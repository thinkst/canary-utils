#!/bin/bash

Console=CONSOLEHASH.canary.tools # Enter your Console domain  for example 1234abc.canary.tools
FacoryAuthToken=FACTORYAUTHTOKEN # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string

FilePath=/home/ubuntu
FileDate=`date "+%Y%m%d%H%M%S"`
FileName="credentials_$FileDate.txt"

# Fetch a session token for AWS Metadata
MetadataToken=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
# Fetch the ec2 instance ID
InstanceId=$(curl -s -H "X-aws-ec2-metadata-token: $MetadataToken" http://169.254.169.254/latest/meta-data/instance-id)
# Fetch the ec2 instance AMI ID
AmiId=$(curl -s -H "X-aws-ec2-metadata-token: $MetadataToken" http://169.254.169.254/latest/meta-data/ami-id)

TokenReminder="Path:$FilePath | InstanceId:$InstanceId | AMIId:$AmiId"

awscreds=$(curl -s https://$Console/api/v1/canarytoken/factory/create \
  -d factory_auth=$FacoryAuthToken \
  -d memo="$TokenReminder" \
  -d kind=aws-id)

aws_access_key_id=$(echo $awscreds | grep -oE "aws_access_key_id = .{20}")
aws_secret_access_key=$(echo echo $awscreds | grep -Eo "aws_secret_access_key = .{40}")

# Write the Canarytoken to a local text file
echo -e "[default]\n$aws_access_key_id\n$aws_secret_access_key" > "$FilePath/$FileName"
echo -e "\nCreds written to $FilePath/$FileName"
