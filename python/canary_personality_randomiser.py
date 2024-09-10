#!/usr/bin/env python3
# canary_personality_randomiser.py

import argparse
import json
import urllib.request
import sys
import random

# Create argument parser
parser = argparse.ArgumentParser(description='Canary Personality Randomiser.py')
parser.add_argument('-domain', help='Your Console Domain Hash: a123456b', required=True)
parser.add_argument('-apikey', help='Your API Key: c6858257b6f32986d7b44', required=True)
args = parser.parse_args()

# Extract command line arguments
DOMAIN = args.domain
AUTHTOKEN = args.apikey

# Fetch online birds
o_url = f"https://{DOMAIN}.canary.tools/api/v1/devices/live"

o_request_data = {
    "auth_token": AUTHTOKEN
}

o_request_data = urllib.parse.urlencode(o_request_data).encode("utf-8")
o_request_url = f"{o_url}?{o_request_data.decode('utf-8')}"

o_response = urllib.request.urlopen(o_request_url)
o_response = o_response.read().decode("utf-8")
o_response_json = json.loads(o_response)

if 'devices' not in o_response_json:
    print("No Canary devices found.")
    exit()
else:
    print("Randomising personalities on the following Canaries:")
    print()

    for index, device in enumerate(o_response_json['devices'], 1):
        print(f"{index}. {device['id']} - {device['name']} - {device['note']} - https://{DOMAIN}.canary.tools/nest/canary/{device['id']}")

    # Get list of personalities for bird
    for device in o_response_json['devices']:
        id = device['id']
        p_url = f"https://{DOMAIN}.canary.tools/api/v1/personalities/list"

        p_request_data = {
            "auth_token": AUTHTOKEN,
            "node_id": id,
            "include_settings": False,
            "as_string": False
        }

        p_request_data_encoded = urllib.parse.urlencode(p_request_data).encode("utf-8")
        p_request = urllib.request.Request(p_url, data=p_request_data_encoded, method="GET")
        p_response = urllib.request.urlopen(p_request)
        p_response = p_response.read().decode("utf-8")
        p_response_json = json.loads(p_response)

        if 'result' in p_response_json and p_response_json['result'] != 'success':
            print(f"Failed to fetch personality list for {id}: {p_response}")
        else:
            p_codes = []
            
            for category in p_response_json['personalities']:
                for cat_name, personalities in category.items():
                    for personality, code in personalities.items():
                        if code:  # To avoid empty codes like "Pick One"
                            p_codes.append(code)

            r_pers = random.choice(p_codes)
            # Randomise Bird personality

            r_url = f"https://{DOMAIN}.canary.tools/api/v1/device/configure_personality"

            r_request_data = {
                "auth_token": AUTHTOKEN,
                "node_id": id,
                "personality": r_pers
            }

            r_request_data_encoded = urllib.parse.urlencode(r_request_data).encode("utf-8")
            r_request = urllib.request.Request(r_url, data=r_request_data_encoded)

            r_response = urllib.request.urlopen(r_request)
            r_response = r_response.read().decode("utf-8")
            r_response_json = json.loads(r_response)

            if 'result' in r_response_json and r_response_json['result'] != 'success':
                print(f"Failed to set personality for {id}: {r_response}")
            else:
                print(f"Applied {r_pers} personality to Canary {id}")
    sys.exit()