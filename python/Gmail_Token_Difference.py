#!/usr/bin/env python3
# Canary Gmail Tokener

import sys
import csv
import re
import requests

# Variables

DOMAIN = 'ABC123' # Enter your Console domain hash e.g abc123.canary.tools
APIKEY = 'DEF456' # Enter your Console API Key
WORKSPACEDOMAIN = 'mydomain.com' # Enter your Google workspace domain name.
WORKSPACEADMIN = 'administrator@mydomain.com' # Enter your Google workspace admin email address.
FLOCK = 'flock:default' # Enter the flock your existing Tokens exist in.

print('[*] Starting Script...')

# Fetch google workspace users
def func_fetch_workspace_users(page_token=None):

    fetch_workspace_users_url = 'https://'+DOMAIN+'.canary.tools/api/v1/canarytoken/gmail/users/list'

    fetch_workspace_users_payload = {
        'auth_token': APIKEY,
        'domain': WORKSPACEDOMAIN,
        'email': WORKSPACEADMIN,
        'flock_id': FLOCK,
        'page_token': page_token
    }

    fetch_workspace_users = requests.post(fetch_workspace_users_url, data=fetch_workspace_users_payload, timeout=60)

    workspace_users_results = fetch_workspace_users.json()

    if 'users' not in workspace_users_results:
        print('Retrieval of users failed, is the Token configured in your workspace? https://help.canary.tools/hc/en-gb/articles/360019746837-How-to-Set-Up-a-Gmail-Canarytoken')
        sys.exit(1)

    user_emails = []
    for user in workspace_users_results['users']:
        user_emails.append(user['email'])

    page_token = workspace_users_results.get('next_page_token', None)

    return user_emails, page_token

list_workspace_users = []
next_page_token = None

print('[*] Fetching list of users from Google Workspace...')

list_workspace_users, next_page_token = func_fetch_workspace_users()

while next_page_token != None:
    user_emails, next_page_token = func_fetch_workspace_users(page_token=next_page_token)
    list_workspace_users.extend(user_emails)

list_workspace_users.sort()

print('[!] '+str(len(list_workspace_users))+' users retrieved from Google Workspace...')

##############################################################################################################################

# Backup function to grab data from a CSV, specify your export file as WORKSPACE_CSV https://support.google.com/a/answer/7348070?hl=en

def func_fetch_workspace_users_from_file():

    WORKSPACE_CSV = 'PATH_TO_FILE'
    workspace_export_file = open(WORKSPACE_CSV, mode='r', encoding="utf-8")

    workspace_export = csv.DictReader(workspace_export_file)

    list_columns = []

    for row in workspace_export:
        list_columns.append(row[0])

    print(list_columns)

    list_csv_users = []

    for col in workspace_export:
        list_csv_users.append(col['Email Address [Required]'])

    list_csv_users.sort()

    print('CSV Imported successfully')

#func_fetch_workspace_users

##############################################################################################################################

# function to fetch tokens
def func_request_tokens(cursor=None):

    fetch_gmail_tokens_url = 'https://'+DOMAIN+'.canary.tools/api/v1/canarytokens/search'

    fetch_gmail_tokens_payload = {
    'auth_token': APIKEY,
    'kind': 'gmail',
    'active': 'True',
    'limit': 100,
    'cursor': cursor
    }

    fetch_gmail_tokens = requests.get(fetch_gmail_tokens_url, params=fetch_gmail_tokens_payload, timeout=60)

    gmail_tokens_results = fetch_gmail_tokens.json()

    if 'canarytokens' not in gmail_tokens_results:
        print('Retrieval of existing Tokens failed, is the Token configured in your workspace? https://help.canary.tools/hc/en-gb/articles/360019746837-How-to-Set-Up-a-Gmail-Canarytoken')
        sys.exit(1)

    list_memos = []
    for token in gmail_tokens_results['canarytokens']:
        list_memos.append(token.get('memo', ''))

    cursor = gmail_tokens_results.get('cursor', None).get('next')

    return list_memos, cursor


list_current_tokens = []
next_cursor = None

print('[*] Fetching existing Tokens...')

list_current_tokens, next_cursor = func_request_tokens()

while next_cursor != None:
    list_memos, next_cursor = func_request_tokens(cursor=next_cursor)
    list_current_tokens.extend(list_memos)

list_current_tokens.sort()

print('[!] '+str(len(list_current_tokens))+' existing Tokens retrieved from Canary Console...')

# filter email addresses from memo's

def get_email(memo=None):
    if not memo:
        return None

    #Ripped from https://www.regular-expressions.info/email.html
    regex = re.compile(r"([a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)")
    match = regex.search(memo.lower())

    if not match:
        return None

    return match.group(1)

list_current_tokened_mailboxes = []

print('[*] Extracting Tokened mailboxes from Tokens...')

for memo in list_current_tokens:
    email = get_email(memo)
    if email is not None:
        list_current_tokened_mailboxes.append(email)

list_current_tokened_mailboxes.sort()

################################################################################################################################

# Compare lists and present to user

untokened_emails = []

untokened_emails.extend(set(list_workspace_users).difference(set(list_current_tokened_mailboxes)))

untokened_emails.sort()

print('[!] Script complete, users to be Tokened are below. Copy and paste this snippet into your Gmail Token wizard: https://help.canary.tools/hc/en-gb/articles/360019746837#h_01GCH6J0XXJ9V9TPPZGP870V6T'+'\n')

print(*untokened_emails, sep=', ')
