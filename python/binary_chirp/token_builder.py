#!/usr/bin/env python3

# Binary_Chirp : Token Builder
# Generates executables embedded with a Token to fingerprint a host running them.
# Requires requests, pyinstaller and dnspython to be installed.
# $ pip install requests pyinstaller dnspython
# Quickstart :
# Edit the variables in lines 19-24
# Run the token_builder.py script with $ python3 token__builder.py
# A new binary will be created in the TOKEN_DIRECTORY path.
# Author: Gareth Wood
# Date: 16 Jun 2023
# Version: 1.5
#>

import socket
import os
import re
import shutil
import requests
import PyInstaller.__main__

DOMAIN = "ABC123.canary.tools" # Enter your Console domain between the . e.g. 1234abc.canary.tools
FACTORY_AUTH = "ABC123" # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
TOKEN_DIRECTORY = os.path.expanduser('~/tokened_binary/') # Enter the tokens destination folder
TOKEN_FILENAME = 'admin_password_resetter.exe' # Enter your preferred executable filename. NOTE: for Windows please append .exe
TOKEN_TEMPLATE_NAME = 'chirp_template.py' # Enter the name of you token template

def generate_dns_token():
    create_token_url = 'https://{domain}/api/v1/canarytoken/factory/create'.format(domain=DOMAIN)

    payload = {
        'factory_auth': FACTORY_AUTH,
        'kind': 'dns',
        'memo': "Tokened_binary - {hostname} - {token_path}".format(
            hostname=socket.gethostname(),
            token_path=os.path.join(TOKEN_DIRECTORY, TOKEN_FILENAME)
        ),
    }

    create_token = requests.post(create_token_url, data=payload, timeout=60)
    create_token.raise_for_status()
    result = create_token.json()
    hostname = result['canarytoken']['hostname']

    return hostname

try:
    token_hostname = generate_dns_token()
except requests.exceptions.RequestException as e:
    print('[!] Creation of '+TOKEN_DIRECTORY+TOKEN_FILENAME+' failed.')
    SystemExit(e)

with open(TOKEN_TEMPLATE_NAME, 'r', encoding='utf-8') as file:
    data = file.read()
    updated_token_script = re.sub("TOKEN_DOMAIN = \'.*\'", "TOKEN_DOMAIN = \'{}\'".format(token_hostname), data)

with open(TOKEN_TEMPLATE_NAME, 'w', encoding='utf-8') as file:
    file.write(updated_token_script)
    file.close()

PyInstaller.__main__.run([
    TOKEN_TEMPLATE_NAME,
    '--onefile',
    '--name', TOKEN_FILENAME,
    '--distpath', '.',
    '--clean',
    '--icon', 'icon.ico',
    '-y'
])

os.remove(TOKEN_FILENAME+'.spec')
shutil.rmtree('build')

if not os.path.exists(TOKEN_DIRECTORY):
    os.makedirs(TOKEN_DIRECTORY)

shutil.move(TOKEN_FILENAME, TOKEN_DIRECTORY+TOKEN_FILENAME)