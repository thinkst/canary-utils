#!/bin/bash

set -eu
set -o pipefail

# This script is intended to get basic alert information into a SIEM. Rather than
# pulling full alert information, this script pulls just enough data to correlate
# Canary and Canarytoken alerts with other events or to trigger the IR process.
#
# On first run the script will load all events from the console using pagination
# to prevent GET calls to the console from timing out.
# All consecutive runs of the script will only load new events and append them
# to the result file.
# The script keeps track of events exported and only pulls in new alerts.
# To reset this script, simply delete the ${domain_hash}_state_store.txt
# file saved alongside the results file ${domain_hash}_alerts.csv.
#
# Requires curl and jq to be in $PATH
# sudo apt install curl jq

# The only variable that need to be set is the AUTH_TOKEN and DOMAIN_HASH
# They can be set as environmental variables or the the file below by
# setting auth_token_default and domain_hash_default.
# To fine the API auth token and domain hash go to the settings page of your console
# (https://1234abcd.canary.tools/settings where "1234abcd" is your console's unique CNAME)
auth_token_default=deadbeef12345678
domain_hash_default=1234abcd

# Use the environmental variables if set otherwise use the default variables
auth_token=${AUTH_TOKEN:-$auth_token_default}
domain_hash=${DOMAIN_HASH:-$domain_hash_default}

results_file_name="${domain_hash}_alerts.csv"
state_store_file_name="${domain_hash}_state_store.txt"

base_url="https://$domain_hash.canary.tools"
page_size=1500 # The number of incidents to get per page
incidents_since=0 # Default to get all incidents
loaded_state=0 # Boolean variable to track if previous state was recovered
sort_on_column=1 # Set the column on which the csv should be sorted on update; First column index is 1

add_blank_notes_column=0 # Set to 1 to add a notes column to the csv that you can add notes too
add_additional_event_details=0 # Set to 1 to add additional event details to the csv

sort_results () {
    cp "$results_file_name" "$results_file_name.unsorted"
    head -n1 "$results_file_name.unsorted" > "$results_file_name" # Save the header in the file
    tail -n+2 "$results_file_name.unsorted" | sort -t ',' -k $sort_on_column,$sort_on_column -n >> "$results_file_name" # Sort the file
    rm -f "$results_file_name.unsorted"
}

stop () {
    sort_results
    echo '' # Newline to not override status feedback
    if [ $loaded_state -ne 1 ]; then
        echo "Results saved in $results_file_name"
    else
        echo "Updated results in $results_file_name"
    fi
    exit 0
}

fail () {
    echo '' # Newline to not override status feedback
    for arg in "$@"; do echo >&2 "$arg"; done
    exit 1
}

# To change what data is processed from the incidents update the create_csv_header and extract_incident_data functions
create_csv_header () {
    header=""

    if [ $add_blank_notes_column -eq 1 ]; then
        header+="Notes,"
        # Increment the column sorting index by one
        sort_on_column+=1
    fi

    header+="Updated ID"
    header+=",Date and Time"
    header+=",Alert Description"
    header+=",Target"
    header+=",Target Port"
    header+=",Attacker"
    header+=",Attacker RevDNS"

    if [ $add_additional_event_details -eq 1 ]; then
        header+=",Additional Events"
    fi

    echo "${header}" > "$results_file_name"
}

extract_incident_data () {
    local content=$1

    description_fields=".created_std"
    description_fields+=",.description"
    description_fields+=",.dst_host"
    description_fields+=",.dst_port"
    description_fields+=",.src_host"
    description_fields+=",.src_host_reverse"

    if [ $add_additional_event_details -eq 1 ]; then
        description_fields+=",(.events | tostring)"
    fi

    if ! data=$(jq -r ".incidents[] | [
        .updated_id,
        (.description | ${description_fields})
    ] | @csv" <<< "$content")
    then
        fail "jq was unable to parse html content data" \
                "Content: $content"
    fi

    if [ $add_blank_notes_column -eq 1 ]; then
        data=$(echo "$data" | sed 's/^/,/g') # Uncomment to add blank notes column, remember to update sort_on_column
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
if ! response=$(curl "$base_url"/api/v1/ping \
            -d auth_token="$auth_token" \
            --get --silent --show-error \
            --write-out '%{http_code}' 2>&1)
then
    fail "curl encountered an error" \
            "Response: $response"
fi
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Unable to ping the console" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

# Check if we have state from the last incidents fetch
if [ -f "$state_store_file_name" ]; then
    # We have state, so continue from last point and append to result file
    incidents_since=$(cat "$state_store_file_name")
    loaded_state=1
fi

if [ $loaded_state -ne 1 ]; then
    echo "No state found, fetching all incidents from the console. (This may take a while)"
fi

echo "Fetching incidents from console: $base_url"
echo -ne "Working: ."

# Get incidents
if ! response=$(curl "$base_url"/api/v1/incidents/all \
            -d auth_token="$auth_token" \
            -d incidents_since="$incidents_since" \
            -d limit=$page_size \
            -d shrink=true \
            --get --silent --show-error \
            --write-out '%{http_code}')
then
    fail "curl encountered an error" \
            "Response: $response"
fi
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Error occurred while fetching incident data from console" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

if ! max_updated_id=$(jq -r '.max_updated_id' <<< "$content")
then
    fail "jq was unable to read the max_updated_id from the html content" \
        "Content: $content"
fi

if [ "$max_updated_id" == "null" ]; then
    echo '' # Newline to not override status feedback
    echo "No new events found on the console"
    exit 0
else
    echo "$max_updated_id" > "$state_store_file_name"
fi

if ! cursor=$(jq -r '.cursor | .next' <<< "$content")
then
    fail "jq was unable to read the cursor from the html content" \
        "Content: $content"
fi

data=$(extract_incident_data "$content")
if [ "$data" != "" ]; then
    if [ $loaded_state -ne 1 ]; then
        create_csv_header
    fi
    echo "$data" >> "$results_file_name"
fi

# There is no more data to read, we can stop
if [ "$cursor" == "null" ]; then
    stop
fi

# While we have a pagination cursor keep loading data
while [ "$cursor" != "null" ]
do
    echo -ne "."

    if ! response=$(curl "$base_url"/api/v1/incidents/all \
                -d auth_token="$auth_token" \
                -d cursor="$cursor" \
                -d shrink=true \
                --get --silent --show-error \
                --write-out '%{http_code}')
    then
        fail "curl encountered an error" \
                "Response: $response"
    fi
    http_code=$(tail -n1 <<< "$response")  # get the last line
    content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

    if [ "$http_code" != "200" ]; then
        fail "Error occurred while fetching incident data from console" \
                "HTTP Code: $http_code" \
                "Content: $content"
    fi

    if ! cursor=$(jq -r '.cursor | .next' <<< "$content")
    then
        fail "jq was unable to read the cursor from the html content" \
            "Content: $content"
    fi

    data=$(extract_incident_data "$content")
    if [ "$data" != "" ]; then
        echo "$data" >> "$results_file_name"
    fi

    # There is no more data to read, we can stop
    if [ "$cursor" == "null" ]; then
        stop
    fi
done
