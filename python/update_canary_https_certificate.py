#!/usr/bin/env python3
"""
Canary Certificate Update Tool

This script provides a CLI for updating the certificate for Canaries using the Canary API.

Usage:
    update_canary_https_certificate.py -domain <DOMAIN> -apikey <APIKEY> -node <NODEID> -privatekey <PRIVATEKEYCERT> -publickey <PUBLICKEY>

Options:
    -domain     Your Canary Console Domain Hash (e.g., a123456b)
    -apikey     Your Canary API Key (e.g., c6858257b6f32986d7b44)
    -node       The target Canary Node ID (e.g., 00000000fc738ff7)
    -key The new TLS private key .key file (e.g., /users/admin/canary_key.key)
    -cert  The new TLS public certficate cert file (e.g., /users/admin/canary_cert.crt)

Example:
    update_canary_https_certificate.py -domain a123456b -apikey c6858257b6f32986d7b44 -node 00000000fc738ff7 -key '/Users/admin/Downloads/code.key' -cert '/Users/admin/Downloads/code.crt'

    Successfully pushed new certificates to Canary: 00000000fc738ff7

    Thank you for using the update tool, goodbye!
"""

import argparse
import json
import urllib.request

# Create argument parser
parser = argparse.ArgumentParser(description='Canary Certificate Update Tool')
parser.add_argument('-domain', help='Your Console Domain Hash: a123456b', required=True)
parser.add_argument('-apikey', help='Your API Key: c6858257b6f32986d7b44', required=True)
parser.add_argument('-node', help='Target Canary Node ID', required=True)
parser.add_argument('-key', help='New Private Key .key file', required=True)
parser.add_argument('-cert', help='New Public cert .crt file', required=True)
args = parser.parse_args()

DOMAIN = args.domain
APIKEY = args.apikey
NODE = args.node
KEY = args.key
CERT = args.cert

# Fetch bird details
url = f"https://{DOMAIN}.canary.tools/api/v1/device/info"

data = {
    "auth_token": APIKEY,
    "node_id": NODE,
    "settings": True,
    "exclude_fixed_settings": True
}

data_encoded = urllib.parse.urlencode(data).encode("utf-8")
request = urllib.request.Request(url, data=data_encoded, method="GET")

try:
    response = urllib.request.urlopen(request)
    response_data = response.read().decode("utf-8")
    json_response = json.loads(response_data)    
    current_settings = json_response['device']['settings']

except Exception as e:
    print(f"\nFailed to retrieve data for Canary {NODE}: {e}")

with open(KEY, 'r') as key_file:
    new_key = key_file.read()

with open(CERT, 'r') as cert_file:
    new_cert = cert_file.read()

if "https.certificate" in current_settings:
    current_settings["https.certificate"] = new_cert

if "https.key" in current_settings:
    current_settings["https.key"] = new_key

url = f"https://{DOMAIN}.canary.tools/api/v1/device/configure"

data = {
    "auth_token": APIKEY,
    "node_id": NODE,
    "settings": json.dumps(current_settings)
}

data_encoded = urllib.parse.urlencode(data).encode("utf-8")
request = urllib.request.Request(url, data=data_encoded, method="POST")

try:
    response = urllib.request.urlopen(request)
    response_data = response.read().decode("utf-8")
    json_response = json.loads(response_data)
    
    if 'result' in json_response and json_response['result'] == 'success':
        print(f"\nSuccessfully pushed new certificates to Canary: {NODE}")
        print(f"\nThank you for using the update tool, goodbye!")
        exit()
except Exception as e:
    print(f"\nFailed to push new cert data for Canary {NODE}: {e}")