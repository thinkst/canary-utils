#!/bin/bash

console_domain=CONSOLE_DOMAIN_HERE.canary.tools # Enter your Console domain  for example 1234abc.canary.tools
auth_factory=FACTORY_AUTH_STRING_HERE # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string

config_region="us-west-2"
config_outputformat="json"

# users_base_dir="/home" # Linux
users_base_dir="/Users"  # OSx

# Get the list of user home directories excluding /Users/Shared (on OSx)
user_dirs=$(find $users_base_dir -type d -maxdepth 1 -mindepth 1 | grep -v '/Users/Shared')

# Loop through each user directory
for user_dir in $user_dirs; do
    current_username=$(basename "$user_dir")
    echo ""
    echo "Processing user: $current_username"

    # Define the AWS credentials file path for the user
    aws_dir="$user_dir/.aws"
    credentials_file="$aws_dir/credentials"
    config_file="$aws_dir/config"
    currentDateTime=$(date +"%Y-%m-%d %H:%M:%S")

    # Ensure the .aws directory exists
    if [ ! -d "$aws_dir" ]; then
        mkdir -p "$aws_dir"
        # Set the ownership to match the user directory
        chown $(stat -f "%u:%g" "$user_dir") "$aws_dir"
    fi

    # Create the token reminder
    # AWS Profile name will be an md5 hash, if a specific named profile is prefered specify it below
    new_profile=$(uuidgen | md5 | awk '{print $1}')
    tokenreminder="hostname: $HOSTNAME|username: $current_username|path: $credentials_file|profile: $new_profile|created: $currentDateTime" 
    
    awscreds=$(curl -s https://$console_domain/api/v1/canarytoken/factory/create \
    -d factory_auth=$auth_factory \
    -d memo="$tokenreminder" \
    -d kind=aws-id)

    # Since the file was created with root, we need to change it to reflect the appropriate user
    current_user_id=$(id -u "$current_username")
    current_group_id=$(id -g "$current_username")

    # Check if the credentials file already exists, we do not want to clobber it
    if [ ! -f "$credentials_file" ]; then
        echo "[$new_profile]" > "$credentials_file"
        echo $awscreds | grep -oE "aws_access_key_id = .{20}" >> "$credentials_file"    
        echo $awscreds | grep -Eo "aws_secret_access_key = .{40}" >> "$credentials_file"
        echo "Credentials file created at $credentials_file for [$new_profile] profile"

        # Set the ownership and permissions to match the user directory
        chown $current_user_id:$current_group_id "$credentials_file"
        chmod 644 "$credentials_file"
        
    else
        printf "\n[%s]\n" "$new_profile" >> "$credentials_file"
        echo $awscreds | grep -oE "aws_access_key_id = .{20}" >> "$credentials_file"
        echo $awscreds | grep -Eo "aws_secret_access_key = .{40}" >> "$credentials_file"
        echo "Token appended to $credentials_file for [$new_profile] profile"
    fi

    # Check if the config file already exists, we do not want to clobber it
    if [ ! -f "$config_file" ]; then
        echo "[$new_profile]" > $config_file
        echo "region=$config_region" >> $config_file
        echo "output=$config_outputformat" >> $config_file
        echo "Config file create at $config_file for [$new_profile] profile"

        # Set the ownership and permissions to match the user directory
        chown $current_user_id:$current_group_id "$config_file"
        chmod 644 "$config_file"
    else
        printf "\n[%s]\n" "$new_profile" >> $config_file
        echo "region=$config_region" >> $config_file
        echo "output=$config_outputformat" >> $config_file
        echo "Config file appended to $config_file for [$new_profile] profile"
    fi

done
