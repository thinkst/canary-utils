#!/bin/bash
# Deploys a WireGuard Canarytoken via Canary Factory API.
#
# Defaults:
#   DOMAIN:         "XYZ123.canary.tools"
#   FACTORY_AUTH:   "ABC123"
#   TOKEN_FILENAME: "vpn-gw3-<HOSTNAME>-wg.conf"
#   TARGET_DIRECTORY: "/usr/local/wireguard/configs"
#
# Notes:
#   - The script replaces "<HOSTNAME>" in the token filename with the short hostname (if <HOSTNAME> is present).
#   - It creates the target directory if missing.

# Default values
DOMAIN="XYZ123.canary.tools"
FACTORY_AUTH="ABC123"
TOKEN_FILENAME="vpn-gw3-<HOSTNAME>-wg.conf"
TARGET_DIRECTORY="/usr/local/wireguard/configs"

echo "Starting token deployment..."

# Get the hostname
HOSTNAME=$(hostname)

# Replace literal '<HOSTNAME>' in TOKEN_FILENAME if present
if [[ "$TOKEN_FILENAME" == *"<HOSTNAME>"* ]]; then
    echo "Replacing <HOSTNAME> in the token filename."
    TOKEN_FILENAME="${TOKEN_FILENAME//<HOSTNAME>/$HOSTNAME}"
fi

# Remove any trailing slash from TARGET_DIRECTORY
TARGET_DIRECTORY="${TARGET_DIRECTORY%/}"

# Build the output file path
OUTPUT_FILE="$TARGET_DIRECTORY/$TOKEN_FILENAME"
echo "Final output file path: $OUTPUT_FILE"

# If the token file already exists, skip deployment
if [ -f "$OUTPUT_FILE" ]; then
    echo "Warning: Token '$OUTPUT_FILE' already exists. Skipping..."
    exit 0
fi

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIRECTORY" ]; then
    echo "Creating directory: $TARGET_DIRECTORY"
    mkdir -p "$TARGET_DIRECTORY" || { echo "Failed to create directory: $TARGET_DIRECTORY"; exit 1; }
fi

# Build the POST data. Memo includes the FQDN and output file path (using '|' as delimiter)
MEMO="${HOSTNAME}|${OUTPUT_FILE}"
POST_DATA="factory_auth=${FACTORY_AUTH}&kind=wireguard&memo=${MEMO}"

echo "Creating token via Factory API..."
# Invoke the API to create the token (forcing TLS v1.2)
CREATE_RESULT=$(curl --tlsv1.2 -s -X POST "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d "$POST_DATA")
if [ $? -ne 0 ]; then
    echo "Failed to invoke REST method for token creation."
    exit 1
fi

# Remove newlines to simplify parsing
CLEAN_RESULT=$(echo "$CREATE_RESULT" | tr -d '\n')

# Extract the "result" field from the JSON response
RESULT=$(echo "$CLEAN_RESULT" | sed -n 's/.*"result"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ "$RESULT" != "success" ]; then
    echo "Creation of $OUTPUT_FILE failed on $HOSTNAME_FQDN. (Result: $RESULT)"
    exit 1
fi

# Extract the TokenID from the JSON response.
# Expected JSON structure:
# {"result": "success", "canarytoken": {"canarytoken": "<TOKEN_ID>"}}
TOKEN_ID=$(echo "$CLEAN_RESULT" | sed -n 's/.*"canarytoken"[[:space:]]*:[[:space:]]*{[^}]*"canarytoken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$TOKEN_ID" ]; then
    echo "Failed to extract token ID from response."
    exit 1
fi

echo "Token creation successful. Token ID: $TOKEN_ID"

# Download the token
echo "Downloading token..."
DOWNLOAD_URI="https://${DOMAIN}/api/v1/canarytoken/factory/download?factory_auth=${FACTORY_AUTH}&canarytoken=${TOKEN_ID}"
curl --tlsv1.2 -s -L -o "$OUTPUT_FILE" "$DOWNLOAD_URI"
if [ $? -ne 0 ]; then
    echo "Failed to download token."
    exit 1
fi

echo "[*] Canarytoken saved to: '$OUTPUT_FILE' on $HOSTNAME"
