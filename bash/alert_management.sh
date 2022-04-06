#!/bin/bash

#Constants
DOMAIN=""
AUTH_KEY=""
SAVE=true
DELETE=true
FILEDATE=`date "+%Y%m%d%H%M%S"`

FILENAME=$FILEDATE-$DOMAIN-export.json
echo -e "\nThinkst Canary Alert Management"

usage()
{
  echo -e "\nBy default, this script will save, acknowledge and then delete your alerts"
  echo "Results are saved to the current working directory in JSON"
  echo -e "\t-d Domain of your Canary Console"
  echo -e "\t-a Auth Token for the Canary API"
  echo -e "\t-s Don't save the incidents (just acknowledge and delete)"
  echo -e "\t-r Don't remove the incidents (just acknowledge)"

  exit -1
}

while getopts "hd:a:rs" opt; do
  case $opt in
  h)
    usage
    ;;
  d)
    DOMAIN="${OPTARG}"
    ;;
  a)
    AUTH_KEY="${OPTARG}"
    ;;
  r)
    DELETE=false
    ;;
  s)
    SAVE=false
    ;;
  \?)
    echo -e "\nInvalid Option: -${OPTARG}" 1>&2
    usage
    exit -1
    ;;
  esac
done
shift $((OPTIND-1))

ping_console() {
  ping=$(curl -s "https://${DOMAIN}.canary.tools/api/v1/ping?auth_token=${AUTH_KEY}" | jq -r ".result")
  if [ ${ping} != "success" ]; then
    echo -e "\nConnection to the Console unsuccessful"
    exit -1
  fi
  echo -e "\nConnection to the Console successful"
}

save_incidents(){
  echo -e "\nSaving the incidents"
  curl -s -X GET "https://${DOMAIN}.canary.tools/api/v1/incidents/unacknowledged?auth_token=${AUTH_KEY}" | jq '.incidents | .[]' >> ${FILENAME}
  echo "Incidents saved to ${PWD}/${FILENAME}"
}

acknowledge_incidents() {
  echo -e "\nThe following incidents have been acknowledged:"
  curl -s -X POST "https://${DOMAIN}.canary.tools/api/v1/incidents/acknowledge?auth_token=${AUTH_KEY}" | jq '.keys[]'
}

delete_incidents() {
  echo -e "\nThe following incidents have been deleted:"
  curl -s -X POST  "https://${DOMAIN}.canary.tools/api/v1/incidents/delete?auth_token=${AUTH_KEY}" | jq '.keys[]'
}
ping_console

if [ ${SAVE} == true ]; then
  save_incidents
fi

acknowledge_incidents

if [ ${DELETE} == true ]; then
delete_incidents
fi
