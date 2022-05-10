#!/bin/bash
# This script automates the process for commissioning a bird that has been deployed as an AWS EC2 instance and configures the device personality using the Canary API. 
# Please consult the README for prequisites and usage instructions

# Retrieve flock info and set the FLOCK_ID variable to the desired flock if the default one won't be used
curl -XGET https://$CANARY_HASH.canary.tools/api/v1/flocks/summary \
  -d auth_token=$CANARY_API_KEY \
  -G | jq '.flocks_summary[] | .flock_id' | sed 's/\"//g'

# List pending bird commissions after the AWS EC2 instance has been deployed and set the NODE_ID accordingly
NODE_ID=$(curl https://$CANARY_HASH.canary.tools/api/v1/devices/commission/pending -d auth_token=$CANARY_API_KEY -G | jq '.devices[] | .id' | sed 's/\"//g')

# Confirm bird commission
curl https://$CANARY_HASH.canary.tools/api/v1/device/commission \
  -d auth_token=$CANARY_API_KEY \
  -d node_id=$NODE_ID \
  -d flock_id=$FLOCK_ID

# Configure the bird's personality using the config.json file. Override desired values as needed
curl https://$CANARY_HASH.canary.tools/api/v1/device/configure \
  -d auth_token=$CANARY_API_KEY \
  -d node_id=$NODE_ID \
  -d settings=config.json
