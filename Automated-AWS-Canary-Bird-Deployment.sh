#!/bin/bash
# Automated-AWS-Canary-Bird-Deployment.sh
# Justin Varner
# July 24, 2021
# This script automates the process for commissioning a bird that has been deployed as an AWS EC2 instance and configures the device personality using the Canary API. Values in the sample config.json file should be replaced (all services are disabled by default). Set the CANARY_HASH, CANARY_TOKEN, and CANARY_FLOCK variables based on your tenant.
#Terraform code for deploying inside and outside birds can be found here:

# Add your unique tenant values here or set them as environment variables
CANARY_HASH=""
CANARY_TOKEN=""
CANARY_FLOCK=""

# Retrieve flock info and set the CANARY_FLOCK variable to the desired flock ID if the default one won't be used
curl https://$CANARY_HASH.canary.tools/api/v1/flocks/summary -d auth_token=$CANARY_TOKEN -G | jq '.flocks_summary[] | .flock_id' | sed 's/\"//g'

# List pending bird commissions after the EC2 AMI has been deployed to AWS and set the node ID
NODE_ID=$(curl https://$CANARY_HASH.canary.tools/api/v1/devices/commission/pending -d auth_token=$CANARY_TOKEN -G | jq '.devices[] | .id' | sed 's/\"//g')

# Confirm bird commission
curl https://$CANARY_HASH.canary.tools/api/v1/device/commission -d auth_token=$CANARY_TOKEN -d node_id=$NODE_ID -d flock_id=$CANARY_FLOCK

# Configure the bird personality from a JSON config file (Refer to the sample config.json file for guidance)
curl https://$CANARY_HASH.canary.tools/api/v1/device/configure -d auth_token=$CANARY_TOKEN -d node_id=$NODE_ID -d settings=config.json
