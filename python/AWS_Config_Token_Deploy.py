import urllib.request
import socket
import os
import json

# Specify you Console domain and Canarytoken Deploy Flock API Key
# (More on the API Key: https://help.canary.tools/hc/en-gb/articles/7111549805213-Flock-API-Keys)
Domain = "ABC123.canary.tools"
canarytoken_deploy_flock_api_key = "fa..."

def drop_awsid_token():
    # Create Token on Console
    create_token_url = 'https://' + Domain + '/api/v1/canarytoken/create'

    payload = {
        'auth_token': canarytoken_deploy_flock_api_key,
        'kind': 'aws-id',
        'memo': socket.gethostname() + ' - ' + 'Inserted into ~/.aws/credentials',
    }

    data = urllib.parse.urlencode(payload).encode("utf-8")
    req = urllib.request.Request(create_token_url, data=data)

    with urllib.request.urlopen(req) as create_token:
        if create_token.status != 200:
            print('[!] Creation of AWS Token failed.')
            exit()
        else:
            result = json.loads(create_token.read().decode('utf-8'))

    canarytoken_key_id = result['canarytoken']['access_key_id']
    canarytoken_access_key = result['canarytoken']['secret_access_key']

    # Insert into AWS CLI Configuration
    aws_profile_name = "emergency-admin-creds"  # Profile name for the AWS CLI configuration
    aws_config_file = os.path.expanduser("~/.aws/config")

    # Construct the AWS CLI configuration content
    config_content = f"""
[profile {aws_profile_name}]
region = us-west-2
aws_access_key_id = {canarytoken_key_id}
aws_secret_access_key = {canarytoken_access_key}
"""

    # Write the configuration content to the AWS config file
    with open(aws_config_file, "a") as config_file:
        config_file.write(config_content)

    print(f"AWS profile '{aws_profile_name}' configured successfully.")

drop_awsid_token()
