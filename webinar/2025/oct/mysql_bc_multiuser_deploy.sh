#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Loop through each user directory dire and adds "mysql -h $CanaryIPAddress -u 
# root -pRo0tP@ssw0rd" into bash/zsh history
# -----------------------------------------------------------------------------

# Configuration
ConsoleDomain=".canary.tools"
AuthToken="" # Read only API Key needed to fetch the IP address of the Canary from the Node ID specified. 

# Canary NodeID that Breadcrumb will point to
# The script can also be modified to just hard code the IP address of the Canary instead, then we don't need to make any API calls
CanaryNode="NODEID"

if [ "$CanaryNode" == "NODEID" ]; then
  echo "Specify a valid Canary NodeID - this should be for a Canary that is running mySQL and is reachable from the host you are deploying this breadcrumb to"
  exit 1
fi

url="https://${ConsoleDomain}/api/v1/device/info?auth_token=${AuthToken}&node_id=${CanaryNode}"
response=$(curl -sS "$url")
CanaryIPAddress=$(echo "$response" | jq -r '.device.ip_address')

os_type=$(uname)

if [ "$os_type" == "Darwin" ]; then
  # macOS
  users_base_dir="/Users"
  history_file=".zsh_history"
else
  # Linux
  users_base_dir="/home"
  history_file=".bash_history"
fi

# Get the list of user home directories excluding /Users/Shared (on OSx)
user_dirs=$(find $users_base_dir -type d -maxdepth 1 -mindepth 1 | grep -v '/Users/Shared')

# Loop through each user directory
for user_dir in $user_dirs; do
  INSERT_STR="mysql -h $CanaryIPAddress -u root -pRo0tP@ssw0rd"
  FILE="$user_dir/$history_file"

  # If the file doesn't exist, skip and move on to the next user
  if [[ ! -e "$FILE" ]]; then
    echo "Warning: file '$FILE' does not exist; skipping." >&2
    continue
  fi

  # Read all existing lines into an array
  lines=()
  while IFS= read -r line; do
    lines+=("$line")
  done < "$FILE"

  line_count=${#lines[@]}

  # If the file is empty (zero lines), append the new line and exit.
  if (( line_count == 0 )); then
    printf '%s\n' "$INSERT_STR" >> "$FILE"
    exit 0
  fi

  # Otherwise, choose a random insertion index from 0..line_count (inclusive).
  # If random_index == line_count, the new line will go at the very end.
  random_index=$(( RANDOM % (line_count + 1) ))

  # Build a new array:
  #   - all original lines before random_index
  #   - the new line (INSERT_STR)
  #   - all original lines starting at random_index
  new_lines=(
    "${lines[@]:0:random_index}"
    "$INSERT_STR"
    "${lines[@]:random_index}"
  )

  # Overwrite the file so that each element of new_lines becomes one newline-terminated line.
  printf '%s\n' "${new_lines[@]}" > "$FILE"

done

exit 0
