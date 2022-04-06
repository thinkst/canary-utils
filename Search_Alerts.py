#Search_through_Alerts.py - Python script to query the Canary Search Incidents API Endpoint documented here. https://docs.canary.tools/incidents/queries.html#search-incidents
#Domain hash and API Key - Documentation can be found here https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#Usage $ python3 Search_through_Alerts.py Domainhash APIKey Ouputfile 'searchterm'
#i.e. $ python3 Search_through_Alerts.py ABC123 DEF456 'Search_Results.json' 'x-forwarded-for'

import requests
import sys

Domainhash = str(sys.argv[1])
APIKey = str(sys.argv[2])
Outputfile = str(sys.argv[3])
Searchterm = (sys.argv[4])

url = 'https://'+(Domainhash)+'.canary.tools/api/v1/incidents/search'

payload = {
  'auth_token': (APIKey),
  'filter_str': (Searchterm),
  'limit': 1000
}

r = requests.get(url, params=payload)

open(Outputfile, 'wb').write(r.content)