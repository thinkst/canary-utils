#!/bin/bash
# This script pulls all alert data from a Canary outside bird, sends the results to the GreyNoise Enterprise API for detailed threat intelligence context, and creates a JSON report.
# Please consult the README for prequisites and usage instructions

# Cleanup any residual files that may have been left behind from previously running the script
rm -rf outside_bird_alerts.json.zip outside-bird-$BIRD_ID.json canary-ips-*.txt

# Query the Canary API for all outside bird events, extract and sort IPs, remove double quotes, and write to a text file for GreyNoise to contextualize
curl https://$CANARY_HASH.canary.tools/api/v1/incidents/outside_bird/download/json \
  -d auth_token=$CANARY_TOKEN \
  -d node_id=$BIRD_ID \
  -G -O -J \
  && unzip outside_bird_alerts.json.zip \
  && cat outside-bird-$BIRD_ID.json | jq '.[].ip_address' | sed 's/\"//g' | sort > canary-ips-$(date +%Y-%m-%d).txt

# Read through each line of the canary text file, send each IP through the GreyNoise Enterprise API, and create a detailed JSON report
file="canary-ips-$(date +%Y-%m-%d).txt"
lines=$(cat $file)

for line in $lines
do
    curl "https://api.greynoise.io/v2/noise/context/$line" --header "$GREYNOISE_API_KEY" | jq '.' | cat >> GreyNoise-Enterprise-Canary-Threat-Intel-Report-$(date +%Y-%m-%d).json
done

# Cleanup all residual files except for the final GreyNoise report
rm -rf outside_bird_alerts.json.zip outside-bird-$BIRD_ID.json canary-ips-*.txt
