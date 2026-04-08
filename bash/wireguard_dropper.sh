#!/usr/bin/env bash
#
# Deploys a WireGuard Canarytoken via Canary Console API.
#
set -Eeuo pipefail

# =========================
# Settings
# =========================
DOMAIN="xyz123.canary.tools"
CDK="abc123abc" # Canarytoken Deploy Key - https://help.canary.tools/hc/en-gb/articles/7111549805213-Flock-API-Keys
TOKEN_FILENAME="vpn-wg.conf" 
TARGET_DIRECTORY="/usr/local/wireguard/configs"
FORCE=0 # set to 1 to overwrite the local Canarytoken file and generate a new token
VERBOSE=1

TMP_RESPONSE=""

# =========================
# Helpers
# =========================
log() {
    if [ "$VERBOSE" = "1" ]; then
        printf '%s\n' "$*" >&2
    fi
}

warn() {
    printf 'Warning: %s\n' "$*" >&2
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

cleanup() {
    if [ -n "${TMP_RESPONSE:-}" ] && [ -f "$TMP_RESPONSE" ]; then
        rm -f "$TMP_RESPONSE"
    fi
}

trap cleanup EXIT

# =========================
# Main
# =========================
deploy_wg() {
    local host_name
    local output_file
    local memo
    local http_code
    local attempt
    local token_id

    host_name="$(hostname 2>/dev/null || uname -n)"
    host_name="${host_name%%.*}"

    output_file="${TARGET_DIRECTORY%/}/$TOKEN_FILENAME"
    memo="${host_name}|${output_file}"

    log "Host: $host_name"
    log "Output file: $output_file"

    if [ -f "$output_file" ] && [ "$FORCE" != "1" ]; then
        warn "Token file already exists, skipping: $output_file"
        return 0
    fi

    if [ ! -d "$TARGET_DIRECTORY" ]; then
        log "Creating directory: $TARGET_DIRECTORY"
        mkdir -p "$TARGET_DIRECTORY"
        chmod 755 "$TARGET_DIRECTORY"
    fi

    TMP_RESPONSE="$(mktemp)"

    for attempt in 1 2 3; do
        log "Creating token (attempt $attempt/3)..."

        http_code="$(
            curl -sS \
                --proto '=https' \
                --tlsv1.2 \
                --connect-timeout 10 \
                --max-time 30 \
                -o "$TMP_RESPONSE" \
                -w '%{http_code}' \
                -X POST "https://$DOMAIN/api/v1/canarytoken/create" \
                -H "X-Canary-Auth-Token: $CDK" \
                --data-urlencode "kind=wireguard" \
                --data-urlencode "memo=$memo" \
            || true
        )"

        if [ "$http_code" = "200" ]; then
            break
        fi

        warn "Attempt $attempt/3 failed (HTTP ${http_code:-unknown})."

        if [ "$attempt" -eq 3 ]; then
            die "Failed to create token after 3 attempts."
        fi

        sleep $((attempt * 2))
    done

    token_id="$(
        python3 - "$TMP_RESPONSE" "$output_file" <<'PY'
import json
import sys

response_path = sys.argv[1]
output_path = sys.argv[2]

with open(response_path, encoding="utf-8") as f:
    data = json.load(f)

if data.get("result") != "success":
    print(f"Token creation failed. Result: {data.get('result')}", file=sys.stderr)
    sys.exit(1)

token = data.get("canarytoken", {})
token_id = token.get("canarytoken", "")
wg_conf = token.get("renders", {}).get("wg_conf", "")

if not wg_conf.strip():
    print(f"Token created (ID: {token_id}) but wg_conf was empty or missing.", file=sys.stderr)
    sys.exit(1)

with open(output_path, "w", encoding="utf-8", newline="") as f:
    f.write(wg_conf)

print(token_id)
PY
    )" || die "Unable to parse API response or write config file."

    chmod 644 "$output_file"

    log "Token creation successful. Token ID: $token_id"
    printf "[*] Canarytoken saved to: '%s' on %s\n" "$output_file" "$host_name"
}

require_cmd curl
require_cmd python3

[ -n "$DOMAIN" ] || die "DOMAIN is empty"
[ -n "$CDK" ] || die "CDK is empty"

deploy_wg
