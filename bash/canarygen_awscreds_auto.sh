#!/bin/bash
# Generate AWS Creds 
# canarygen_awscreds_auto.sh

# This is the "auto" version of this script. Run it unattended and it will
# automatically grab username and hostname variables from the system it is
# run on.

# Set the following variables to the correct values for your:
# 1. Unique Canary Console URL - This is your domain hash
# 2. Canary Console API Key - We recommend that you use the Canarytoken Deploy Flock API key type, instead of Factory Auth Tokens.
#    - How does the API work? -> https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work
#    - Flock API keys - https://help.canary.tools/hc/en-gb/articles/7111549805213-Flock-API-Keys
# 3. Path where file will be created (defaults to root of home directory)

set -euo pipefail

CONSOLE="abc1234e.canary.tools"
AUTH_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
FILEPATH="${HOME}"

command -v curl >/dev/null 2>&1 || { echo "Missing required command: curl" >&2; exit 1; }
mkdir -p "${FILEPATH}"

FILEDATE="$(date "+%Y%m%d%H%M%S")"
OUTFILE="${FILEPATH}/awscreds_${FILEDATE}.txt"

# Safety check: never overwrite an existing file
if [[ -e "${OUTFILE}" ]]; then
  echo "ERROR: Output file already exists, refusing to overwrite: ${OUTFILE}" >&2
  exit 1
fi

# Token Memo for tracking in the Canary Console
TOKENMEMO="${HOSTNAME} - ${USER} - ${OUTFILE}"

# Call API (capture body + http code)
RESP_TMP="$(mktemp)"
HTTP_CODE="$(
  curl -sS -o "${RESP_TMP}" -w "%{http_code}" "https://${CONSOLE}/api/v1/canarytoken/factory/create" \
    -d "factory_auth=${AUTH_TOKEN}" \
    -d "memo=${TOKENMEMO}" \
    -d "kind=aws-id" || echo "000"
)"

if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "ERROR: Token creation request failed (HTTP ${HTTP_CODE})." >&2
  cat "${RESP_TMP}" >&2
  rm -f "${RESP_TMP}"
  exit 1
fi

if ! grep -Eq '"result"[[:space:]]*:[[:space:]]*"success"' "${RESP_TMP}"; then
  echo "ERROR: Token creation API returned an error:" >&2
  cat "${RESP_TMP}" >&2
  rm -f "${RESP_TMP}"
  exit 1
fi

# Extract access_key_id and secret_access_key
ACCESS_KEY_ID="$(
  tr -d '\n' < "${RESP_TMP}" |
    sed -n 's/.*"access_key_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
)"

SECRET_ACCESS_KEY="$(
  tr -d '\n' < "${RESP_TMP}" |
    sed -n 's/.*"secret_access_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
)"

rm -f "${RESP_TMP}"

if [[ -z "${ACCESS_KEY_ID}" || -z "${SECRET_ACCESS_KEY}" ]]; then
  echo "ERROR: Could not extract access_key_id / secret_access_key from API response." >&2
  exit 1
fi

cat > "${OUTFILE}" <<EOF
[default]
aws_access_key_id = ${ACCESS_KEY_ID}
aws_secret_access_key = ${SECRET_ACCESS_KEY}
EOF

echo "Success: Creds written to ${OUTFILE}"

unset CONSOLE AUTH_TOKEN FILEPATH FILEDATE OUTFILE TOKENMEMO ACCESS_KEY_ID SECRET_ACCESS_KEY HTTP_CODE
exit 0