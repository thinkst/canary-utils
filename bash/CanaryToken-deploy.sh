#!/bin/bash

#.SYNOPSIS
#    Creates Canarytokens and drops them to local host.
#    Uses Canarytoken Deploy keys, so it can be safely used for mass deployment.
#
#.NOTES
#    For this tool to work, you must have your Canary Console API enabled, please 
#    follow this link to learn how to do so:
#    https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#
#    ###################
#    How does this work?
#    ###################
#    Requires curl to be present.
#    1. Create the Flock you want the Tokens to be part of in your Console.
#    2. Create a Canarytoken Deploy Key (https://help.canary.tools/hc/en-gb/articles/7111549805213-Flock-API-Keys)
#    3. Make sure the host has access to the internet.
#    4. Run script as a user that has read/write access on the target directory.
#
#.EXAMPLE
#    sh .\CanaryToken-deploy.sh
#    This will run the tool asking interactively for missing params.
#    Flags 
#    -d Domain e.g aabbccdd.canary.tools
#    -a APIKey "abc123"
#    -o Output Directory e.g "~/secret"
#    -t Token Type e.g aws-id
#    -n Token Filename e.g aws_secret.txt Note: Use an appropriate extension for your token type.
#
#    sh .\CanaryToken-deploy.sh -d aabbccdd.canary.tools -a XXYYZZ -o "~/secret" -t aws-id -n aws_secret.txt
#    creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and places it under ~/secret

#   Supported tokens are: "aws-id"                : "AWS API Key",
#                         "credit-card"           : "Credit Card",
#                         "doc-msword"            : "MS Word Document",
#                         "msexcel-macro"         : "MS Excel Macro Document",
#                         "msword-macro"          : "MS Word Macro Document",
#                         "mysql-dump"            : "MySQL Dump",
#                         "pdf-acrobat-reader"    : "Acrobat PDF",
#                         "qr-code"               : "QR Code",
#                         "slack-api"             : "Slack API Key",
#                         "windows-dir"           : "Windows Folder",
#                         "wireguard"             : "Wireguard Config",


#VARIABLES
DOMAIN=""
APIKEY=""
TARGETDIRECTORY=""
TOKENTYPE=""
TOKENFILENAME=""

#Set script flags
while getopts d:a:o:t:n: flag
do
    case "${flag}" in
        d) DOMAIN=${OPTARG};;
        a) APIKEY=${OPTARG};;
        o) TARGETDIRECTORY=${OPTARG};;
        t) TOKENTYPE=${OPTARG};;
        n) TOKENFILENAME=${OPTARG};;
    esac
done

#Collect unset variables from user.
if [ -z "$TOKENTYPE" ]
then
echo '\nEnter your desired token type\n> aws-id | azure-id | credit-card | doc-msword | doc-msexcel | msexcel-macro | msword-macro | mysql-dump | pdf-acrobat-reader | qr-code | slack-api | windows-dir | wireguard'
read TOKENTYPE
fi

#Don't continue unless $TOKENTYPE is supported
case "$TOKENTYPE" in
    "aws-id"|"azure-id"|"credit-card"|"doc-msword"|"doc-msexcel"|"msexcel-macro"|"msword-macro"|"mysql-dump"|"pdf-acrobat-reader"|"qr-code"|"slack-api"|"windows-dir"|"wireguard")
        echo '\n[*] Token type is downloadable, proceeding'
        ;;
    *)
        echo "\n[X] Token type '$TOKENTYPE' cannot be downloaded."
        exit 1
        ;;
esac

if [ -z "$DOMAIN" ]
then
echo '\nEnter your Full Canary domain (e.g. 'xyz.canary.tools')'
read DOMAIN
fi

if [ -z "$APIKEY" ]
then
echo '\nEnter your Canarytoken API Key'
read APIKEY
fi

if [ -z "$TARGETDIRECTORY" ]
then
echo '\nEnter your target directory. Leave blank for ~/backup'
read TARGETDIRECTORY
fi
if [ -z "$TARGETDIRECTORY" ]
then
TARGETDIRECTORY="$HOME/backup"
fi

if [ -z "$TOKENFILENAME" ]
then
echo '\nEnter your desired file name'
read TOKENFILENAME
fi

#Print current variables
echo "\n[*] Starting Script with the following params:"
echo "\nConsole Domain = $DOMAIN"
echo "\nAPI Key = $APIKEY"
echo "\nTarget Directory = $TARGETDIRECTORY"
echo "\nToken Type = $TOKENTYPE"
echo "\nToken Filename = $TOKENFILENAME" 

#Checking target directory existence
echo "\n[*] Checking if '$TARGETDIRECTORY' exists..."

if [ -d "$TARGETDIRECTORY" ]; then
echo "\nDirectory exists" ;
else
`mkdir -p $TARGETDIRECTORY`;
echo "\n$TARGETDIRECTORY was not found. directory has been created"
fi

#Check whether token already exists
OUTPUTFILENAME="$TARGETDIRECTORY/$TOKENFILENAME"

echo "\n[*] Dropping '$OUTPUTFILENAME'..."

if [ -f "$OUTPUTFILENAME" ]; 
then
echo "\nFile already exists." ;
fi

#Create token
MACHINEHOSTNAME=$(hostname)

echo "\n[*] Requesting a Token from the Canary Console API..." ;

GETTOKEN=$(curl -s -X POST "https://${DOMAIN}/api/v1/canarytoken/create" \
  -d auth_token="$APIKEY" \
  -d memo="'$MACHINEHOSTNAME - $TARGETDIRECTORY/$TOKENFILENAME'" \
  -d kind="$TOKENTYPE")

[[ $GETTOKEN =~ \"result\":[[:space:]]*\"([^\"]+)\" ]]      && TOKENRESULT="${BASH_REMATCH[1]}"
[[ $GETTOKEN =~ \"canarytoken\":[[:space:]]*\"([^\"]+)\" ]] && TOKENID="${BASH_REMATCH[1]}"

if [[ "$TOKENRESULT" == *"success"* ]];
then
echo "\n[*] Token Created (ID: $TOKENID)."
else
echo "\n[X] Creation of $OUTPUTFILENAME failed."
exit -1
fi

#Download Token
echo "\n[*] Downloading Token from Console..."

curl -s -G -L --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/download" -d auth_token="$APIKEY" -d canarytoken="$TOKENID"

echo "\n[*] Token Successfully written to destination: '$OUTPUTFILENAME'."
