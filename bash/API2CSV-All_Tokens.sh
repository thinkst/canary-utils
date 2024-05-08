#!/bin/bash
# Call script with :
# user@host $ sh mass_fetch_tokens.sh abc123 5a3...2xf
# requires JQ to be installed :
# user@host $ sudo apt-get install jq
# https://stedolan.github.io/jq/

CANARYDOMAIN=$1
CANARYAPIKEY=$2

PAGELIMIT=50
VARCURSOR=none
i=1

# Check if the required parameters are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <CANARYDOMAIN> <CANARYAPIKEY>"
    exit 1
fi

# Initial run to fetch page cursor.

echo '\n [*] Fetching all Tokens in batches of '$PAGELIMIT'...'

# Add column headers to the CSV file.
echo '"Flock ID","Token Node ID","Creation Date","Enabled","Type", "Memo"' > token_results.csv

curl -s https://$CANARYDOMAIN.canary.tools/api/v1/canarytokens/paginate -d auth_token=$CANARYAPIKEY -d limit=$PAGELIMIT -G > temp.txt ; VARCURSOR=$(jq -r '.cursor.next' temp.txt) ; jq -r '.canarytokens[] | [.flock_id, .canarytoken, .created_printable, .enabled, .kind, .memo | tostring] | @csv' temp.txt >> token_results.csv

# Only print cursor if it's not "null"
if [[ $VARCURSOR != "null" ]]; then
    echo '\n [*] Page cursor '$i' is :' $VARCURSOR
fi

# Loop to iterate through pages.

while [[ $VARCURSOR != "null" ]]
do
  ((i++))
  curl -s https://$CANARYDOMAIN.canary.tools/api/v1/canarytokens/paginate -d auth_token=$CANARYAPIKEY -d cursor=$VARCURSOR -G > temp.txt ; VARCURSOR=$(jq -r '.cursor.next' temp.txt) ; jq -r '.canarytokens[] | [.flock_id, .canarytoken, .created_printable, .enabled, .kind, .memo | tostring] | @csv' temp.txt >> token_results.csv
  if [[ $VARCURSOR != "null" ]]; then
      echo '\n [*] Page cursor '$i' is :' $VARCURSOR
  fi
done

echo '\n [*] Job Complete!'
echo '\n [*] Total Pages of Tokens fetched:' $i

RESULTCOUNT=$(wc -l < token_results.csv)

echo '\n [*] Number of Tokens found :' $RESULTCOUNT

echo '\n [*] Results written to token_results.csv \n'
