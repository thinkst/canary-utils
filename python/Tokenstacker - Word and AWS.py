import socket
import zipfile
import requests
import os
import shutil
import time
import random
import re

# Tokenstacker - Word and AWS.py

# This script will download a Word Template from a private github repo, Token it, then embed an AWS API Token inside and save it to a realistic directory.
# Edit the variables in lines 16 - 22 to match your deployment.
# Contact support@canary.tools for assistance.

Domain = 'ABC123.canary.tools' # Enter your Console domain between the quotes. e.g. 1234abc.canary.tools
FactoryAuth = 'ABC123' # Enter your Factory auth key. e.g a1bc3e769fg832hij3 https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
FlockID = 'flock:default' # Enter the desired flock to place tokens in. https://docs.canary.tools/flocks/queries.html#list-flock-sensors
WordTemplate = 'https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx' # URL of your template, Private Repo's should follow the format of https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx, public files can be referenced by https://github.com/owner/repo/raw/main/template.docx
AWSToken_Placeholder_id = 'AWS_ACCESS_KEY_ID' # The text within the word template that will be replaced with an AWS Token ID.
AWSToken_Placeholder_key = 'AWS_SECRET_ACCESS_KEY' # The text within the word template that will be replaced with an AWS Token Key.
Personal_Access_Token = 'gh_abcdefghijklmnop123' # Personal access token generated on Github, if blank the template will be generically downloaded. https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token

# Randomise the Token deployment path, this list can edited to your preferences.

TokenFolder_list = ['Acronis','Github','Zoho', 'Confluence', 'Hubspot', 'Okta', 'Gitlab', 'Postman', 'Veeam', 'Redstore']
TokenSubFolder_list = ['Temp','Backup', 'Archive', 'Secrets', ]
TokenFilename_list = ['Emergency.docx', 'Credentials.docx', 'Access.docx', 'Accounts.docx']

TokenFolder_selection = random.choice(TokenFolder_list) 
TokenSubFolder_selection = random.choice(TokenSubFolder_list)
TokenFilename_selection = random.choice(TokenFilename_list)

TokenPath = os.path.join(os.path.expanduser('~'), TokenFolder_selection, TokenSubFolder_selection, TokenFilename_selection)
TokenFilename = os.path.split(TokenPath)[1]

if not os.path.exists(TokenPath):
    os.makedirs(os.path.split(TokenPath)[0])

#Create AWS Token on Canary Console
CreateToken_AWS_payload = {
'factory_auth': FactoryAuth,
'kind': 'aws-id',
'flock_id' : FlockID,
'memo': socket.gethostname()+' - Embedded AWS Token in '+ TokenPath,
}

Create_Token_AWS_request = requests.post('https://'+Domain+'/api/v1/canarytoken/factory/create', data=CreateToken_AWS_payload)
Create_Token_AWS_result = Create_Token_AWS_request.json()

AWS_TokenID = Create_Token_AWS_result['canarytoken']['canarytoken']

Fetch_Token_AWS_payload = {
'factory_auth': FactoryAuth,
'canarytoken': AWS_TokenID
}

Fetch_Token_AWS_request = requests.get('https://'+Domain+'/api/v1/canarytoken/factory/download', allow_redirects=True, params=Fetch_Token_AWS_payload)

AWSToken_id = re.findall('(?<![A-Z0-9])[A-Z0-9]{20}(?![A-Z0-9])', Fetch_Token_AWS_request.content.decode())
AWSToken_key = re.findall('([a-zA-Z0-9+/]{40})', Fetch_Token_AWS_request.content.decode())
AWSToken_id = ''.join(AWSToken_id)
AWSToken_key = ''.join(AWSToken_key)

#Fetch Word Template.

Fetch_WordTemplate_payload = {
'Authorization': 'token '+Personal_Access_Token,
'Accept': 'application/vnd.github.v3.raw'
}

if Personal_Access_Token != '':
    print('Fetching Template with Github Access Token')
    Fetch_WordTemplate_request = requests.get(WordTemplate, headers=Fetch_WordTemplate_payload)
else:
    print('Fetching Template generically')
    Fetch_WordTemplate_request = requests.get(WordTemplate) 

if Fetch_WordTemplate_request.status_code != requests.codes.ok:
    print('[!] Could not fetch Word template.')
    exit()
else:
    open(TokenPath, 'wb').write(Fetch_WordTemplate_request.content)

# Upload template to Canary Console for Tokening

Create_Token_Word_payload = {
'factory_auth': FactoryAuth,
'flock_id' : FlockID,
'kind': 'doc-msword',
'memo': socket.gethostname()+' - '+TokenPath,
}

Create_Token_Word_files = {
'doc': (TokenPath, open(TokenPath, 'rb'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
}

Create_Token_Word_request = requests.post('https://'+Domain+'/api/v1/canarytoken/factory/create', data=Create_Token_Word_payload, files=Create_Token_Word_files)

if Create_Token_Word_request.status_code != requests.codes.ok:
    print('[!] Creation of Word Token failed.')
    exit()
else:
    Create_Token_Word_result = Create_Token_Word_request.json()

Word_TokenID = Create_Token_Word_result['canarytoken']['canarytoken']

# Replace template with Tokened version locally.
Fetch_Token_Word_payload = {
    'factory_auth': FactoryAuth,
    'canarytoken': Word_TokenID
}

Fetch_Token_Word_request = requests.get('https://'+Domain+'/api/v1/canarytoken/factory/download', allow_redirects=True, params=Fetch_Token_Word_payload)

if Fetch_Token_Word_request.status_code != requests.codes.ok:
    print('[!] Fetching of Word Token failed.')
    exit()

open(TokenPath, 'wb').write(Fetch_Token_Word_request.content)

# Unzip Word doc to insert AWS Token and rebuild.

with zipfile.ZipFile(TokenPath, 'r') as zip_ref:
    zip_ref.extractall(os.path.join(os.path.split(TokenPath)[0], 'temp'))

with open(os.path.join(os.path.split(TokenPath)[0], 'temp', 'word', 'document.xml'), 'r') as file :
    filedata = file.read()
    replace_id = filedata.replace(AWSToken_Placeholder_id,AWSToken_id)
    replace_key = replace_id.replace(AWSToken_Placeholder_key,AWSToken_key)
    
with open(os.path.join(os.path.split(TokenPath)[0], 'temp', 'word', 'document.xml'), 'w') as file :
    file.write(replace_key)
    file.close()

with zipfile.ZipFile(TokenPath, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
    for folder_name, subfolders, filenames in os.walk(os.path.join(os.path.split(TokenPath)[0], 'temp/')):
        for filename in filenames:
            file_path = os.path.join(folder_name, filename)
            zip_ref.write(file_path, arcname=os.path.relpath(file_path, os.path.join(os.path.split(TokenPath)[0], 'temp/')))

shutil.rmtree(os.path.join(os.path.split(TokenPath)[0], 'temp/'))

#Randomise Token metadata.

Current_epoch = int(time.time())
Max_old_epoch = Current_epoch - 31536000
Modified_timestamp = random.randint(Max_old_epoch, Current_epoch)

os.utime(os.path.join(os.path.expanduser('~'), TokenFolder_selection), (Modified_timestamp, Modified_timestamp))
os.utime(os.path.join(os.path.expanduser('~'), TokenFolder_selection, TokenSubFolder_selection), (Modified_timestamp, Modified_timestamp))
os.utime(TokenPath, (Modified_timestamp, Modified_timestamp))

print('[*]Token successfully saved to : '+TokenPath)