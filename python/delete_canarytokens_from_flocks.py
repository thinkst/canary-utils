import requests

# Console's domain abcdefhg.canary.tools
CANARYDOMAIN="abcd1234"
# Console's API Key abc123...
CANARYAPIKEY="aab1ccd234babacdcd1411abab"

# Flocks to delete Canarytokens from
given_flocks ={
    "flock:aab1ccd234babacdcd1411abab",
    "flock:aab1ccd234babacdcdxxyyxxzz"
}
# Fetch all Canarytokens from a Console
fetch_canarytokens_url = f'https://{CANARYDOMAIN}.canary.tools/api/v1/canarytokens/fetch'
fetch_canarytokens_payload = {
    'auth_token': CANARYAPIKEY
}
fetch_canarytokens = requests.get(fetch_canarytokens_url, params=fetch_canarytokens_payload)

# Delete Canarytokens from given Flocks
delete_canarytoken_url = f'https://{CANARYDOMAIN}.canary.tools/api/v1/canarytoken/delete'
data = fetch_canarytokens.json()
for i in data['tokens']:
    if (i["flock_id"] in given_flocks):
        CANARYTOKEN = str(i["canarytoken"])
        print("Selected Canarytoken: " + i["canarytoken"] + ":" + i["flock_id"])
        delete_canarytoken_payload = {
            'auth_token': CANARYAPIKEY,
            'canarytoken': CANARYTOKEN,
            'clear_incidents': 'true'
        }
        delete_canarytoken = requests.post(delete_canarytoken_url, data=delete_canarytoken_payload)
        if(delete_canarytoken.status_code == 200):
            print("Deleted Canarytoken: " + i["canarytoken"] + ":" + i["flock_id"])
        else:
            print(delete_canarytoken.text)