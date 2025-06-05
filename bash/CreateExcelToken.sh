#!/bin/bash
#CanayToken_Multi-Dropper.sh

#Set Canary Console connection variables here
# Enter your Console domain between the . e.g. 1234abc.canary.tools
DOMAIN=".canary.tools"
# Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
FACTORYAUTH=""

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

#Drops an Excel Token
create_token_excel(){
TokenType="doc-msexcel"
#Set Token target directory here.
TargetDirectory="/"
#Set Token file name here
TokenFilename=""

OUTPUTFILENAME="$TargetDirectory/$TokenFilename"

if [ -f "$OUTPUTFILENAME" ];
then
printf "\n \e[1;33m $OUTPUTFILENAME already exists.";
return
fi

CREATE_TOKEN=$(curl -L -s -X POST --tlsv1.2 --tls-max 1.2 "https://${DOMAIN}/api/v1/canarytoken/factory/create" -d factory_auth=$FACTORYAUTH -d memo="'"$HOSTNAME" "-" "$OUTPUTFILENAME"'" -d kind=$TokenType)

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
