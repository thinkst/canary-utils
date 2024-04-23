
#!/usr/bin/env python3
"""
Canary Backup and Restore Tool

This script provides a CLI for backing up and restoring settings for Canaries using the Canary API.

Usage:
    backup_restore_canary.py -domain <DOMAIN> -apikey <APIKEY>
    backup_restore_canary.py -domain <DOMAIN> -apikey <APIKEY> -restore

Options:
    -domain     Your Canary Console Domain Hash (e.g., a123456b)
    -apikey     Your Canary API Key (e.g., c6858257b6f32986d7b44)
    -restore    Restore data instead of backing up.

Examples:
    # Backup Canary devices
    backup_restore_canary.py -domain a123456b -apikey c6858257b6f32986d7b44

    # Restore Canary devices
    backup_restore_canary.py -domain a123456b -apikey c6858257b6f32986d7b44 -restore

How it Works:
    - Backup: The script fetches settings for selected Canary devices from the Canary API and saves them
      as JSON files in the current directory. Each file is named after the Canary's Node ID.
    
    - Restore: The script checks for the previously backed up JSON files in the current directory
      with names matching the format '{Node ID}.json'. It prompts the user to select one of these
      files to restore settings from. It then prompts for the target Node ID where the settings will be restored.

Note:
    - Backup files are saved in the current directory. Make sure you have write permissions.
    - Backup files include the IP and MAC settings, keep this in mind when restoring.
    - Backup files are pure JSON dumps of your Canary configs, these can be manually tweaked if needed.
    - Before restoring settings, ensure that the backup files exist in the same directory as the script.
"""

import argparse
import json
import urllib.request
import os
import re

def backup_canary(DOMAIN, AUTHTOKEN, restore=False):
    # Initialize counters
    successful_writes = 0
    failed_writes = 0

    # Fetch bird details
    url = f"https://{DOMAIN}.canary.tools/api/v1/devices/all"

    json_response = {
        "auth_token": AUTHTOKEN
    }

    json_response = urllib.parse.urlencode(json_response).encode("utf-8")
    full_url = f"{url}?{json_response.decode('utf-8')}"

    response = urllib.request.urlopen(full_url)
    response_json_response = response.read().decode("utf-8")
    json_response = json.loads(response_json_response)

    if 'devices' not in json_response or not json_response['devices']:
        print("No Canary devices found.")
        exit()
    else:
        print("\nYou have access to the following Canaries:")
        print()

        # Display the IDs to the user
        print("Available IDs:")
        print("Selector. Node ID - Name - Notes - URL:")
        for index, device in enumerate(json_response['devices'], 1):
            print(f"{index}. {device['id']} - {device['name']} - {device['note']} - https://{DOMAIN}.canary.tools/nest/canary/{device['id']}")

        # Prompt the user to select IDs
        selected_ids = []
        while True:
            choice = input("\nEnter the number(s) of the ID(s) you need (comma-separated), or type 'done' to finish: ")
            if choice.lower() == 'done':
                break
            try:
                choices = [int(num.strip()) for num in choice.split(',')]
                selected_ids.extend([json_response['devices'][num - 1]['id'] for num in choices])
            except (ValueError, IndexError):
                print("\nInvalid input. Please enter the number(s) corresponding to the ID(s) you need.")

        # Display the selected IDs
        print("\nSelected IDs:")
        for id in selected_ids:
            print(id)

        # Prompt the user to confirm proceeding
        while True:
            confirm = input("\nDo you want to proceed with backing up the selected IDs? (yes/no): ").strip().lower()
            if confirm in ('yes', 'no'):
                break
            else:
                print("\nInvalid input. Please enter 'yes' or 'no'.")

        if confirm == 'yes':
            for id in selected_ids:
                url = f"https://{DOMAIN}.canary.tools/api/v1/device/info"

                data = {
                    "auth_token": AUTHTOKEN,
                    "node_id": id,
                    "settings": True,
                    "exclude_fixed_settings": True
                }

                data_encoded = urllib.parse.urlencode(data).encode("utf-8")
                request = urllib.request.Request(url, data=data_encoded, method="GET")
                
                try:
                    response = urllib.request.urlopen(request)
                    response_data = response.read().decode("utf-8")
                    json_response = json.loads(response_data)
                    
                    if 'result' in json_response and json_response['result'] != 'success':
                        print(f"Failed to backup Canary {id}: {json_response}")
                        failed_writes += 1
                    else:
                        with open(f"{id}.json", "w") as json_file:
                            json.dump(json_response['device']['settings'], json_file)
                        successful_writes += 1
                except Exception as e:
                    print(f"\nFailed to retrieve data for Canary {id}: {e}")
                    failed_writes += 1

            print(f"\nSuccessful backups made: {successful_writes}")
            print(f"Failed backups: {failed_writes}")

        else:
            print("\nYou opted not to proceed, goodbye!")
            exit()


def restore_canary(DOMAIN, AUTHTOKEN):
    # Check for files in the current directory with the specified name format
    file_pattern = re.compile(r'.{16}\.json')
    file_names = [file for file in os.listdir() if file_pattern.match(file)]

    if not file_names:
        print("\nNo files found for restore.")
        return

    # Display the found file names with numbers
    print("Files found for restore:")
    for index, file_name in enumerate(file_names, 1):
        print(f"{index}. {file_name}")

    # Prompt the user to select one ID to restore
    selected_id = None
    while True:
        choice = input("\nEnter the number of the Node ID you want to restore, or type 'cancel' to cancel: ")
        if choice.lower() == 'cancel':
            return
        try:
            selected_index = int(choice.strip()) - 1
            if selected_index not in range(len(file_names)):
                raise ValueError()
            selected_id = file_names[selected_index]
            print(f"\nFile selected for restore: {selected_id}")
            break
        except ValueError:
            print("\nInvalid input. Please enter a valid number or 'cancel'.")

    # Prompt the user for the target ID to restore
    while True:
        target_id = input("\nEnter the target Node ID to restore: ")
        if len(target_id) == 16:
            break
        else:
            print("\nInvalid Node ID. Please enter a 16-character Node ID.")

    # Prompt the user to confirm proceeding
    while True:
        print("\n[!] Remember, backups include IP and MAC configuration, please manually edit the backup file if needed, or contact support.")
        confirm = input(f"\nAre you sure you want to restore {selected_id} to {target_id}? (yes/no): ").strip().lower()
        if confirm in ('yes', 'no'):
            break
        else:
            print("\nInvalid input. Please enter 'yes' or 'no'.")

    if confirm == 'yes':

        with open(selected_id, "r") as file:
            canary_settings = json.load(file)
            serialized_json = json.dumps(canary_settings)

        url = f"https://{DOMAIN}.canary.tools/api/v1/device/configure"

        data = {
            "auth_token": AUTHTOKEN,
            "node_id": target_id,
            "settings": serialized_json
        }

        data_encoded = urllib.parse.urlencode(data).encode("utf-8")
        request = urllib.request.Request(url, data=data_encoded, method="POST")
        
        try:
            response = urllib.request.urlopen(request)
            response_data = response.read().decode("utf-8")
            json_response = json.loads(response_data)
            
            if 'result' in json_response and json_response['result'] == 'success':
                print(f"\nSuccessfully restored Canary {target_id}")
                print(f"\nThank you for using the restore tool, goodbye!")
                exit()
        except Exception as e:
            print(f"\nFailed to restore data for Canary {id}: {e}")

    else:
        print("\nYou opted not to proceed, goodbye!")
        exit()

if __name__ == "__main__":
    # Create argument parser
    parser = argparse.ArgumentParser(description='Canary Backup and Restore Tool')
    parser.add_argument('-domain', help='Your Console Domain Hash: a123456b', required=True)
    parser.add_argument('-apikey', help='Your API Key: c6858257b6f32986d7b44', required=True)
    parser.add_argument('-restore', help='Restore data instead of backing up', action='store_true')
    args = parser.parse_args()

    DOMAIN = args.domain
    AUTHTOKEN = args.apikey
    restore = args.restore

    if restore:
        restore_canary(DOMAIN, AUTHTOKEN)
    else:
        backup_canary(DOMAIN, AUTHTOKEN)