#!/bin/bash

#### This is somewhat a port of CreateTokens.ps1 to bash - https://github.com/thinkst/canary-utils/blob/master/powershell/CreateTokens.ps1
#### It can be used to generate multiple Canarytokens on a single host, which can then be distributed using another method

# ────────────────[ Config ]────────────────

API_HOST="YOUR_CONSOLE.canary.tools"
API_TOKEN="YOUR_API_KEY"

TOKEN_KIND="azure-id"  # Options: doc-msword, aws-id, azure-id, slack-api, wireguard, mysql-dump
AZURE_FILENAME="azure-prod.pem"  # Required param for azure-id

TARGETS=("host1" "host2")

# ────────────────[ Setup ]────────────────

# Check for required tools
for tool in curl jq; do
    if ! command -v $tool &>/dev/null; then
        echo "❌ Required tool '$tool' not installed."
        exit 1
    fi
done

# Ping Canary API
PING_RESULT=$(curl -s "https://$API_HOST/api/v1/ping?auth_token=$API_TOKEN" | jq -r '.result')
if [[ "$PING_RESULT" != "success" ]]; then
    echo "❌ Error connecting to Canary API. Check your domain/token."
    exit 1
fi
echo "✅ Canary API is reachable."

# ────────────────[ Token Generation ]────────────────

for TARGET in "${TARGETS[@]}"; do
    TOKEN_NAME="${TARGET}-${TOKEN_KIND}"

    # Determine output filename based on token kind
    case "$TOKEN_KIND" in
        doc-msword)
            OUTPUT_FILE="${TARGET}-doc.docx"
            ;;
        aws-id)
            OUTPUT_FILE="${TARGET}-credentials"
            ;;
        azure-id)
            OUTPUT_FILE="${TARGET}-azure-prod.zip"
            ;;
        slack-api)
            OUTPUT_FILE="${TARGET}-slack-prod"
            ;;
        wireguard)
            OUTPUT_FILE="${TARGET}-wg0.conf"
            ;;
        mysql-dump)
            OUTPUT_FILE="${TARGET}-dump.sql.gz"
            ;;
        *)
            echo "❌ Unsupported TOKEN_KIND: $TOKEN_KIND"
            exit 1
            ;;
    esac

    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "⚠️  Skipping $TOKEN_NAME — file already exists."
        continue
    fi

    echo "🔧 Creating token: $TOKEN_NAME"

    # Base API payload
    API_PAYLOAD=(-d auth_token="$API_TOKEN" -d kind="$TOKEN_KIND" -d memo="$TOKEN_NAME")

    # Add extra param if required
    if [[ "$TOKEN_KIND" == "azure-id" ]]; then
        API_PAYLOAD+=(-d azure_id_cert_file_name="$AZURE_FILENAME")
    fi

    CREATE_RESP=$(curl -s -X POST "https://$API_HOST/api/v1/canarytoken/create" "${API_PAYLOAD[@]}")
    RESULT=$(echo "$CREATE_RESP" | jq -r '.result')

    if [[ "$RESULT" != "success" ]]; then
        echo "❌ Failed to create token for $TARGET"
        echo "$CREATE_RESP"
        continue
    fi

    TOKEN_ID=$(echo "$CREATE_RESP" | jq -r '.canarytoken.canarytoken')
    echo "✅ Token created for $TARGET (ID: $TOKEN_ID)"

    # Attempt download (if applicable)
    curl -s -G -L -o "$OUTPUT_FILE" \
        "https://$API_HOST/api/v1/canarytoken/download?auth_token=$API_TOKEN&canarytoken=$TOKEN_ID"

    if [[ $? -eq 0 ]]; then
        echo "📁 Token file saved to $OUTPUT_FILE"
    else
        echo "⚠️  Token created, but no downloadable file returned."
    fi
done
