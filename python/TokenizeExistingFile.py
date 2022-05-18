import requests
import os
import socket
from requests_toolbelt.multipart.encoder import MultipartEncoder

Domain = "xxxxyyyy.canary.tools"  # Enter your Console domain between the . e.g. 1234abc.canary.tools
FactoryAuth = "a1bc3e769fg832hij3"  # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
FlockID = "flock:default"  # Enter desired flock ID to place tokens in. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors

def drop_msword_token():
    # Drop MSWord Token
    token_directory = os.path.expanduser('~') + '/Downloads/'  # Download location of token.
    token_filename = 'secrets.docx'  # Token filename, consider an enticing name to attract attackers.
    token_type = 'doc-msword'
    memo = socket.gethostname() + ' - ' + token_directory + token_filename

    # Create Token on Console
    create_token_url = 'https://' + Domain + '/api/v1/canarytoken/factory/create'

    m = MultipartEncoder(
        fields={'factory_auth': FactoryAuth, 'memo': memo, 'kind': token_type,
                'doc': (token_filename, open(token_directory + token_filename, 'rb'),
                        'application/vnd.openxmlformats-officedocument.wordprocessingml.document')}
    )

    create_token = requests.post(create_token_url, data=m, headers={'Content-Type': m.content_type})

    if create_token.status_code != requests.codes.ok:
        print('[!] Creation of ' + token_directory + token_filename + ' failed.')
        exit()
    else:
        result = create_token.json()

    canarytoken_id = result['canarytoken']['canarytoken']

    # Download token to endpoint.
    download_token_url = 'https://' + Domain + '/api/v1/canarytoken/factory/download'

    payload = {
        'factory_auth': FactoryAuth,
        'canarytoken': canarytoken_id
    }

    fetch_token = requests.get(download_token_url, allow_redirects=True, params=payload)

    if fetch_token.status_code != requests.codes.ok:
        print('[!] Fetching of ' + token_directory + token_filename + ' failed.')
        exit()
    else:
        result = create_token.json()

    if not os.path.exists(token_directory):
        os.makedirs(token_directory)

    open(token_directory + token_filename, 'wb').write(fetch_token.content)

    print("[*] MSWord Token Dropped")

drop_msword_token()