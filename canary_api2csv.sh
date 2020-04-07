#!/bin/bash
#
# Intended to get basic alert information into a SIEM. Rather than pulling full
# alert information, this script pulls just enough data to correlate Canary and
# Canarytoken alerts with other events or to trigger the IR process.
#
# Initially, this script will pull the last week's worth of information. The
# script keeps track of events exported and only pulls in new alerts. To
# reset this script, simply delete the last.txt file in the same directory as 
# this script.

# TODO: do a console ping that shows usage if ping fails
# implement error checking for curl/jq commands
# don't output a file if no data

# Requires curl and jq to be in the path
# sudo apt install curl jq

# Set this variable to your API token (grab it here: https://1234abcd.canary.tools/settings where "1234abcd" is your unique console's CNAME)
export token=deadbeef12345678

# Customize this variable to match your console URL
export console=1234abcd.canary.tools

# Do a console ping - if it fails, print usage (not yet implemented)

# Date format (one week ago)
export weekago=`date --date="1 week ago" "+%Y-%m-%d-%H:%M:%S"`

# Date format (current date)
export currdate=`date "+%Y-%m-%d-%H:%M:%S"`

# Filename date (current date, diff format that's file friendly)
export filedate=`date "+%Y%m%d%H%M%S"`

# Complete Filename
export filename=$filedate-$console-alerts.csv

# Base URL
export baseurl="https://$console/api/v1/incidents/all?auth_token=$token&shrink=true&newer_than"

# Run the jewels
echo Datetime,Alert Description,Target,Target Port,Attacker,Attacker RevDNS > $filename
# Check for previous runs
if [ -f "last.txt" ]; then
	export lastdate=`cat last.txt`
	echo Last run was on $lastdate, grabbing everything since then.
	curl -s "$baseurl=$lastdate" | jq -r '.incidents[] | [.description | .created_std, .description, .dst_host, .dst_port, .src_host, .src_host_reverse | tostring] | @csv' >> $filename
	echo $currdate > last.txt
	echo Results saved in $filename.
else
	# If no previous runs, do first run
	echo First run, grabbing the last week of alerts.
	curl -s "$baseurl=$weekago" | jq -r '.incidents[] | [.description | .created_std, .description, .dst_host, .dst_port, .src_host, .src_host_reverse | tostring] | @csv' >> $filename
	echo $currdate > last.txt
	echo Results saved in $filename
fi
