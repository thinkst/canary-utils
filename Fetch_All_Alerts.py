#Fetch_All_Alerts.py - Python script to query the Canary All Incidents API Endpoint documented here. https://docs.canary.tools/incidents/queries.html#all-incidents
#Domain hash and API Key - Documentation can be found here https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#Usage $ python3 Fetch_All_Alerts.py DOMAINHASH APIKEY OUTPUTFILE
#i.e. $ python3 Fetch_All_Alerts.py abc123 def456 'All_Alerts.json'

import requests
import sys

Domainhash = str(sys.argv[1])
APIKey = str(sys.argv[2])  
Outputfile = str(sys.argv[3])

url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/all'

payload = {
  'auth_token': (APIKey),
  'limit': 10
}

r = requests.get(url, params=payload)

open(Outputfile, 'wb').write(r.content)