#!/usr/bin/env python3
"""
Canary - API too CSV
This script is intended to get basic alert information into a SIEM. Rather than
pulling full alert information, this script pulls just enough data to correlate
Canary and Canarytoken alerts with other events or to trigger the IR process.

On first run the script will load all events from the console using pagination
to prevent GET calls to the console from timing out.
All consecutive runs of the script will only load new events and append them
to the result file.
The script keeps track of events exported and only pulls in new alerts.
To reset this script, simply delete the {DOMAIN_HASH}_state_store.txt
file saved alongside the results file {DOMAIN_HASH}_alerts.csv.
"""

import os
import sys
import json
import requests

# The only variable that need to be set is the AUTH_TOKEN and DOMAIN_HASH
# They can be set as environmental variables or the the file below by
# setting auth_token_default and domain_hash_default.
# To fine the API auth token and domain hash go to the settings page of your console
# (https://1234abcd.canary.tools/settings where "1234abcd" is your console's unique CNAME)
AUTH_TOKEN_DEFAULT = "deadbeef12345678"
DOMAIN_HASH_DEFAULT = "1234abcd"

# Customise the script output by configuring these optional variables
PAGE_SIZE = 500 # The number of incidents to get per page
PAGE_SIZE = 1
INCIDENTS_SINCE = 0 # 0 = Default to get all incidents
SORT_ON_COLUMN = 1 # Set the column on which the csv should be sorted on update
ADD_BLANK_NOTES_COLUMN = False # Set to True to add a notes column to the csv that you can add notes too
ADD_ADDITIONAL_EVENT_DETAILS = False # Set to True to add additional event details to the csv

# Use the environmental variables if set otherwise use the default variables
AUTH_TOKEN = os.environ.get('AUTH_TOKEN', AUTH_TOKEN_DEFAULT)
DOMAIN_HASH = os.environ.get('DOMAIN_HASH', DOMAIN_HASH_DEFAULT)

# Prepare script variables
RESULTS_FILE_NAME = f"{DOMAIN_HASH}_alerts.csv"
STATE_STORE_FILE_NAME = f"{DOMAIN_HASH}_state_store.txt"
BASE_URL = f"https://{DOMAIN_HASH}.canary.tools"
LOADED_STATE = False # Boolean variable to track if previous state was recovered

# sort_results () {
#     cp "$RESULTS_FILE_NAME" "$RESULTS_FILE_NAME.unsorted"
#     head -n1 "$RESULTS_FILE_NAME.unsorted" > "$RESULTS_FILE_NAME" # Save the header in the file
#     tail -n+2 "$RESULTS_FILE_NAME.unsorted" | sort -t ',' -k $SORT_ON_COLUMN,$SORT_ON_COLUMN -n >> "$RESULTS_FILE_NAME" # Sort the file
#     rm -f "$RESULTS_FILE_NAME.unsorted"
# }

def stop():
    """Print relevant message before exiting
    """
    # sort_results()
    print('') # Newline to not override status feedback
    if not LOADED_STATE:
        print(f"Results saved in {RESULTS_FILE_NAME}")
    else:
        print(f"Updated results in {RESULTS_FILE_NAME}")
    sys.exit(0)

def fail(msg :str):
    """Print failure message before exiting

    Args:
        msg (str): Message to print
    """
    print('') # Newline to not override status feedback
    print(msg)
    sys.exit(1)

# To change what data is processed from the incidents update
# the create_csv_header and extract_incident_data functions
def create_csv_header():
    """Function to write the csv file header
    """

    header = ""

    if ADD_BLANK_NOTES_COLUMN:
        header += "Notes,"

    header += "Updated ID"
    header += ",Date and Time"
    header += ",Alert Description"
    header += ",Target"
    header += ",Target Port"
    header += ",Attacker"
    header += ",Attacker RevDNS"

    if ADD_ADDITIONAL_EVENT_DETAILS:
        header += ",Additional Events"

    return header

def extract_incident_data(incidents_to_process: list) -> str:
    """Process the incidents in the list and extract required information

    Args:
        incidents (list): Incidents to process

    Returns:
        str: String with csv data
    """

    incident_data = []
    for incident in incidents_to_process:
        data_line = ""
        if ADD_BLANK_NOTES_COLUMN:
            data_line += ","

        data_line += f"{incident.get('updated_id', None)}"

        description = incident.get('description', None)

        data_line += f",{description.get('created_std', '')}"
        data_line += f",{description.get('description', '')}"
        data_line += f",{description.get('dst_host', '')}"
        data_line += f",{description.get('dst_port', '')}"
        data_line += f",{description.get('src_host', '')}"
        data_line += f",{description.get('src_host_reverse', '')}"

        if ADD_ADDITIONAL_EVENT_DETAILS:
            data_line += f",{json.dumps(description.get('events', ''))}"

        incident_data.append(data_line)

    return '\n'.join(incident_data)

# Ping the console to ensure reachability
print("Check console is reachable")
request_parameters = {
    'auth_token': AUTH_TOKEN
}
try:
    response = requests.get(
        f"{BASE_URL}/api/v1/ping",
        params=request_parameters,
        timeout=30
    )
    response.raise_for_status()
except requests.exceptions.HTTPError as error:
    message = f"The console threw and HTTPError:\nError:{error}\nResponse: {response.text}"
    fail(msg=message)
except requests.exceptions.RequestException as error:
    message = f"Failed to communicate with the console:\n{error}"
    fail(msg=message)

# Check if we have state from the last incidents fetch
if os.path.exists(STATE_STORE_FILE_NAME):
    # We have state, so continue from last point and append to result file
    with open(STATE_STORE_FILE_NAME, 'r', encoding='utf-8') as f:
        INCIDENTS_SINCE=f.read()
    LOADED_STATE = True

if not LOADED_STATE:
    print("No state found, fetching all incidents from the console. (This may take a while)")

print(f"Fetching incidents from console: {BASE_URL}")
print("Working: .", end='')

# Get incidents
request_parameters = {
    'auth_token': AUTH_TOKEN,
    'incidents_since': INCIDENTS_SINCE,
    'limit': PAGE_SIZE,
    'shrink': 'true'
}
try:
    response = requests.get(
        f"{BASE_URL}/api/v1/incidents/all",
        params=request_parameters,
        timeout=30
    )
    response.raise_for_status()
    json_data = response.json()
    max_updated_id = json_data.get('max_updated_id', None)
    cursor = json_data.get('cursor', [None]).get('next', None)
    incidents = json_data.get('incidents', None)
except requests.exceptions.JSONDecodeError as error:
    message = f"Unable to process console return:\nError:{error}\nResponse: {response.text}"
    fail(msg=message)
except requests.exceptions.HTTPError as error:
    message = f"The console threw and HTTPError:\nError:{error}\nResponse: {response.text}"
    fail(msg=message)
except requests.exceptions.RequestException as error:
    message = f"Failed to communicate with the console:\n{error}"
    fail(msg=message)

if max_updated_id is None:
    print('') # Newline to not override status feedback
    print("No new events found on the console")
    sys.exit(0)
else:
    with open(STATE_STORE_FILE_NAME, 'w+', encoding='utf-8') as f:
        f.write(f"{max_updated_id}")

INCIDENT_DATA = extract_incident_data(incidents)
if INCIDENT_DATA != "":
    with open(RESULTS_FILE_NAME, 'a', encoding='utf-8') as f:
        if not LOADED_STATE:
            if ADD_BLANK_NOTES_COLUMN:
                # Increment the column sorting index by one if a note column is added
                SORT_ON_COLUMN += 1
            f.write(f"{create_csv_header()}\n")
        f.write(f"{INCIDENT_DATA}\n")

# There is no more data to read, we can stop
if cursor is None:
    stop()

# While we have a pagination cursor keep loading data
while cursor is not None:
    print(".", end='')

    request_parameters = {
        'auth_token': AUTH_TOKEN,
        'cursor': cursor,
        'shrink': 'true'
    }
    try:
        response = requests.get(
            f"{BASE_URL}/api/v1/incidents/all",
            params=request_parameters,
            timeout=30
        )
        response.raise_for_status()
        json_data = response.json()
        cursor = json_data.get('cursor', [None]).get('next', None)
        incidents = json_data.get('incidents', None)
    except requests.exceptions.JSONDecodeError as error:
        message = f"Unable to process console return:\nError:{error}\nResponse: {response.text}"
        fail(msg=message)
    except requests.exceptions.HTTPError as error:
        message = f"The console threw and HTTPError:\nError:{error}\nResponse: {response.text}"
        fail(msg=message)
    except requests.exceptions.RequestException as error:
        message = f"Failed to communicate with the console:\n{error}"
        fail(msg=message)

    INCIDENT_DATA = extract_incident_data(incidents)
    if INCIDENT_DATA != "":
        with open(RESULTS_FILE_NAME, 'a', encoding='utf-8') as f:
            f.write(f"{INCIDENT_DATA}\n")

    # There is no more data to read, we can stop
    if cursor is None:
        stop()
