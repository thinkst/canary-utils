#!/bin/bash
# This script pulls all alert data from a Canary outside bird, sends the results to the GreyNoise Community API for threat intelligence context, and creates a JSON report.
# Please consult the README for prequisites and usage instructions

# Cleanup any residual files that may have been left behind from previously running the script
rm -rf outside* canary-ips-*.txt

# Query the Canary API for all outside bird events, extract and sort IPs, remove double quotes, and write to a text file for GreyNoise to contextualize
curl -XGET "https://$CANARY_HASH.canary.tools/api/v1/incidents/outside_bird/download/json" \
  -d auth_token=$CANARY_API_KEY \
  -d node_id=$BIRD_ID \
  -G -O -J \
  && unzip outside_bird_alerts.json.zip \
  && cat outside-bird-$BIRD_ID.json | jq '.[].ip_address' | sed 's/\"//g' | sort > canary-ips-$(date +%Y-%m-%d).txt

# Read through each line of the canary text file, send each IP through the GreyNoise Community API, and create a JSON report
file="canary-ips-$(date +%Y-%m-%d).txt"
lines=$(cat $file)

for line in $lines
do
    curl -XGET "https://api.greynoise.io/v3/community/$line" -H "accept: application/json" | jq '.' | cat >> Canary-GreyNoise-Community-Threat-Intel-Report-$(date +%Y-%m-%d).json
done

# Cleanup residual files except for the final GreyNoise report
#rm -rf outside_bird_alerts.json.zip outside-bird-$BIRD_ID.json canary-ips-*.txt
