#!/bin/bash
#
# Requires curl and jq to be in the path
# sudo apt install curl jq

# Set this variable to your API token (grab it here: https://1234abcd.canary.tools/settings where "1234abcd" is your unique console's CNAME)
export token=ABC123

# Customize this variable to match your console URL
export console=ABC123.canary.tools

# Complete Filename
export filename=$console-tokens.csv

# Base URL
export baseurl="https://$console/api/v1/canarytokens/fetch?auth_token=$token"

# Run the jewels
echo created_std,kind,memo > $filename
curl -s "$baseurl" | jq -r '.tokens[] | [.created_printable, .kind, .memo | tostring] | @csv' >> $filename
echo Results saved in $filename