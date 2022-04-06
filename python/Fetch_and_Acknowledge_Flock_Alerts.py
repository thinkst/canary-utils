#Fetch_All_Alerts.py - Python script to query the Canary All Incidents API Endpoint documented here. https://docs.canary.tools/incidents/queries.html#all-incidents
#Domain hash and API Key - Documentation can be found here https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#Usage $ python3 Fetch_All_Alerts.py DOMAINHASH APIKEY FLOCKID OUTPUTFILE
#i.e. $ python3 Fetch_All_Alerts.py abc123 def456 ghi789'All_Alerts.json'

import requests
import sys

Domainhash = str(sys.argv[1])
APIKey = str(sys.argv[2])
FlockID = str(sys.argv[3])
Outputfile = str(sys.argv[4])

fetch_url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/unacknowledged'

fetch_payload = {
  'auth_token': (APIKey),
  'flock_id': 'flock:'+(FlockID)
}

r = requests.get(fetch_url, params=fetch_payload)

result = r.content.decode('UTF-8')

open(Outputfile, 'a').write(result)

#Acknowedge Alerts
ack_url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/acknowledge'

ack_payload = {
  'auth_token': (APIKey),
  'flock_id': 'flock:'+(FlockID)
}

r = requests.post(ack_url, params=ack_payload)