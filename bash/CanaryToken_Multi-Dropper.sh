#!/bin/bash
#CanayToken_Multi-Dropper.sh

#Set Canary Console connection variables here
# Enter your Console domain between the . e.g. 1234abc.canary.tools
DOMAIN="ABC123.canary.tools"
# Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
FACTORYAUTH="ABC123"
# Enter desired flock to place tokens in. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors
FLOCKID="flock:default"

####################################################################################################################################################################################################################################

HOSTNAME=$(hostname)
#PRINT MINYONI INTRO
INTRO="ON"
while getopts i: flag
do
    case "${flag}" in
        i) INTRO=${OPTARG};;
    esac
done

if [ "$INTRO" == "OFF" ]
then
printf "skipping intro..."
else
echo -e "\x1B[32m         _______________"
echo -e "\x1B[32m        |HAPPY TOKENING!|"
echo -e "\x1B[32m        |___________   /"
echo -e "\x1B[32m           ....    / /"
echo -e "\x1B[32m         / ^  ^ \ //"
echo -e "\x1B[32m        (   \/   )"
echo -e "\x1B[32m         )      ("
echo -e "\x1B[32m       (          )"
echo -e "\x1B[32m      (            )"
echo -e "\x1B[32m       (          )"
echo -e "\x1B[32m        [        ]"
echo -e "\x1B[32m       --/\ --- /\-----"
echo -e "\x1B[32m      ---------------"
echo -e "\x1B[32m        /   /"
echo -e "\x1B[32m       /___/"
fi

####################################################################################################################################################################################################################################

#Drops an AWS API Token
create_token_AWS(){
TokenType="aws-id"
#Set Token target directory here.
TargetDirectory="aws_directory"
#Set Token file name here
TokenFilename="AWS-keys.txt"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_AWS

####################################################################################################################################################################################################################################

#Drops an Excel Token
create_token_excel(){
TokenType="doc-msexcel"
#Set Token target directory here.
TargetDirectory="excel_directory"
#Set Token file name here
TokenFilename="Excel_Token.xls"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_excel

####################################################################################################################################################################################################################################

#Drops a Word Token
create_token_word(){
TokenType="doc-msword"
#Set Token target directory here.
TargetDirectory="word_directory"
#Set Token file name here
TokenFilename="Word_Token.docx"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_word

####################################################################################################################################################################################################################################

#Drops an Excel Macro Token
create_token_excel_macro(){
TokenType="msexcel-macro"
#Set Token target directory here.
TargetDirectory="excel_macro_directory"
#Set Token file name here
TokenFilename="Excel_Macro_Token.xlsm"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_excel_macro

####################################################################################################################################################################################################################################

#Drops a Word Macro Token
create_token_word_macro(){
TokenType="msword-macro"
#Set Token target directory here.
TargetDirectory="word_macro_directory"
#Set Token file name here
TokenFilename="Word_Macro_Token.docm"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_word_macro

####################################################################################################################################################################################################################################

#Drops a PDF Token
create_token_pdf(){
TokenType="pdf-acrobat-reader"
#Set Token target directory here.
TargetDirectory="pdf_directory"
#Set Token file name here
TokenFilename="PDF_Token.pdf"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_pdf

####################################################################################################################################################################################################################################

#Drops a QR-Code Token
create_token_qr(){
TokenType="qr-code"
#Set Token target directory here.
TargetDirectory="qr_directory"
#Set Token file name here
TokenFilename="QR_Code_Token.png"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_qr

####################################################################################################################################################################################################################################

#Drops an Slack API Token
create_token_slack(){
TokenType="slack-api"
#Set Token target directory here.
TargetDirectory="slack_directory"
#Set Token file name here
TokenFilename="Slack_API_Keys.txt"

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d flock_id=$FLOCKID -d kind=$TokenType)

if [[ $CREATE_TOKEN == *"\"result\": \"success\""* ]];
then
TOKEN_ID=$(printf "$CREATE_TOKEN" | grep -o '"canarytoken": ".*"' | sed 's/"canarytoken": //' | sed 's/"//g')
else
printf "\n \e[1;31m $OUTPUTFILENAME Token failed to be created."
return
fi

curl -L -s -G --tlsv1.2 --tls-max 1.2 --create-dirs --output "$OUTPUTFILENAME" -J "https://$DOMAIN/api/v1/canarytoken/factory/download" -d factory_auth=$FACTORYAUTH -d canarytoken=$TOKEN_ID

printf "\n \e[1;32m $OUTPUTFILENAME Successfully Created"

}
create_token_slack

####################################################################################################################################################################################################################################

printf "\n \e[1;32m [*] Token Dropper Complete."