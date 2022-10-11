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

# Ensure we have the basics set in PATH (helps for scripts run via crowdstrike)
export PATH="${PATH:+${PATH}:}/usr/sbin:/usr/bin:/sbin:/bin"

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

# The target_folder is absolute path to the folder that is targeted for tokening
# Defaults to the home folder of the user running the script if it is unset
target_folder=""

##
## Variables for this wrapper script
##

# URL of your python version of the tokenstacker, Private Repo's should follow the format of
# https://api.github.com/repos/repo_owner/private_repo_name/contents/tokenstacker_word_and_aws.py,
# public files can be referenced by https://github.com/owner/repo/raw/main/tokenstacker_word_and_aws.py
python_tokenstacker_script_url="https://github.com/thinkst/canary-utils/raw/master/python/tokenstacker_word_and_aws.py"

# Personal access token generated on Github,
# if blank the token stacker script will downloaded using public channels.
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
python_tokenstacker_github_token=""

##
## Tokenstacker wrapper script
##

# Prepare a temporary working directory
work_directory=$(mktemp -d)

# check if tmp dir was created
if [[ ! "$work_directory" || ! -d "$work_directory" ]]; then
    echo "Could not create temp dir"
    exit 1
fi

# deletes the temp directory
clean_up () {
    rm -rf "$work_directory"
    echo "Deleted temp working directory $work_directory"
}

# register the clean_up function to be called on the EXIT signal
trap clean_up EXIT

fail () {
    for arg in "$@"; do echo >&2 "$arg"; done
    exit 1
}

replace_variable () {
    local variable_name=$1
    local variable_value=$2
    local target_file=$3
    sed -i.bak "s|^$variable_name = .*|$variable_name = ${variable_value}|g" "$target_file" && rm "$target_file.bak"
}

# Fetch Python token stacker
python_script_path="$work_directory/tokenstacker_word_and_aws.py"
if [ "$python_tokenstacker_github_token" != "" ]; then
    echo "Fetching tokenstacker script with Github Access Token"
    if ! response=$(curl "$python_tokenstacker_script_url" \
                -o "$python_script_path" \
                -H "Authorization: token $python_tokenstacker_github_token" \
                -H "Accept: application/vnd.github.v3.raw" \
                --get --location --silent --show-error \
                --write-out '\n%{http_code}' 2>&1)
    then
        fail "curl encountered an error" \
                "Response: $response"
    fi
else
    echo "Fetching tokenstacker script using Github public channel"
    if ! response=$(curl "$python_tokenstacker_script_url" \
                -o "$python_script_path" \
                --get --location --silent --show-error \
                --write-out '\n%{http_code}' 2>&1)
    then
        fail "curl encountered an error" \
                "Response: $response"
    fi
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
replace_variable "DOMAIN_HASH" "\"${domain_hash}\"" "$python_script_path"
replace_variable "FACTORY_AUTH" "\"${factory_auth}\"" "$python_script_path"
replace_variable "FLOCK_ID" "\"${flock_id}\"" "$python_script_path"
replace_variable "WORD_TEMPLATE_URL" "\"${word_template_url}\"" "$python_script_path"

replace_variable "GITHUB_PERSONAL_ACCESS_TOKEN" "\"${github_personal_access_token}\"" "$python_script_path"

replace_variable "AWS_TOKEN_PLACEHOLDER_ID" "\"${aws_token_placeholder_id}\"" "$python_script_path"
replace_variable "AWS_TOKEN_PLACEHOLDER_KEY" "\"${aws_token_placeholder_key}\"" "$python_script_path"

replace_variable "TOKEN_FOLDERS" "${token_folders}" "$python_script_path"
replace_variable "TOKEN_SUB_FOLDERS" "${token_sub_folders}" "$python_script_path"
replace_variable "TOKEN_FILENAMES" "${token_filenames}" "$python_script_path"

replace_variable "TARGET_FOLDER" "\"${target_folder}\"" "$python_script_path"

# run the python token script
echo "Running tokenstacker script"

venv_directory="$work_directory/venv"
if ! /usr/bin/env python3 -m venv "$venv_directory"; then
    fail "Failed to create python virtual environment"
fi

if ! "$venv_directory/bin/python3" -m pip install requests --quiet --disable-pip-version-check; then
    fail "Failed to prepare python virtual environment"
fi

if ! "$venv_directory/bin/python3" "$python_script_path"; then
    fail "Failed to run tokenstacker script"
fi

echo "Tokening complete"
