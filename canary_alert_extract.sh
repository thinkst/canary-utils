#!/bin/bash
# Create a CSV with the last week's worth of alerts from your Canary console
# Requires curl and jq to be in the path

# Set this variable to your API token
export token=deadbeef12345678

# Customize this variable to match your console URL
export console=ab123456.canary.tools

# Date format (one week ago)
export dateformat=`date -v-1w "+%Y-%m-%d-%H:%M:%S"`

# Filename date (right now)
export filedate=`date "+%Y%m%d%H%M%S"`

# Complete Filename
export filename=$filedate-$console-1week-alert-export.csv

# Base URL
export baseurl="https://$console/api/v1/incidents/all?auth_token=$token&shrink=true&newer_than"

# Run the jewels
echo Datetime,Alert Description,Target,Target Port,Attacker,Attacker RevDNS > $filename
curl "$baseurl=$dateformat" | jq -r '.incidents[] | [.description | .created_std, .description, .dst_host, .dst_port, .src_host, .src_host_reverse | tostring] | @csv' >> $filename
