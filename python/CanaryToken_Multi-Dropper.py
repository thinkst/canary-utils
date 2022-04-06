import requests
import socket
import os
import zipfile

Domain = "XXXXXX.canary.tools" # Enter your Console domain between the . e.g. 1234abc.canary.tools
FactoryAuth = "XXXXX" # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
FlockID = "flock:default" # Enter desired flock ID to place tokens in. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors

def drop_msword_token():
  #Drop MSWord Token 
  token_directory = os.path.expanduser('~')+'/mswordtoken/' # Download location of token.
  token_filename = 'secrets.docx' # Token filename, consider an enticing name to attract attackers.
  token_type = 'doc-msword'
  
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
  
  print("[*] MSWord Token Dropped")

drop_msword_token()

def drop_awsid_token():
  #Drop aws-id Token 
  token_directory = os.path.expanduser('~')+'/awsidtoken/' # Download location of token.
  token_filename = 'aws-api-key.txt' # Token filename, consider an enticing name to attract attackers.
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
  
  print("[*] AWS-API Key Token Dropped")

drop_awsid_token()

def drop_mswordmacro_token():
  #Drop msword-macro Token 
  token_directory = os.path.expanduser('~')+'/mswordmacrotoken/' # Download location of token.
  token_filename = 'credentials.docm' # Token filename, consider an enticing name to attract attackers.
  token_type = 'msword-macro'
  
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
  
  print("[*] MSWord-Macro Token Dropped")

drop_mswordmacro_token()

def drop_msexcelmacro_token():
  #Drop msexcel-macro Token 
  token_directory = os.path.expanduser('~')+'/msexcelmacrotoken/' # Download location of token.
  token_filename = 'credentials.xlsm' # Token filename, consider an enticing name to attract attackers.
  token_type = 'msexcel-macro'
  
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
  
  print("[*] MSExcel-Macro Token Dropped")

drop_msexcelmacro_token()

def drop_adobepdf_token():
  #Drop Adobe PDF Token 
  token_directory = os.path.expanduser('~')+'/adobepdftoken/' # Download location of token.
  token_filename = 'mysecrets.pdf' # Token filename, consider an enticing name to attract attackers.
  token_type = 'pdf-acrobat-reader'
  
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
  
  print("[*] Adobe PDF Token Dropped")

drop_adobepdf_token()

def drop_slackapi_token():
  #Drop Slack API Token 
  token_directory = os.path.expanduser('~')+'/slackapitoken/' # Download location of token.
  token_filename = 'slack_api_creds.txt' # Token filename, consider an enticing name to attract attackers.
  token_type = 'slack-api'
  
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
  
  print("[*] Slack API Token Dropped")

drop_slackapi_token()

def drop_qr_code_token():
  #Drop QR-Code Token 
  token_directory = os.path.expanduser('~')+'/qrcodetoken/' # Download location of token.
  token_filename = 'WiFi_Password_QRCode.png' # Token filename, consider an enticing name to attract attackers.
  token_type = 'qr-code'
  
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
  
  print("[*] QR Code Token Dropped")

drop_qr_code_token()

def drop_windows_folder_token():
  #Drop Windows Folder Token 
  token_directory = os.path.expanduser('~')+'/windows_folder_token/' # Download location of token.
  token_filename = 'token-folder.zip' # Token filename, consider an enticing name to attract attackers.
  token_type = 'windows-dir'
  
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
  
  open(token_directory+token_filename, 'wb').write(fetch_token.content)
    
  with zipfile.ZipFile(token_directory+token_filename, 'r') as zip_ref:
    zip_ref.extractall(token_directory)
  
  os.remove(token_directory+token_filename)
    
  print("[*] Windows Folder Token Dropped")

drop_windows_folder_token()