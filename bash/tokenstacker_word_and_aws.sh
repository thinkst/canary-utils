#!/usr/bin/env bash

set -eu
set -o pipefail

# Tokenstacker - Word and AWS
# This script will download a Word Template from a private github repo,
# Token it, then embed an AWS API Token inside and save it to a realistic directory.
# For example: ~/Gitlab/Secrets/Credentials.docx
# Contact support@canary.tools for assistance.

##
## Customize these variables to match the environment
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
token_folders=('Acronis' 'Github' 'Zoho' 'Confluence' 'Hubspot' 'Okta' 'Gitlab' 'Postman' 'Veeam' 'Redstore')
token_sub_folders=('Temp' 'Backup' 'Archive' 'Secrets')
token_filenames=('Emergency.docx' 'Credentials.docx' 'Access.docx' 'Accounts.docx')

# The target_folder is absolute path to the folder that is targeted for tokening
# Defaults to the home folder of the user running the script if it is unset
target_folder=""

##
## Tokenstacker script
##

random_between_numbers () {
    local min_value=$1
    local max_value=$2
    awk -v min="$min_value" -v max="$max_value" -v seed=$RANDOM 'BEGIN{srand(seed); print int(min+rand()*(max-min+1))}'
}

random_item_from_array () {
    local array=("$@")

    array_length=$((${#array[@]} - 1 ))
    index=modified_timestamp=$(random_between_numbers 0 "$array_length")
    echo "${array[$index]}"
}

fail () {
    echo '' # Newline to not override status feedback
    for arg in "$@"; do echo >&2 "$arg"; done
    exit 1
}


# Check command prerequisites
if ! command -v curl &> /dev/null; then
    fail "I require curl but it's not installed.  Aborting."
fi
if ! command -v tar &> /dev/null; then
    fail "I require tar but it's not installed.  Aborting."
fi
if ! command -v zip &> /dev/null; then
    fail "I require zip but it's not installed.  Aborting."
fi

# Prepare variables
if [ $target_folder == "" ]; then
    target_folder=$HOME
fi

base_url="https://$domain_hash.canary.tools"
random_token_folder=$(random_item_from_array "${token_folders[@]}")
random_token_sub_folder=$(random_item_from_array "${token_sub_folders[@]}")
random_token_filename=$(random_item_from_array "${token_filenames[@]}")
token_folder="$target_folder/$random_token_folder/$random_token_sub_folder"
token_path="$token_folder/$random_token_filename"

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

echo "Creating token: $token_path"

# Ensure the target directory exists
mkdir -p "$token_folder"

# Create AWS Token on Canary Console
echo "Creating AWS token"
memo="$HOSTNAME - Embedded AWS Token in $token_path"
response=$(curl "$base_url"/api/v1/canarytoken/factory/create \
            -d factory_auth="$factory_auth" \
            -d kind="aws-id" \
            -d flock_id="$flock_id" \
            -d memo="$memo" \
            --silent --show-error \
            --write-out '%{http_code}' 2>&1)
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Failed to create AWS token on console" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

aws_token_id=$(jq -r '.canarytoken.canarytoken' <<< "$content")

# Fetch the token payload
response=$(curl "$base_url"/api/v1/canarytoken/factory/download \
            -d factory_auth="$factory_auth" \
            -d canarytoken="$aws_token_id" \
            --get --location --silent --show-error \
            --write-out '\n%{http_code}' 2>&1)
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Failed to fetch AWS token payload" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

token_aws_access_key_id=$(sed -n -e '/^aws_access_key_id=/p' <<< "$content" | sed 's/^aws_access_key_id=//g')
token_aws_secret_access_key=$(sed -n -e '/^aws_secret_access_key=/p' <<< "$content" | sed 's/^aws_secret_access_key=//g')

# Fetch Word Template
if [ "$github_personal_access_token" != "" ]; then
    echo "Fetching Template with Github Access Token"
    response=$(curl "$word_template_url" \
                -o "$token_path" \
                -H "Authorization: token $github_personal_access_token" \
                -H "Accept: application/vnd.github.v3.raw" \
                --get --location --silent --show-error \
                --write-out '\n%{http_code}' 2>&1)
else
    echo "Fetching Template using Github public channel"
    response=$(curl "$word_template_url" \
                -o "$token_path" \
                --get --location --silent --show-error \
                --write-out '\n%{http_code}' 2>&1)
fi
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Failed to fetch the Word template" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

# Upload template to Canary Console for Tokening
echo "Creating Word token"
memo="$HOSTNAME - $token_path"
response=$(curl "$base_url"/api/v1/canarytoken/factory/create \
            -F factory_auth="$factory_auth" \
            -F kind="doc-msword" \
            -F flock_id="$flock_id" \
            -F memo="$memo" \
            -F "doc=@$token_path; type=application/vnd.openxmlformats-officedocument.wordprocessingml.document" \
            --silent --show-error \
            --write-out '%{http_code}' 2>&1)
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Failed to create Word token on console" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

word_token_id=$(jq -r '.canarytoken.canarytoken' <<< "$content")

# Fetch the word token
response=$(curl "$base_url"/api/v1/canarytoken/factory/download \
            -d factory_auth="$factory_auth" \
            -d canarytoken="$word_token_id" \
            -o "$token_path" \
            --get --location --silent --show-error \
            --write-out '\n%{http_code}' 2>&1)
http_code=$(tail -n1 <<< "$response")  # get the last line
content=$(sed '$ d' <<< "$response")   # get all but the last line which contains the status code

if [ "$http_code" != "200" ]; then
    fail "Failed to fetch Word token payload" \
            "HTTP Code: $http_code" \
            "Content: $content"
fi

# Unzip Word doc to insert AWS Token and rebuild.
echo "Embed AWS token in Word token"
tar -xf "$token_path" -C "$work_directory"

# Replace the AWS token place holders in the word doc
target_file="$work_directory/word/document.xml"
sed -i.bak "s|${aws_token_placeholder_id}|${token_aws_access_key_id}|g" "$target_file" && rm "$target_file.bak"
sed -i.bak "s|${aws_token_placeholder_key}|${token_aws_secret_access_key}|g" "$target_file" && rm "$target_file.bak"

# Zip up the word doc again
pushd "$work_directory" > /dev/null
zip -q -r "$token_path" ./*
popd > /dev/null

# Randomise Token metadata.
current_epoch=$(date +%s)
max_old_epoch=$(("$current_epoch" - 31536000))
modified_timestamp=$(random_between_numbers "$current_epoch" "$max_old_epoch")

case $(uname | tr '[:upper:]' '[:lower:]') in
    linux*)
        formatted_timestamp=$(date -d @"$modified_timestamp" +%Y%m%d%H%M.%S)
        ;;
    darwin*)
        formatted_timestamp=$(date -r "$modified_timestamp" +%Y%m%d%H%M.%S)
        ;;
    *)
        echo "Unexpected OS; Skip setting the time stamp of the token"
        exit
        ;;
esac

touch -a -m -t "$formatted_timestamp" "$target_folder/$random_token_folder"
touch -a -m -t "$formatted_timestamp" "$target_folder/$random_token_folder/$random_token_sub_folder"
touch -a -m -t "$formatted_timestamp" "$token_path"

echo "Token successfully saved to $token_path"
