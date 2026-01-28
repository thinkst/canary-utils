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
#   - Refuses to overwrite an existing key file
#   - Skips appending if the Host entry already exists
#   - Uses secure permissions: ~/.ssh (0700), private keys (0600), config (0600)
#
# Notes:
#   - Must be run as root to write into other users’ home directories.
#   - Uses jq if available; otherwise falls back to grep/awk parsing.
# -----------------------------------------------------------------------------
set -euo pipefail

DOMAIN="abc123.canary.tools"
BDK="qwerty123qwerty"
node_id="0000000011111111" # optional

# Leave ssh_alias and canary_ip empty if node_id is specified.
# If node_id is not specified, you must define a ssh_alais & canary_ip
ssh_alias=""
canary_ip=""

# ssh_port is option and will only be used if specified (and not 22)
ssh_port=""

HOSTNAME=$(hostname)

detect_os() {
  case "$(uname -s)" in
    Linux)   echo linux ;;
    Darwin) echo macos ;;
    *)       echo unknown ;;
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

OS="$(detect_os)"

deploy_ssh_breadcrumb() {
    # Skip system/shared folders commonly found on macOS, if you want to skip over specific users, add below
    skip_users=(Shared .localized)

    USERS_DIR="/home" 
    if [[ "$OS" == "macos" ]]; then
        USERS_DIR="/Users" 
    fi
    
    echo "Starting SSH Breadcrumb Deployment..."
    echo "$HOSTNAME ($OS) looking for users directories in: $USERS_DIR"

    # Loop through each directory in $USERS_DIR
    for user_home in "$USERS_DIR"/*; do
        # Check if the directory is actually a directory
        [[ -d "$user_home" ]] || continue

        username=$(basename "$user_home")
        

        for skip in "${skip_users[@]}"; do
            [[ "$username" == "$skip" ]] && continue 2
        done

        current_user_id=$(id -u "$username")
        current_group_id=$(id -g "$username")
        

        echo "------------------------------------------------"
        echo "Processing user: $username"
        
        ssh_dir="$user_home/.ssh"
        config_path="$ssh_dir/config"
        endpoint="https://${DOMAIN}/api/v1/breadcrumb/generate"

        reminder="$HOSTNAME:$ssh_dir"

        if [ -n "$node_id" ]; then
            response="$(
                curl --tlsv1.2 -sS -X POST "$endpoint" \
                    -d "kind=ssh-key" \
                    -d "reminder=$reminder" \
                    -d "node_id=$node_id" \
                    -d "auth_token=$BDK" \
                    --retry 3 \
                    --retry-delay 2 \
                    --retry-max-time 30
                )"
        else 
            response="$(
                curl --tlsv1.2 -sS -X POST "$endpoint" \
                    -d "kind=ssh-key" \
                    -d "reminder=$reminder" \
                    -d "auth_token=$BDK" \
                    --retry 3 \
                    --retry-delay 2 \
                    --retry-max-time 30
                )"
        fi

        if [[ "$response" != *success* ]]; then
            echo "[ERROR] API call failed or did not return success." >&2
            echo "[ERROR] Response: $response" >&2
            continue
        fi

        if command -v jq >/dev/null 2>&1; then
            private_key="$(printf '%s' "$response" | jq -r '.private_key')"
            public_key="$(printf '%s' "$response" | jq -r '.public_key')" # not used but available if you want to use it
            
            if [ -n "$node_id" ]; then
                ssh_alias="$(printf '%s' "$response" | jq -r '.label')" # Canary device name
                canary_ip="$(printf '%s' "$response" | jq -r '.canary_ip')"
                ssh_port="$(printf '%s' "$response" | jq -r '.ssh_port')"
            fi     
        else
            public_key="$(printf '%s' "$response" \
                | grep -oE '"public_key"[[:space:]]*:[[:space:]]*"[^"]+"' \
                | awk -F'"' '{print $4}')"

            private_key="$(printf '%s' "$response" \
                | grep -oE '"private_key"[[:space:]]*:[[:space:]]*"([^"]|\\n)*"' \
                | awk -F'"' '{print $4}' \
                | sed 's/\\n/\n/g')"

            if [ -n "$node_id" ]; then
                ssh_alias="$(printf '%s' "$response" \
                    | grep -oE '"label"[[:space:]]*:[[:space:]]*"[^"]+"' \
                    | awk -F'"' '{print $4}')"

                canary_ip="$(printf '%s' "$response" \
                    | grep -oE '"canary_ip"[[:space:]]*:[[:space:]]*"[^"]+"' \
                    | awk -F'"' '{print $4}')"

                ssh_port="$(printf '%s' "$response" \
                    | grep -oE '"ssh_port"[[:space:]]*:[[:space:]]*"[^"]+"' \
                    | awk -F'"' '{print $4}')"
            fi
        fi

        # Basic sanity checks
        if [[ -z "$private_key" ]]; then
            echo "[ERROR] private_key missing or invalid in response." >&2
            continue
        fi

        if [[ -z "$ssh_alias" ]]; then
            echo "[ERROR] No SSH alias defined" >&2
            continue
        fi

        key_path="$ssh_dir/id_$ssh_alias"

        if [[ -e "$key_path" ]]; then
            echo "[WARNING] Refusing to overwrite existing key: $key_path (skipping)" >&2
            continue
        fi

        echo "Writing files..."
        echo "$key_path"
        echo "$config_path"

        if [ ! -d "$ssh_dir" ]; then
            echo "Creating directory: $ssh_dir"
            mkdir -p "$ssh_dir" || { echo "Failed to create directory: $ssh_dir"; continue; }
            chmod 700 "$ssh_dir"
            chown -- "$current_user_id:$current_group_id" "$ssh_dir"
        fi

        # Avoid duplicating config entries
        if [[ -f "$config_path" ]] && grep -qE "^[[:space:]]*Host[[:space:]]+$ssh_alias([[:space:]]|\$)" "$config_path"; then
            echo "[INFO] SSH config already contains a Host entry for '$ssh_alias' (skipping append)." >&2
            continue
        fi

        umask 077
        echo "$private_key" > "$key_path"
        chmod 600 "$key_path"
        chown -- "$current_user_id:$current_group_id" "$key_path"

        echo "[OK] Wrote private key to: $key_path" >&2

        # Ensure SSH config file exists
        if [[ ! -f "$config_path" ]]; then
            touch "$config_path"
            chmod 600 "$config_path" 2>/dev/null || true
            chown -- "$current_user_id:$current_group_id" "$config_path"
        fi

        ssh_port_arg="" # leave empty
        if [ -n "$ssh_port" ] && [ "$ssh_port" != "22" ]; then
            ssh_port_arg=$'\n'"    Port $ssh_port"
        fi

        cat <<EOT >> "$config_path"

Host $ssh_alias
    HostName $canary_ip$ssh_port_arg
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
