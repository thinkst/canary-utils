#Alert_Deleter.py - Python script to acknowledge alerts, save acknowledged alerts locally then delete old acknowledged alerts.
#Domain hash and API Key - Documentation can be found here https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#Usage $ python3 Alert_Deleter.py DOMAINHASH APIKEY OUTPUTFILE
#i.e. $ python3 Alert_Delete.py abc123 def456 'Canary_Alerts.json'

import requests
import sys
from datetime import datetime

Domainhash = str(sys.argv[1])
APIKey = str(sys.argv[2])
Outputfile = str(sys.argv[3])

#Acknowledge Alerts
ack_url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/acknowledge'

ack_payload = {
  'auth_token': (APIKey)
}

ack_alerts_request = requests.post(ack_url, params=ack_payload)

#Fetch Acknowledged Alerts

fetch_url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/acknowledged'

fetch_payload = {
  'auth_token': (APIKey)
}

fetch_alerts_request = requests.get(fetch_url, params=fetch_payload)

open(Outputfile, 'a').write('\n'+fetch_alerts_request.content.decode('UTF-8'))
open(Outputfile, 'a').write('\nAlert_Delete.py Script complete at: '+str(datetime.utcnow())+' UTC\n')

#Delete Acknowledged Alerts
del_url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/delete'

del_payload = {
  'auth_token': (APIKey),
  'older_than': '1h',
  'include_unacknowledged': 'False'
}

del_alerts_request = requests.delete(del_url, params=del_payload)