import requests

Domain = "ABC123" # Enter your Console domain between the . e.g. 1234abc.canary.tools
ApiKey = "ABC123" # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string

# list all factory auth strings
list_url = 'https://'+Domain+'.canary.tools/api/v1/canarytoken/list_factories'
list_payload = {
  'auth_token': ApiKey
}
list_response = requests.get(list_url, params=list_payload)
list_json = list_response.json()
list_data = list_json['factories']
factory_auths = [factory['factory_auth'] for factory in list_data]

# delete all factory auth strings
delete_url = 'https://'+Domain+'.canary.tools/api/v1/canarytoken/delete_factory'
delete_payload = {
  'auth_token': ApiKey
}

for factory_auth in factory_auths:
    delete_payload['factory_auth'] = factory_auth
    delete_response = requests.delete(delete_url, data=delete_payload)
    print(f"Factory Auth {factory_auth} deleted. Response: {delete_response.json()}")

