#!/bin/bash
# This script pulls alert data from an outside bird, sends the results to GreyNoise for threat intelligence context, and creates a report in json format. 
# You will need to install the jq package and set your own CANARY_HASH and CANARY_TOKEN values ideally as environment variables since these are sensitive.
# Canary support will be happy to enable API access to your console. See the README for further information.

# Replace these placeholder values with your own
export CANARY_HASH="abcd1234"
export CANARY_TOKEN="11a2222bb3333c444d555e6f777ggg88"

# Query Canary API for all events, extract IPs, remove double quotes, and write to a text file for GreyNoise
curl https://$CANARY_HASH.canary.tools/api/v1/incidents/outside_bird/search -d auth_token=$CANARY_TOKEN -d node_ids="INSERT_NODE_IDS" -G | jq '.src_ips[] | .ip_address' | sed 's/\"//g' | cat > canary-ips-$(date +%Y-%m-%d).txt

# Read through each line of the text file, send each IP to the GreyNoise Community API for context, and write the results to a JSON file
file="canary-ips-$(date +%Y-%m-%d).txt"
lines=$(cat $file)

for line in $lines
do
    curl "https://api.greynoise.io/v3/community/$line" | jq '.' | cat >> GreyNoise-Canary-Threat-Intel-Report-$(date +%Y-%m-%d).json
done

