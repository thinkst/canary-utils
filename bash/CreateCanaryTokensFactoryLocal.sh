#!/bin/bash

#.SYNOPSIS
#    Adaption of Invoke-CreateCanarytokensFactoryLocal.ps1 to bash.
#    Creates Canarytokens and drops them to local host.
#    Uses Canarytoken Factory, so it can be safely used for mass deployment.
#
#.NOTES
#    For this tool to work, you must have your Canary Console API enabled, please 
#    follow this link to learn how to do so:
#    https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
#
#    Also, you must have a Canarytoken Factory Auth, and the Flock *ID* you want to deploy to beforehand.
#    if you don't know how, please reach out to support@canary.tools.
#
#    ###################
#    How does this work?
#    ###################
#    Requires curl and jq to be in the path
#    1. Create the flock you want the tokens to be part of in your Console.
#    2. Get the Flock ID (https://docs.canary.tools/flocks/queries.html#list-flocks-summary)
#    3. Create a Canarytoken Factory (https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string)
#    4. Make sure the host has access to the internet.
#    5. Run script as a user that has read/write access on the target directory.
#    
#    Last Edit: 2022-08-24
#    Version 1.1 - release candidate
#
#.EXAMPLE
#    sh .\CreateCanarytokensFactoryLocal.sh
#    This will run the tool with the default flock, asking interactively for missing params.
#    Flags 
#    -d Domain e.g aabbccdd.canary.tools
#    -a FactoryAuth ""
#    -f Flock ID e.g "flock:xxyyzz" Note: not setting the flock id will use "flock:default"
#    -o Output Directory e.g "~/secret"
#    -t Token Type e.g aws-id
#    -n Token Filename e.g aws_secret.txt Note: Use an appropriate extension for your token type.
#
#    sh .\CreateCanarytokensFactoryLocal.sh -d aabbccdd.canary.tools -a XXYYZZ -f flock:xxyyzz -o "~/secret" -t aws-id -n aws_secret.txt
#    creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and places it under ~/secret

#   Supported tokens are: "aws-id"                : "AWS API Key",
#                         "doc-msword"            : "MS Word Document",
#                         "msexcel-macro"         : "MS Excel Macro Document",
#                         "msword-macro"          : "MS Word Macro Document",
#                         "pdf-acrobat-reader"    : "Acrobat PDF",
#                         "slack-api"             : "Slack API Key",
#                         "windows-dir"           : "Windows Folder"

#VARIABLES
DOMAIN=""
FACTORYAUTH=""
FLOCKID="flock:default"
TARGETDIRECTORY=""
TOKENTYPE=""
TOKENFILENAME=""

#Set script flags
while getopts d:a:f:o:t:n: flag
do
    case "${flag}" in
        d) DOMAIN=${OPTARG};;
        a) FACTORYAUTH=${OPTARG};;
        f) FLOCKID=${OPTARG};;
        o) TARGETDIRECTORY=${OPTARG};;
        t) TOKENTYPE=${OPTARG};;
        n) TOKENFILENAME=${OPTARG};;
    esac
done

#Check for jq package
if ! command -v jq &> /dev/null
then
echo '\n[X] jq package not found, please install : "sudo apt-get install jq"'
exit -1
else
echo '\n[*] jq package found, proceeding'
fi

#Collect unset variables from user.
if [ -z "$TOKENTYPE" ]
then
echo '\nEnter your desired token type\n> aws-id | doc-msword | msexcel-macro | msword-macro | pdf-acrobat-reader | slack-api | windows-dir'
read TOKENTYPE
fi

#Don't continue unless $TOKENTYPE is supported
case "$TOKENTYPE" in
    "aws-id"|"doc-msword"|"msexcel-macro"|"msword-macro"|"pdf-acrobat-reader"|"slack-api"|"windows-dir") 
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

if [ -z "$FACTORYAUTH" ]
then
echo '\nEnter your Canarytoken Factory Auth String'
read FACTORYAUTH
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
echo "\nFlock ID = $FLOCKID"
echo "\nTarget Directory = $TARGETDIRECTORY"
echo "\nToken Type = $TOKENTYPE"
echo "\nToken Filename = $TOKENFILENAME" 

#Checking target directory existance
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
TOKENNAME=$OUTPUTFILENAME
MACHINEHOSTNAME=$(hostname)

echo "\n[*] Signing to the API for a token..." ;

GETTOKEN=$(curl -s -X POST "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$MACHINEHOSTNAME" "-" "$TARGETDIRECTORY"/"$TOKENFILENAME"'" -d flock_id=$FLOCKID -d kind=$TOKENTYPE --tlsv1.2 --tls-max 1.2)
TOKENRESULT=$(echo $GETTOKEN | jq -r ".result")
TOKENID=$(echo $GETTOKEN | jq -r '.canarytoken.canarytoken')

if [[ "$TOKENRESULT" == *"success"* ]];
then
echo "\n[*] Token Created (ID: $TOKENID)."
else
echo "\n[X] Creation of $TOKENNAME failed."
exit -1
fi

#Download Token
echo "\n[*] Downloading Token from Console..."

curl -s -G -L --tlsv1.2 --tls-max 1.2 --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKENID

echo "\n[*] Token Successfully written to destination: '$OUTPUTFILENAME'."
