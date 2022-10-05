#!/usr/bin/env python3
"""
Canary - API to CSV
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
import csv
import requests

# The only variable that need to be set is the AUTH_TOKEN and DOMAIN_HASH
# They can be set as environmental variables or the the file below by
# setting auth_token_default and domain_hash_default.
# To fine the API auth token and domain hash go to the settings page of your console
# (https://1234abcd.canary.tools/settings where "1234abcd" is your console's unique CNAME)
AUTH_TOKEN_DEFAULT = "deadbeef12345678"
DOMAIN_HASH_DEFAULT = "1234abcd"

# Customise the script output by configuring these optional variables
PAGE_SIZE = 1500 # The number of incidents to get per page
INCIDENTS_SINCE = 0 # 0 = Default to get all incidents
ADD_BLANK_NOTES_COLUMN = False # Set True to add a notes column you can add notes too
ADD_ADDITIONAL_EVENT_DETAILS = False # Set to True to add additional event details to the csv
SORT_ON_COLUMN = 0 # Column on which the csv should be sorted; First column index is 0

# Use the environmental variables if set otherwise use the default variables
AUTH_TOKEN = os.environ.get('AUTH_TOKEN', AUTH_TOKEN_DEFAULT)
DOMAIN_HASH = os.environ.get('DOMAIN_HASH', DOMAIN_HASH_DEFAULT)

# Prepare script variables
RESULTS_FILE_NAME = f"{DOMAIN_HASH}_alerts.csv"
STATE_STORE_FILE_NAME = f"{DOMAIN_HASH}_state_store.txt"
BASE_URL = f"https://{DOMAIN_HASH}.canary.tools"
LOADED_STATE = False # Boolean variable to track if previous state was recovered

#Increase the field size for csv
MAX_INT = sys.maxsize
while True:
    # decrease the MAX_INT value by factor 10
    # as long as the OverflowError occurs.
    try:
        csv.field_size_limit(MAX_INT)
        break
    except OverflowError:
        MAX_INT = int(MAX_INT/10)

def _key(row):
    return row[SORT_ON_COLUMN]

def sort_results():
    """Sort the csv file containing the results
    """
    print('Sorting csv file')
    with open(RESULTS_FILE_NAME, 'r', encoding='utf-8') as file_in:
        reader = csv.reader(file_in, dialect='excel')
        header = next(reader)
        rows = sorted(reader, key=_key)
    with open(RESULTS_FILE_NAME, 'w', encoding='utf-8', newline="") as file_out:
        writer = csv.writer(file_out, dialect='excel')
        writer.writerow(header)
        writer.writerows(rows)

def stop():
    """Print relevant message before exiting
    """
    print('') # Newline to not override status feedback
    sort_results()
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

    header = []

    if ADD_BLANK_NOTES_COLUMN:
        header.append("Notes")

    header.append("Updated ID")
    header.append("Date and Time")
    header.append("Alert Description")
    header.append("Target")
    header.append("Target Port")
    header.append("Attacker")
    header.append("Attacker RevDNS")

    if ADD_ADDITIONAL_EVENT_DETAILS:
        header.append("Additional Events")

    return header

def extract_incident_data(incidents_to_process: list) -> str:
    """Process the incidents in the list and extract required information

    Args:
        incidents (list): Incidents to process

    Returns:
        str: String with csv data
    """

    processed_incidents = []

    open_flag = 'a' # Append to file if it exists
    if not os.path.exists(RESULTS_FILE_NAME):
        # Prep new csv file if it does not exist
        open_flag = 'w'
        processed_incidents.append(create_csv_header())

    for incident in incidents_to_process:
        incident_data = []
        if ADD_BLANK_NOTES_COLUMN:
            incident_data.append("")

        incident_data.append(incident.get('updated_id', None))

        description = incident.get('description', None)

        incident_data.append(f"{description.get('created_std', '')}")
        incident_data.append(f"{description.get('description', '')}")
        incident_data.append(f"{description.get('dst_host', '')}")
        incident_data.append(f"{description.get('dst_port', '')}")
        incident_data.append(f"{description.get('src_host', '')}")
        incident_data.append(f"{description.get('src_host_reverse', '')}")

        if ADD_ADDITIONAL_EVENT_DETAILS:
            events_data = json.dumps(description.get('events', ''), separators=(',', ':'))
            incident_data.append(f"{events_data}")

        processed_incidents.append(incident_data)

    with open(RESULTS_FILE_NAME, open_flag, encoding='utf-8') as file_out:
        writer = csv.writer(file_out, dialect='excel')
        writer.writerows(processed_incidents)

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
print("Working: .", end='', flush=True)

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
    cursor = json_data.get('cursor', {}).get('next', None)
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

extract_incident_data(incidents)

# There is no more data to read, we can stop
if cursor is None:
    stop()

# While we have a pagination cursor keep loading data
while cursor is not None:
    print(".", end='', flush=True)

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

    extract_incident_data(incidents)

    # There is no more data to read, we can stop
    if cursor is None:
        stop()
