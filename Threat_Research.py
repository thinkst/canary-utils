#Threat_Research.py - Python script to query the Canary All Incidents API Endpoint documented here. https://docs.canary.tools/incidents/queries.html#all-incidents
#Domain hash and API Key - Documentation can be found here https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#Usage $ python3 Threat_Research.py DOMAINHASH APIKEY FLOCKID OUTPUTFILE SEARCH_QUERY SEARCH_OUTPUT_FILE
#i.e. $ python3 Threat_Research.py abc123 def456 ghi789 'All_Alerts.json' 'src_host' 'extracted_data.txt'

import requests
import sys
import re

Domainhash = str(sys.argv[1])
APIKey = str(sys.argv[2])
FlockID = str(sys.argv[3])
Outputfile = str(sys.argv[4])
Searchpattern = str(sys.argv[5])
Searchoutputfile = str(sys.argv[6])

fetch_url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/unacknowledged'

fetch_payload = {
  'auth_token': (APIKey),
  'flock_id': 'flock:'+(FlockID)
}

r = requests.get(fetch_url, params=fetch_payload)

result = r.content.decode('UTF-8')

open(Outputfile, 'a').write(result)

#Acknowledge Alerts
ack_url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/acknowledge'

ack_payload = {
  'auth_token': (APIKey),
  'flock_id': 'flock:'+(FlockID)
}

r = requests.post(ack_url, params=ack_payload)

#Extract contents from file
open(Searchoutputfile, 'w').write("")

with open(Outputfile, 'r') as file_allalerts:
    for line in file_allalerts:
      if re.search("\""+Searchpattern+"\"", line):
          remove_spaces = line.replace(' ', '')
          remove_apostrophe = remove_spaces.replace("\"",'')
          cleaned = re.sub(':',',', remove_apostrophe)
          open(Searchoutputfile, 'a').write(cleaned)