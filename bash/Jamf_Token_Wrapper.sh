#!/bin/bash
set -eux
set -o pipefail

# Listing all users
TARGET_USERS=$(ls -ld /Users/* | grep -v Shared | awk '{print $3}')

for target_user in $TARGET_USERS;
do
    base64 -D -o /Users/$target_user/Downloads/tmp.sh <<< <BASE64 OF SCRIPT>
    chown -R $target_user "/Users/$target_user/Downloads/tmp.sh"
    sudo -u $target_user chmod +x "/Users/$target_user/Downloads/tmp.sh"
    sudo -u $target_user sh "/Users/$target_user/Downloads/tmp.sh"
    rm "/Users/$target_user/Downloads/tmp.sh"
done