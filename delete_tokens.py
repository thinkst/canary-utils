# Delete Tokens
# delete_tokens.py
# Authors: Jay wrote most of this and Adrian updated to Python3
#
# Be VERY careful with this script! It is designed to wipe out all tokens 
# after some heavy automated API testing. Don't use it if you have any
# production tokens that you've worked hard to create and deploy - you'll
# lose them and will have to redeploy!
#

import requests
import sys
import re

def main(args):
    if len(args) < 2:
        print("usage: python delete_tokens.py <console_url> <api_key>")
    auth = args[1]
    console = args[0]
    get_url = "{base}/api/v1/canarytokens/fetch?auth_token={auth}".format(
        base=console, auth=auth)
    resp = requests.get(get_url)
    resp_obj =  resp.json()
    print("Current tokens on your console")
    print("-----------------------------------------------------------------------------------")
    print("kind\t\ttoken\t\t\t\t\tmemo")
    print("-----------------------------------------------------------------------------------")
    for token in resp_obj['tokens']:
        print("{}\t\t{}\t\t{}".format(token['kind'], token['canarytoken'], token['memo']))
    print("-----------------------------------------------------------------------------------")
    canarytoken = input("Are you sure you would like to delete all your Canarytokens? [Y\\n] PLEASE NOTE: This is irreversible!  ")
    if canarytoken != 'Y':
        print("Not deleting any canarytokens from your Canary console.")
        exit(0)
    delete_url = "{base}/api/v1/canarytoken/delete".format(base=console)
    for token in resp_obj['tokens']:
        print("Deleting {}: {}".format(token['canarytoken'], token['kind']))
        data = {
            'auth_token': auth,
            'canarytoken': token['canarytoken']
        }
        resp = requests.post(delete_url, data=data)
    print("-----------------------------------------------------------------------------------")
    print("All deleted. Go create some more! They're on us ;)")

if __name__ == "__main__":
    main(sys.argv[1:])
