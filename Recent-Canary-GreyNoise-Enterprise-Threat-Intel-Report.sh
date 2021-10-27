#!/bin/bash
# This script pulls recent alert data from a Canary outside bird, sends the results to the GreyNoise Enterprise API for detailed threat intelligence context, and creates a JSON report.
# Please consult the README for prequisites and usage instructions

# Cleanup any residual files that may have been left behind from previously running the script
rm -rf outside* canary-ips-*.txt

curl -XGET "https://$CANARY_HASH.canary.tools/api/v1/incidents/outside_bird/search" -d auth_token=$CANARY_API_KEY -d node_ids=$BIRD_ID -G | jq '.src_ips[] | .ip_address' | sed 's/\"//g' | sort > canary-ips-$(date +%Y-%m-%d).txt

# Read through each line of the canary text file, send each IP through the GreyNoise Enterprise API, and create a detailed JSON report
file="canary-ips-$(date +%Y-%m-%d).txt"
lines=$(cat $file)

for line in $lines
do
    curl "https://api.greynoise.io/v2/noise/context/$line" -H "key: $GREYNOISE_API_KEY" -H "accept: application/json" | jq '.' | cat >> Recent-Canary-GreyNoise-Enterprise-Threat-Intel-Report-$(date +%Y-%m-%d).json
done
