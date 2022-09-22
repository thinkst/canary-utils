#!/bin/bash

# This script is intended to get basic alert information into a SIEM. Rather than
# pulling full alert information, this script pulls just enough data to correlate
# Canary and Canarytoken alerts with other events or to trigger the IR process.
#
# On first run the script will load all events from the console using pagination
# to prevent GET calls to the console from timing out.
# All consecutive runs of the script will only load new events and append them
# to the result file.
# The script keeps track of events exported and only pulls in new alerts.
# To reset this script, simply delete the last.txt file in the same directory as 
# this script.
#
# Requires curl and jq to be in $PATH
# sudo apt install curl jq

# Configure the API authentication token and the domain hash of your console.
# (Grab it here: https://1234abcd.canary.tools/settings where "1234abcd" is your unique console's CNAME)
AUTH_TOKEN=deadbeef12345678
DOMAIN_HASH=1234abcd

# FILE_NAME=$(date "+%Y%m%d%H%M%S")-$DOMAIN_HASH-alerts.csv
FILE_NAME=alerts.csv

BASE_URL="https://$DOMAIN_HASH.canary.tools"
LIMIT=500 # The number of incidents to get per page
INCIDENTS_SINCE=0 # Default to get all incidents
LOADED_STATE=0 # Boolean variable to track if previous state was recovered

stop () {
    if [ $LOADED_STATE -ne 1 ]; then
        echo "Results saved in $FILE_NAME"
    else
        echo "Updated results in $FILE_NAME"
    fi
    exit 0
}

fail () {
    for arg in "$@"; do echo >&2 "$arg"; done
    exit 1
}

# To change what data is processed from the incidents update the create_csv_header and extract_incident_data functions
create_csv_header () {
    echo "Datetime,Alert Description,Target,Target Port,Attacker,Attacker RevDNS" > $FILE_NAME
}

extract_incident_data () {
    local content=$1
    data=$(jq -r '.incidents[] | [.description | .created_std, .description, .dst_host, .dst_port, .src_host, .src_host_reverse | tostring] | @csv' <<< "$content")
    if [ $? -ne 0 ]; then
        fail "jq was unable to parse html content data"
                "Content: $content"
    fi
    echo "$data"
}

# Check command prerequisites
if ! command -v curl &> /dev/null; then
    fail "I require curl but it's not installed.  Aborting."
fi
if ! command -v jq &> /dev/null; then
    fail "I require jq but it's not installed.  Aborting."
fi

# Ping the console to ensure reachability
response=$(curl $BASE_URL/api/v1/ping \
            -d auth_token=$AUTH_TOKEN \
            --get --silent \
            --write-out '%{http_code}')
if [ $? -ne 0 ]; then
    fail "curl encountered an error"
            "Response: $response"
fi
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ $http_code -ne 200 ]; then
    fail "Unable to ping the console" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

# Check if we have state from the last incidents fetch
if [ -f "last.txt" ]; then
    # We have state, so continue from last point and append to result file
    INCIDENTS_SINCE=`cat last.txt`
    LOADED_STATE=1
fi

if [ $LOADED_STATE -ne 1 ]; then
    echo "No state found, fetching all incidents from the console. (This may take a while)"
fi

echo "Fetching incidents from console"

# Get incidents
response=$(curl $BASE_URL/api/v1/incidents/all \
            -d auth_token=$AUTH_TOKEN \
            -d incidents_since=$INCIDENTS_SINCE \
            -d limit=$LIMIT \
            -d shrink=true \
            --get --silent \
            --write-out '%{http_code}')
if [ $? -ne 0 ]; then
    fail "curl encountered an error"
            "Response: $response"
fi
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ $http_code -ne 200 ]; then
    fail "Error occurred while fetching incident data from console" \
            "HTTP Code: $http_code"
            "Content: $content"
fi

max_updated_id=$(jq -r '.max_updated_id' <<< "$content")
if [ $? -ne 0 ]; then
    fail "jq was unable to read the max_updated_id from the html content"
            "Content: $content"
fi

if [ $max_updated_id == "null" ]; then
    fail "No new events found on the console"
else
    echo $max_updated_id > last.txt
fi

cursor=$(jq -r '.cursor | .next' <<< "$content")
if [ $? -ne 0 ]; then
    fail "jq was unable to read the cursor from the html content"
            "Content: $content"
fi

data=$(extract_incident_data "$content")
if [ "$data" != "" ]; then
    if [ $LOADED_STATE -ne 1 ]; then
        create_csv_header
    fi
    echo "$data" >> $FILE_NAME
fi

# There is no more data to read, we can stop
if [ $cursor == "null" ]; then
    stop
fi

# While we have a pagination cursor keep loading data
counter=1
while [ cursor ]
do
    echo "Fetching additional incidents from console $counter"
    ((counter=counter+1))

    response=$(curl $BASE_URL/api/v1/incidents/all \
                -d auth_token=$AUTH_TOKEN \
                -d cursor=$cursor \
                -d shrink=true \
                --get --silent \
                --write-out '%{http_code}')
    if [ $? -ne 0 ]; then
        fail "curl encountered an error"
                "Response: $response"
    fi
    http_code=$(tail -n1 <<< "$response")  # get the last line
    content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

    if [ $http_code -ne 200 ]; then
        fail "Error occurred while fetching incident data from console" \
                "HTTP Code: $http_code"
                "Content: $content"
    fi

    cursor=$(jq -r '.cursor | .next' <<< "$content")
    if [ $? -ne 0 ]; then
        fail "jq was unable to read the cursor from the html content"
                "Content: $content"
    fi

    data=$(extract_incident_data "$content")
    if [ "$data" != "" ]; then
        echo "$data" >> $FILE_NAME
    fi

    # There is no more data to read, we can stop
    if [ $cursor == "null" ]; then
        stop
    fi
done
