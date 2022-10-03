#!/usr/bin/env python3
"""
Tokenstacker - Word and AWS
This script will download a Word Template from a private github repo,
Token it, then embed an AWS API Token inside and save it to a realistic directory.
For example: ~/Gitlab/Secrets/Credentials.docx
Contact support@canary.tools for assistance.
"""

import os
import shutil
import time
import random
import re
import socket
import zipfile
import requests

##
## Customize these variables to match the environment
##

# Enter your Console domain hash between the quotes. e.g. 1234abc.canary.tools
# where "1234abcd" is your console's unique CNAME
DOMAIN_HASH = "1234abc"

# Enter your Factory auth key. e.g a1bc3e769fg832hij3
# https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
FACTORY_AUTH = "a1bc3e769fg832hij3"

# Enter the desired flock to place tokens in.
# https://docs.canary.tools/flocks/queries.html#list-flock-sensors
FLOCK_ID = "flock:default"

# URL of your template, Private Repo's should follow the format of
# https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx,
# public files can be referenced by https://github.com/owner/repo/raw/main/template.docx
WORD_TEMPLATE_URL = "https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx"

# Personal access token generated on Github,
# if blank the template will downloaded using public channels.
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
GITHUB_PERSONAL_ACCESS_TOKEN = "gh_abcdefghijklmnop123"

# The text within the word template that will be replaced with an AWS Token ID.
AWS_TOKEN_PLACEHOLDER_ID = "AWS_ACCESS_KEY_ID"

# The text within the word template that will be replaced with an AWS Token Key.
AWS_TOKEN_PLACEHOLDER_KEY = "AWS_SECRET_ACCESS_KEY"

# Randomise the Token deployment path, this list can edited to your preferences.
TOKEN_FOLDERS = ['Acronis', 'Github', 'Zoho', 'Confluence', 'Hubspot', 'Okta', 'Gitlab', 'Postman', 'Veeam', 'Redstore']
TOKEN_SUB_FOLDERS = ['Temp','Backup', 'Archive', 'Secrets']
TOKEN_FILENAMES = ['Emergency.docx', 'Credentials.docx', 'Access.docx', 'Accounts.docx']

# The TARGET_FOLDER is absolute path to the folder that is targeted for tokening
# Defaults to the home folder of the user running the script if it is unset
TARGET_FOLDER = ""

##
## Tokenstacker script
##

# Prepare variables
if TARGET_FOLDER == "":
    TARGET_FOLDER = os.path.expanduser('~')

base_url = f"https://{DOMAIN_HASH}.canary.tools"
random_token_folder = random.choice(TOKEN_FOLDERS)
random_token_sub_folder = random.choice(TOKEN_SUB_FOLDERS)
random_token_filename = random.choice(TOKEN_FILENAMES)
token_folder = os.path.join(TARGET_FOLDER, random_token_folder, random_token_sub_folder)
token_path = os.path.join(token_folder, random_token_filename)
hostname = socket.gethostname()

print(f"Creating token: {token_path}")

# Ensure the target directory exists
if not os.path.exists(token_folder):
    os.makedirs(token_folder)

# Create AWS Token on Canary Console
print("Creating AWS token")
request_parameters = {
    'factory_auth': FACTORY_AUTH,
    'kind': 'aws-id',
    'flock_id' : FLOCK_ID,
    'memo': f"{hostname} - Embedded AWS Token in {token_path}",
}

response = requests.post(
    f"{base_url}/api/v1/canarytoken/factory/create",
    data=request_parameters,
    timeout=30
)
response.raise_for_status()
response_json = response.json()

aws_token_id = response_json['canarytoken']['canarytoken']

# Fetch the token payload
request_parameters = {
    'factory_auth': FACTORY_AUTH,
    'canarytoken': aws_token_id
}

response = requests.get(
    f"{base_url}/api/v1/canarytoken/factory/download",
    allow_redirects=True,
    params=request_parameters,
    timeout=30
)

response.raise_for_status()
response_content = response.content.decode()

token_aws_access_key_id = re.findall('aws_access_key_id=(.*)', response_content)[0]
token_aws_secret_access_key = re.findall('aws_secret_access_key=(.*)', response_content)[0]

# Fetch Word Template.
if GITHUB_PERSONAL_ACCESS_TOKEN != '':
    print('Fetching Template with Github Access Token')
    request_parameters = {
        'Authorization': f"token {GITHUB_PERSONAL_ACCESS_TOKEN}",
        'Accept': 'application/vnd.github.v3.raw'
    }
    response = requests.get(
        WORD_TEMPLATE_URL,
        headers=request_parameters,
        timeout=30
    )
else:
    print('Fetching Template using Github public channel')
    response = requests.get(
        WORD_TEMPLATE_URL,
        timeout=30
    )

response.raise_for_status()

with open(token_path, 'wb') as f:
    f.write(response.content)

# Upload template to Canary Console for Tokening
print("Creating Word token")
request_parameters = {
    'factory_auth': FACTORY_AUTH,
    'kind': 'doc-msword',
    'flock_id' : FLOCK_ID,
    'memo': f"{hostname} - {token_path}",
}
request_files = {
    'doc': (token_path, open(token_path, 'rb'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
}

response = requests.post(
    f"{base_url}/api/v1/canarytoken/factory/create",
    data=request_parameters,
    files=request_files,
    timeout=30
)
response.raise_for_status()
response_json = response.json()

word_token_id = response_json['canarytoken']['canarytoken']

# Fetch the word token
request_parameters = {
    'factory_auth': FACTORY_AUTH,
    'canarytoken': word_token_id
}

response = requests.get(
    f"{base_url}/api/v1/canarytoken/factory/download",
    allow_redirects=True,
    params=request_parameters,
    timeout=30
)

response.raise_for_status()

with open(token_path, 'wb') as f:
    f.write(response.content)

# Unzip Word doc to insert AWS Token and rebuild.
print("Embed AWS token in Word token")
tmp_folder = os.path.join(token_folder, 'tmp_token_work_dir')

with zipfile.ZipFile(token_path, 'r') as zip_ref:
    zip_ref.extractall(tmp_folder)

with open(os.path.join(tmp_folder, 'word', 'document.xml'), 'r', encoding='utf-8') as f:
    filedata = f.read()
    filedata1 = filedata.replace(AWS_TOKEN_PLACEHOLDER_ID, token_aws_access_key_id)
    filedata2 = filedata1.replace(AWS_TOKEN_PLACEHOLDER_KEY, token_aws_secret_access_key)

with open(os.path.join(tmp_folder, 'word', 'document.xml'), 'w', encoding='utf-8') as f:
    f.write(filedata2)
    f.close()

with zipfile.ZipFile(token_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
    for folder_name, subfolders, filenames in os.walk(tmp_folder):
        for filename in filenames:
            file_path = os.path.join(folder_name, filename)
            zip_ref.write(file_path, arcname=os.path.relpath(file_path, tmp_folder))

shutil.rmtree(tmp_folder)

# Randomise Token metadata.
Current_epoch = int(time.time())
Max_old_epoch = Current_epoch - 31536000
Modified_timestamp = random.randint(Max_old_epoch, Current_epoch)

os.chmod(os.path.join(TARGET_FOLDER, random_token_folder), 0o777)
os.chmod(os.path.join(TARGET_FOLDER, random_token_folder, random_token_sub_folder), 0o777)
os.chmod(token_path, 0o777)

os.utime(os.path.join(TARGET_FOLDER, random_token_folder), (Modified_timestamp, Modified_timestamp))
os.utime(os.path.join(TARGET_FOLDER, random_token_folder, random_token_sub_folder), (Modified_timestamp, Modified_timestamp))
os.utime(token_path, (Modified_timestamp, Modified_timestamp))

print(f"Token successfully saved to {token_path}")
