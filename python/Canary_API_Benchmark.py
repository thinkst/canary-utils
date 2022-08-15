import requests
import json
import datetime

DOMAIN = 'ABC123'
APIKEY = 'ABC123'

def func_pingconsole():

    start = datetime.datetime.now()

    print("Benchmarking time to ping Console...")

    url = 'https://'+DOMAIN+'.canary.tools/api/v1/ping'

    payload = {
    'auth_token': APIKEY
    }

    r = requests.get(url, params=payload).json()

    end = datetime.datetime.now()
    diff = end - start

    print("Ping Console complete, time taken: "+str(start)+" - "+str(end))
    print("Time Taken: "+str(diff)+"\n")

    with open('Ping_Console_Result.txt', 'w') as export:
        json.dump(r, export)

def func_fetchdevices():

    url = 'https://'+DOMAIN+'.canary.tools/api/v1/devices/all'

    start = datetime.datetime.now()

    print("Benchmarking time to fetch all device details...")
    
    payload = {
    'auth_token': APIKEY
    }

    r = requests.get(url, params=payload).json()
    
    end = datetime.datetime.now()
    diff = end - start

    print("Fetch Devices complete, time taken: "+str(start)+" - "+str(end))
    print("Time Taken: "+str(diff)+"\n")
    
    with open('Fetch_Devices_Result.txt', 'w') as export:
        json.dump(r, export)

def func_fetchtokens():

    url = 'https://'+DOMAIN+'.canary.tools/api/v1/canarytokens/fetch'

    start = datetime.datetime.now()

    print("Benchmarking time to fetch all Tokens...")

    payload = {
    'auth_token': APIKEY
    }

    r = requests.get(url, params=payload).json()

    end = datetime.datetime.now()

    diff = end - start

    print("Fetch Tokens complete, time taken: "+str(start)+" - "+str(end))
    print("Time Taken: "+str(diff)+"\n")

    with open('Fetch_Tokens_Result.txt', 'w') as export:
        json.dump(r, export)

def func_fetchincidents():

    url = 'https://'+DOMAIN+'.canary.tools/api/v1/incidents/all'

    start = datetime.datetime.now()

    print("Benchmarking time to fetch all Incident data...")

    payload = {
    'auth_token': APIKEY
    }

    r = requests.get(url, params=payload).json()

    end = datetime.datetime.now()

    diff = end - start

    print("Fetch Incidents complete, time taken: "+str(start)+" - "+str(end))
    print("Time Taken: "+str(diff)+"\n")

    with open('Fetch_Incidents_Result.txt', 'w') as export:
        json.dump(r, export)

def func_fetchaudit():

    url = 'https://'+DOMAIN+'.canary.tools/api/v1/audit_trail/fetch'

    start = datetime.datetime.now()

    print("Benchmarking time to fetch all audit data...")

    payload = {
    'auth_token': APIKEY
    }

    r = requests.get(url, params=payload).json()

    end = datetime.datetime.now()

    diff = end - start

    print("Fetch Audit complete, time taken: "+str(start)+" - "+str(end))
    print("Time Taken: "+str(diff)+"\n")

    with open('Fetch_Audit_Result.txt', 'w') as export:
        json.dump(r, export)

def func_fetchexample():

    url = 'https://example.com'

    start = datetime.datetime.now()

    print("Benchmarking time to fetch example.com...")

    r = requests.get(url)

    end = datetime.datetime.now()
    
    diff = end - start

    print("Fetch Example.com complete, time taken: "+str(start)+" - "+str(end))
    print("Time Taken: "+str(diff)+"\n")

func_pingconsole()
func_fetchdevices()
func_fetchtokens()
func_fetchincidents()
func_fetchaudit()
func_fetchexample()