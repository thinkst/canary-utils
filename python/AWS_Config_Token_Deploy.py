import requests
import socket
import os

Domain = "ABC123.canary.tools" # Enter your Console domain between the . e.g. 1234abc.canary.tools
FactoryAuth = "ABC123" # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
FlockID = "flock:default" # Enter desired flock ID to place tokens in. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors

def drop_awsid_token():
  #Drop aws-id Token 
  token_directory = os.path.expanduser('~')+'/.aws/' # Download location of token.
  token_filename = 'config' # Token filename, consider an enticing name to attract attackers.
  token_type = 'aws-id'
  
  #Create Token on Console
  create_token_url = 'https://'+Domain+'/api/v1/canarytoken/factory/create'
  
  payload = {
  'factory_auth': FactoryAuth,
  'kind': token_type,
  'flock_id' : FlockID,
  'memo': socket.gethostname()+' - '+token_directory+token_filename,
  }
  
  create_token = requests.post(create_token_url, data=payload)
  
  if create_token.status_code != requests.codes.ok:
    print('[!] Creation of '+token_directory+token_filename+' failed.')
    exit()
  else:
    result = create_token.json()
  
  canarytoken_id = result['canarytoken']['canarytoken']
  
  #Download token to endpoint.
  download_token_url = 'https://'+Domain+'/api/v1/canarytoken/factory/download'
  
  payload = {
  'factory_auth': FactoryAuth,
  'canarytoken': canarytoken_id
  }
  
  fetch_token = requests.get(download_token_url, allow_redirects=True, params=payload)
  
  if fetch_token.status_code != requests.codes.ok:
    print('[!] Fetching of '+token_directory+token_filename+' failed.')
    exit()
  else:
    result = create_token.json()

  if not os.path.exists(token_directory):
    os.makedirs(token_directory)
  
  if os.path.exists(token_directory+token_filename):
    open(token_directory+token_filename, 'a').write("\n")
    open(token_directory+token_filename, 'ab').write(fetch_token.content)
  else:
    open(token_directory+token_filename, 'wb').write(fetch_token.content)

  print("[*] AWS-API Key Token Dropped")

drop_awsid_token()