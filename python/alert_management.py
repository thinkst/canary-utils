"""
alert_management.py
@author: <Javier Domínguez Gómez>

usage: alert_management.py [-h] [-d DOMAIN] [-f FLOCKID] [-a {true,false}] [-o OUTPUTFILE]

Tool to query the Canary All Incidents API Endpoint and mange the response.

options:
  -h, --help            show this help message and exit
  -d DOMAIN, --domain DOMAIN
                        Client domain to append as <your_domain>.canary.tools URL
  -f FLOCKID, --flockid FLOCKID
                        (Optional) Get all incidents for a specific flock_id
  -a {true,false}, --acknowledged {true,false}
                        (Optional) To filter acknowledged or unacknowledged incidents. Valid values are 'true', 'false'.
                        If you do not specify this flag you will receive all incidents.
  -o OUTPUTFILE, --outputfile OUTPUTFILE
                        (Optional) JSON file to dump the API query response

Canary All Incidents API Endpoint documented here: https://docs.canary.tools/incidents/queries.html#all-incidents
Domain hash and API Key documented here: https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
"""

import argparse
import json
import os
import requests

from typing import NoReturn

CANARY_API_AUTH_TOKEN = os.getenv('CANARY_API_AUTH_TOKEN')

def get_args() -> tuple:
    """ Function to parse program arguments """

    parser = argparse.ArgumentParser(
        description='Tool to query the Canary All Incidents API Endpoint and mange the response.'
    )

    parser.add_argument(
        '-d',
        '--domain',
        help="Client domain to append as <your_domain>.canary.tools URL.",
        type=str
    )

    parser.add_argument(
        '-f',
        '--flockid',
        help="(Optional) Get all incidents for a specific flock_id.",
        type=str
    )

    parser.add_argument(
        '-a',
        '--acknowledged',
        help="(Optional) To filter acknowledged or unacknowledged incidents. Valid values are 'true', 'false'. "
             "If you do not specify this flag you will receive all incidents.",
        type=str,
        choices=['true', 'false']
    )

    parser.add_argument(
        '-l',
        '--limit',
        help="(Optional) Parameter used to initiate cursor pagination. The limit is used to specify the page sizes "
             "returned when iterating through the pages representing all incidents.",
        type=int
    )

    parser.add_argument(
        '-o',
        '--outputfile',
        help="(Optional) JSON file to dump the API query response.",
        type=str
    )

    arguments = parser.parse_args()

    if not arguments.domain:
        parser.error("-d or --domain flag it's mandatory.")

    return arguments, parser

def write_to_json_file(data: dict, output_file: str) -> NoReturn:
    try:
        with open(output_file, 'w', encoding='utf-8') as file:
            json.dump(data, file, ensure_ascii=False)
    except Exception as err:
        print(err)


if __name__ == '__main__':
    args, _ = get_args()

    """
    Check mandatory enviroment variable CANARY_API_AUTH_TOKEN and return the value if exists, then exit with error.
    For security reasons, this API key that you'll need to use in order to make calls to API must not be provided as
    an argument when executing the program.
    """
    if CANARY_API_AUTH_TOKEN is None:
        print(f"Please set CANARY_API_AUTH_TOKEN enviroment variable")
        exit(1)

    if args.acknowledged == 'true':
        endpoint = 'acknowledged'
    elif args.acknowledged == 'false':
        endpoint = 'unacknowledged'
    else:
        endpoint = 'all'

    url = f'https://{args.domain}.canary.tools/api/v1/incidents/{endpoint}'

    payload = {'auth_token': CANARY_API_AUTH_TOKEN}

    if args.flockid:
        payload['flock_id'] = f'flock:{args.flockid}'

    if args.limit:
        payload['limit'] = args.limit

    try:
        response = requests.get(url, params=payload)
        if response.status_code == 200:
            response = response.json()
            incidents = response.get('incidents')

            if args.limit:
                next_cursor = response.get('cursor').get('next')

                while next_cursor:
                    del payload['limit']

                    payload['cursor'] = next_cursor
                    response = requests.get(url, params=payload)

                    if response.status_code == 200:
                        response = response.json()
                        next_cursor = response.get('cursor').get('next')
                        incidents += response.get('incidents')

            if args.outputfile:
                write_to_json_file(
                    data=incidents,
                    output_file=args.outputfile
                )
        else:
            print(f'Response status code: {response.status_code}')
    except Exception as err:
        print(err)
