import requests
import json
import argparse

# Create argument parser
parser = argparse.ArgumentParser(description='Edit Bird MAC Script')
parser.add_argument('-domain', help='Your Console Domain Hash: a123456b', required=True)
parser.add_argument('-apikey', help='Your Console API Key: c6858257b6f32986d7b44', required=True)
parser.add_argument('-nodeid', help='The Node ID of the Bird you\'d like to tweak: 00022a1e1ca8a6cc', required=True)
parser.add_argument('-macprefix', help='Your preferred new MAC prefix: 1A:2B:3C', required=True)
args = parser.parse_args()

# Extract command line arguments
DOMAIN = args.domain
AUTHTOKEN = args.apikey
NODE_ID = args.nodeid
NEW_PREFIX = args.macprefix

# Fetch Bird Details

url = f'https://{DOMAIN}.canary.tools/api/v1/device/configuration_settings'

payload = {
    'auth_token': AUTHTOKEN,
    'node_id': NODE_ID
}

r = requests.get(url, params=payload)

response_json = r.json()
settings_json = response_json['settings']
birdname = settings_json['device.name']
bird_mac_prefix = settings_json['device.mac_prefix']
bird_mac_suffix = settings_json['device.mac_suffix']

# Replace MAC prefix

settings_json["device.mac_prefix"] = NEW_PREFIX

# Push new prefix

url = f'https://{DOMAIN}.canary.tools/api/v1/device/configure'

payload = {
    'auth_token': AUTHTOKEN,
    'node_id': NODE_ID,
    'settings': json.dumps(settings_json)
}

r = requests.post(url, data=payload)

print(f'\nSettings pushed to {birdname}. Old MAC: {bird_mac_prefix}:{bird_mac_suffix} New MAC: {NEW_PREFIX}:{bird_mac_suffix}')