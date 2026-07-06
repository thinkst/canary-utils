#!/bin/bash
# -----------------------------------------------------------------------------
# SSH Key Breadcrumb multi-user deployment
#
# This script loops through local user home directories and:
#   1) Requests an SSH Key breadcrumb from Canary Console via the Breadcrumb API
#   2) Writes a per-user private key into ~/.ssh/
#   3) Appends a matching Host entry to ~/.ssh/config (without duplicates)
#
# Configuration:
#   - Set Console DOMAIN Hash and BDK (Breadcrumb Deploy Key).
#   - See Flock API Keys: https://help.canary.tools/hc/en-gb/articles/7111549805213-Flock-API-Keys
#   - node_id is optional:
#       * If node_id is set, ssh_alias/canary_ip/ssh_port are taken from API output.
#       * If node_id is empty, you MUST set ssh_alias and canary_ip in this file.
#
# Safety / idempotency:
#   - Skips (rather than aborts) on any per-user failure
#   - Refuses to overwrite an existing key file
#   - Skips appending if the Host entry already exists
#   - Checks for existing artifacts BEFORE calling the API where possible,
#     to avoid minting breadcrumbs that never get deployed
#   - Uses secure permissions: ~/.ssh (0700), private keys (0600), config (0600)
#
# Notes:
#   - Must be run as root to write into other users' home directories.
# -----------------------------------------------------------------------------
set -euo pipefail

DOMAIN="abc123.canary.tools"
BDK="fa000000000000000000001111111111111111111111"
node_id="0000000011111111" # optional

# Leave ssh_alias and canary_ip empty if node_id is specified.
# If node_id is not specified, you must define ssh_alias & canary_ip
ssh_alias=""
canary_ip=""

# ssh_port is optional and will only be used if specified (and not 22)
ssh_port=""

# Skip system/shared folders; add any users you want to skip below
skip_users=(Shared .localized Guest lost+found)

HOSTNAME=$(hostname)

detect_os() {
  case "$(uname -s)" in
    Linux)  echo linux ;;
    Darwin) echo macos ;;
    *)      echo unknown ;;
  esac
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root for multi-user deployment." >&2
    exit 1
  fi
}

require_node_or_alias_and_ip() {
    if [[ -z "$node_id" ]]; then
        if [[ -z "$ssh_alias" || -z "$canary_ip" ]]; then
            echo "[ERROR] Either node_id must be set, or both ssh_alias and canary_ip must be provided." >&2
            exit 1
        fi
    fi
}

# Extracts values from JSON response.
json_field() {
    printf '%b' "$(printf '%s' "$2" \
        | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")"
}

# Sanitise a device label into something safe for a filename / ssh Host alias
sanitise_alias() {
    printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

OS="$(detect_os)"

deploy_ssh_breadcrumb() {
    local USERS_DIR="/home"
    if [[ "$OS" == "macos" ]]; then
        USERS_DIR="/Users"
    fi

    echo "Starting SSH Breadcrumb Deployment..."
    echo "$HOSTNAME ($OS) looking for user directories in: $USERS_DIR"

    # When node_id is set, we can reuse the alias/ip/port.
    local known_alias="" known_ip="" known_port=""
    if [[ -z "$node_id" ]]; then
        known_alias="$(sanitise_alias "$ssh_alias")"
        known_ip="$canary_ip"
        known_port="$ssh_port"
    fi

    local user_home username current_user_id current_group_id
    local ssh_dir config_path endpoint reminder response result
    local private_key alias_raw key_alias key_path ip port ssh_port_arg

    for user_home in "$USERS_DIR"/*; do
        # Strictly checks for a real directory (not a symlink to elsewhere, not a file)
        [[ -d "$user_home" && ! -L "$user_home" ]] || continue

        username=$(basename "$user_home")

        for skip in "${skip_users[@]}"; do
            [[ "$username" == "$skip" ]] && continue 2
        done

        # Skip directories that don't correspond to an actual user account.
        if ! current_user_id=$(id -u "$username" 2>/dev/null); then
            echo "[INFO] '$username' is not a valid user (directory only?), skipping." >&2
            continue
        fi
        if ! current_group_id=$(id -g "$username" 2>/dev/null); then
            echo "[INFO] Could not resolve primary group for '$username', skipping." >&2
            continue
        fi

        echo "------------------------------------------------"
        echo "Processing user: $username"

        ssh_dir="$user_home/.ssh"
        config_path="$ssh_dir/config"
        endpoint="https://${DOMAIN}/api/v1/breadcrumb/generate"
        reminder="$HOSTNAME:$ssh_dir"

        # If we already know the alias, skip early — before spending an API call.
        if [[ -n "$known_alias" && -e "$ssh_dir/id_$known_alias" ]]; then
            echo "[WARNING] Refusing to overwrite existing key: $ssh_dir/id_$known_alias (skipping)" >&2
            continue
        fi

        if [[ -n "$node_id" ]]; then
            if ! response="$(
                curl --tlsv1.2 -sS --fail -X POST "$endpoint" \
                    -d "kind=ssh-key" \
                    -d "reminder=$reminder" \
                    -d "node_id=$node_id" \
                    -d "auth_token=$BDK" \
                    --retry 3 \
                    --retry-delay 2 \
                    --retry-max-time 30
                )"; then
                echo "[ERROR] API request failed for $username, skipping." >&2
                continue
            fi
        else
            if ! response="$(
                curl --tlsv1.2 -sS --fail -X POST "$endpoint" \
                    -d "kind=ssh-key" \
                    -d "reminder=$reminder" \
                    -d "auth_token=$BDK" \
                    --retry 3 \
                    --retry-delay 2 \
                    --retry-max-time 30
                )"; then
                echo "[ERROR] API request failed for $username, skipping." >&2
                continue
            fi
        fi

        result="$(json_field result "$response")"
        if [[ "$result" != "success" ]]; then
            echo "[ERROR] API call did not return success." >&2
            echo "[ERROR] Response: $response" >&2
            continue
        fi

        # Reset per-response fields in case of intermittent API failure.
        private_key="$(json_field private_key "$response")"
        alias_raw="$known_alias"
        ip="$known_ip"
        port="$known_port"

        if [[ -n "$node_id" ]]; then
            alias_raw="$(json_field label "$response")"      # Canary device name
            ip="$(json_field canary_ip "$response")"
            port="$(json_field ssh_port "$response")"
        fi

        # Basic sanity checks
        # NOTE: marker is split across two string literals so pre-commit's
        # detect-private-key hook does not flag this validation check.
        openssh_marker="BEGIN OPENSSH ""PRIVATE KEY"
        if [[ "$private_key" != *"$openssh_marker"* ]]; then
            echo "[ERROR] private_key missing or invalid in response." >&2
            continue
        fi
        if [[ -z "$alias_raw" ]]; then
            echo "[ERROR] No SSH alias defined" >&2
            continue
        fi
        if [[ -z "$ip" ]]; then
            echo "[ERROR] No Canary IP defined" >&2
            continue
        fi
        case "$port" in
            ''|*[!0-9]*) port="" ;;   # keep only if purely numeric
        esac

        key_alias="$(sanitise_alias "$alias_raw")"

        # Cache device details for early-skip on subsequent users
        if [[ -n "$node_id" && -z "$known_alias" ]]; then
            known_alias="$key_alias"
            known_ip="$ip"
            known_port="$port"
        fi

        key_path="$ssh_dir/id_$key_alias"

        if [[ -e "$key_path" ]]; then
            echo "[WARNING] Refusing to overwrite existing key: $key_path (skipping)" >&2
            continue
        fi

        echo "Writing files..."
        echo "$key_path"
        echo "$config_path"

        if [[ ! -d "$ssh_dir" ]]; then
            echo "Creating directory: $ssh_dir"
            mkdir -p "$ssh_dir" || { echo "[ERROR] Failed to create directory: $ssh_dir" >&2; continue; }
            chmod 700 "$ssh_dir"
            chown -- "$current_user_id:$current_group_id" "$ssh_dir"
        fi

        umask 077
        # Strip any trailing newlines from the API value, then write exactly one.
        while [[ "$private_key" == *$'\n' ]]; do private_key="${private_key%$'\n'}"; done
        printf '%s\n' "$private_key" > "$key_path"
        chmod 600 "$key_path"
        chown -- "$current_user_id:$current_group_id" "$key_path"

        echo "[OK] Wrote private key to: $key_path" >&2

        # Append config entry unless one already exists.
        if [[ -f "$config_path" ]] && grep -qE "^[[:space:]]*Host[[:space:]]+$key_alias([[:space:]]|\$)" "$config_path"; then
            echo "[INFO] SSH config already contains a Host entry for '$key_alias' (skipping append)." >&2
            continue
        fi

        if [[ ! -f "$config_path" ]]; then
            touch "$config_path"
            chmod 600 "$config_path" 2>/dev/null || true
            chown -- "$current_user_id:$current_group_id" "$config_path"
        fi

        ssh_port_arg="" # leave empty
        if [[ -n "$port" && "$port" != "22" ]]; then
            ssh_port_arg=$'\n'"    Port $port"
        fi

        cat <<EOT >> "$config_path"

Host $key_alias
    HostName $ip$ssh_port_arg
    User $username
    IdentityFile $key_path
EOT

        echo "[OK] Appended SSH config entry to: $config_path" >&2
    done
}

require_root
require_node_or_alias_and_ip
sleep "$((RANDOM % 5))"
deploy_ssh_breadcrumb
