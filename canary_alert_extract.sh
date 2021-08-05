#!/bin/bash
# Creates a CSV an export of all alerts from your Canary Console.
# Requires curl and jq to be in the path. (https://stedolan.github.io/jq/)
# The API functionality will need to be enabled on your Console, a guide available here.(https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-)

export token=a1bc3e769fg832hij3 # Enter your API auth key. e.g a1bc3e769fg832hij3 Docs available here. https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
export console=1234abc.canary.tools # Enter your Console domain between the quotes. e.g. 1234abc.canary.tools
export dateformat=1990-01-01-00:00:00 # Enter starting date of Alerts to retrieve e.g. YYYY-MM-DD-HH:MM:SS

export filedate=`date "+%Y%m%d%H%M%S"`
export filename=$filedate-$console-alert-export.csv
export baseurl="https://$console/api/v1/incidents/all?auth_token=$token&shrink=true&newer_than"

echo Datetime,Alert Description,Target,Target Port,Attacker,Attacker RevDNS > $filename
curl "$baseurl=$dateformat" | jq -r '.incidents[] | [.description | .created_std, .description, .dst_host, .dst_port, .src_host, .src_host_reverse | tostring] | @csv' >> $filename