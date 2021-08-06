#!/bin/bash
# This script automates the process for commissioning a bird that has been deployed as an AWS EC2 instance and configures the device personality using the Canary API. 
# Values in the sample config.json file should be set. All bird services are disabled by default. 
# Set the CANARY_HASH, CANARY_TOKEN, and FLOCK_ID variables based on your Canary console.
# Sample code for automating the deployment of AWS EC2 birds can be found in the terraform folder of this repository

# Retrieve flock info and set the FLOCK_ID variable to the desired flock if the default one won't be used
curl https://$CANARY_HASH.canary.tools/api/v1/flocks/summary -d auth_token=$CANARY_TOKEN -G | jq '.flocks_summary[] | .flock_id' | sed 's/\"//g'

# List pending bird commissions after the EC2 instance has been deployed to AWS and set the NODE_ID variable from the result of the API call
NODE_ID=$(curl https://$CANARY_HASH.canary.tools/api/v1/devices/commission/pending -d auth_token=$CANARY_TOKEN -G | jq '.devices[] | .id' | sed 's/\"//g')

# Confirm bird commission
curl https://$CANARY_HASH.canary.tools/api/v1/device/commission -d auth_token=$CANARY_TOKEN -d node_id=$NODE_ID -d flock_id=$FLOCK_ID

# Configure the bird personality from a JSON config file with your values set
curl https://$CANARY_HASH.canary.tools/api/v1/device/configure -d auth_token=$CANARY_TOKEN -d node_id=$NODE_ID -d settings=config.json
