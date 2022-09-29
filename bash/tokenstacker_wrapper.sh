#!/usr/bin/env bash

set -eu
set -o pipefail

# Tokenstacker - Wrapper
# This script is a wrapper for the python version of Tokenstacker.
# A python virtual environment will be configured and the python Tokenstacker script
# downloaded from github. After downloading the python script the relevant script
# variables will be updated as they are configured in this bash script.
# After preparing the virtual environment and configuring the python script it will be
# executed to do the tokening.
#
# Using this script to overcome some of the limitations such as certain
# binaries not being installed and to have a contained tokening environment.

##
## Customize these variables to match the environment, they will be used to update the python script
##

# Enter your Console domain hash between the quotes. e.g. 1234abc.canary.tools
# where "1234abcd" is your console's unique CNAME
domain_hash="1234abc"

# Enter your Factory auth key. e.g a1bc3e769fg832hij3
# https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
factory_auth="a1bc3e769fg832hij3"

# Enter the desired flock to place tokens in.
# https://docs.canary.tools/flocks/queries.html#list-flock-sensors
flock_id="flock:default"

# URL of your template, Private Repo's should follow the format of
# https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx,
# public files can be referenced by https://github.com/owner/repo/raw/main/template.docx
word_template_url="https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx"

# Personal access token generated on Github,
# if blank the template will downloaded using public channels.
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
github_personal_access_token="gh_abcdefghijklmnop123"

# The text within the word template that will be replaced with an AWS Token ID.
aws_token_placeholder_id="AWS_ACCESS_KEY_ID"

# The text within the word template that will be replaced with an AWS Token Key.
aws_token_placeholder_key="AWS_SECRET_ACCESS_KEY"

# Randomise the Token deployment path, this list can edited to your preferences.
# Note this is defined in python array syntax as strings
token_folders="['Acronis', 'Github', 'Zoho', 'Confluence', 'Hubspot', 'Okta', 'Gitlab', 'Postman', 'Veeam', 'Redstore']"
token_sub_folders="['Temp','Backup', 'Archive', 'Secrets']"
token_filenames="['Emergency.docx', 'Credentials.docx', 'Access.docx', 'Accounts.docx']"

##
## Variables for this wrapper script
##

# URL of your python version of the tokenstacker, Private Repo's should follow the format of
# https://api.github.com/repos/repo_owner/private_repo_name/contents/tokenstacker_word_and_aws.py,
# public files can be referenced by https://github.com/owner/repo/raw/main/tokenstacker_word_and_aws.py
python_tokenstacker_script_url="https://github.com/thinkst/canary-utils/raw/master/python/tokenstacker_word_and_aws.py"

current_working_directory=$(pwd)
work_directory="$current_working_directory/tmp"
venv_directory="$work_directory/venv"
python_script_path="$work_directory/tokenstacker_word_and_aws.py"


##
## Tokenstacker wrapper script
##

# Ensure the work directory exists
mkdir -p "$work_directory"

# Fetch Python token stacker
if [ "$github_personal_access_token" != "" ]; then
    echo "Fetching tokenstacker script with Github Access Token"
    response=$(curl "$python_tokenstacker_script_url" \
                -o "$python_script_path" \
                -d Authorization="token $github_personal_access_token" \
                -d Accept="application/vnd.github.v3.raw" \
                --get --location --silent --show-error \
                --write-out '\n%{http_code}' 2>&1)
else
    echo "Fetching tokenstacker script using Github public channel"
    response=$(curl "$python_tokenstacker_script_url" \
                -o "$python_script_path" \
                --get --location --silent --show-error \
                --write-out '\n%{http_code}' 2>&1)
fi
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Failed to fetch the python tokenstacker script" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

# prepare the python token script
echo "Updating variables in tokenstacker script"
sed -i.bak "s|DOMAIN_HASH = .*|DOMAIN_HASH = \"${domain_hash}\"|g" "$python_script_path" && rm "$python_script_path.bak"
sed -i.bak "s|FACTORY_AUTH = .*|FACTORY_AUTH = \"${factory_auth}\"|g" "$python_script_path" && rm "$python_script_path.bak"
sed -i.bak "s|FLOCK_ID = .*|FLOCK_ID = \"${flock_id}\"|g" "$python_script_path" && rm "$python_script_path.bak"
sed -i.bak "s|WORD_TEMPLATE_URL = .*|WORD_TEMPLATE_URL = \"${word_template_url}\"|g" "$python_script_path" && rm "$python_script_path.bak"

sed -i.bak "s|GITHUB_PERSONAL_ACCESS_TOKEN = .*|GITHUB_PERSONAL_ACCESS_TOKEN = \"${github_personal_access_token}\"|g" "$python_script_path" && rm "$python_script_path.bak"

sed -i.bak "s|AWS_TOKEN_PLACEHOLDER_ID = .*|AWS_TOKEN_PLACEHOLDER_ID = \"${aws_token_placeholder_id}\"|g" "$python_script_path" && rm "$python_script_path.bak"
sed -i.bak "s|AWS_TOKEN_PLACEHOLDER_KEY = .*|AWS_TOKEN_PLACEHOLDER_KEY = \"${aws_token_placeholder_key}\"|g" "$python_script_path" && rm "$python_script_path.bak"

sed -i.bak "s|TokenFolder_list = .*|TokenFolder_list = ${token_folders}|g" "$python_script_path" && rm "$python_script_path.bak"
sed -i.bak "s|TokenSubFolder_list = .*|TokenSubFolder_list = ${token_sub_folders}|g" "$python_script_path" && rm "$python_script_path.bak"
sed -i.bak "s|TokenFilename_list = .*|TokenFilename_list = ${token_filenames}|g" "$python_script_path" && rm "$python_script_path.bak"

# run the python token script
echo "Running tokenstacker script"

if ! /usr/bin/env python3 -m venv "$venv_directory"; then
    echo "Failed to create python virtual environment"
    exit 1
fi

if ! "$venv_directory/bin/python3" -m pip install requests --quiet --disable-pip-version-check; then
    echo "Failed to prepare python virtual environment"
    exit 1
fi

if ! "$venv_directory/bin/python3" "$python_script_path"; then
    echo "Failed to run tokenstacker script"
    exit 1
fi

echo "Cleaning up temporary python virtual environment"
rm -rf "$work_directory"

echo "Tokening complete"
