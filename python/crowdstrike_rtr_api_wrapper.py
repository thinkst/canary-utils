import time
import os
import sys
import argparse
from falconpy import RealTimeResponse, RealTimeResponseAdmin, Hosts, HostGroup

print("=== 🦜 Thinkst Canary RTR API Wrapper ===")

# Ensure falconpy is installed
try:
    from falconpy import RealTimeResponse, RealTimeResponseAdmin, Hosts, HostGroup
except ImportError:
    print("⚠️ 'falconpy' is not installed. Do you want to install it now? (yes/no)")
    choice = input().strip().lower()
    if choice in ["y", "yes"]:
        print("📦 Installing falconpy...")
        os.system(f"{sys.executable} -m pip install crowdstrike-falconpy")
        print("✅ Installation complete. Please restart the script.")
        sys.exit(0)
    else:
        print("❌ falconpy is required to run this script. Exiting.")
        sys.exit(1)

# Parse command-line arguments
parser = argparse.ArgumentParser(
    description="Execute a script via CrowdStrike RTR on multiple hosts. "
                "You can specify a single host (--host), a list of hosts (--hosts-file), or a group (--group-name).",
    epilog=(
        "Example usage:\n"
        "  python script.py --client-id YOUR_ID --client-secret YOUR_SECRET --script-path script.ps1 --host my-hostname\n"
        "  python script.py --client-id YOUR_ID --client-secret YOUR_SECRET --script-path script.ps1 --hosts-file hosts.txt\n"
        "  python script.py --client-id YOUR_ID --client-secret YOUR_SECRET --script-name 'My Uploaded Script' --group-name 'My Group'\n"
        "  python script.py --client-id YOUR_ID --client-secret YOUR_SECRET --script-name 'My Uploaded Script' --host single-hostname\n"
        "  python script.py --client-id YOUR_ID --client-secret YOUR_SECRET --script-name 'My Uploaded Script' --host single-hostname --queue-offline\n"
        "  python script.py --client-id YOUR_ID --client-secret YOUR_SECRET --script-name 'My Uploaded Script' --group-name 'My Group' --queue-offline"
    ),
    formatter_class=argparse.RawTextHelpFormatter  # ✅ This ensures proper formatting of new lines
)

parser.add_argument("--client-id", required=True, help="CrowdStrike API Client ID (required).")
parser.add_argument("--client-secret", required=True, help="CrowdStrike API Client Secret (required).")
parser.add_argument("--script-path", help="Path to the script file. Required if --script-name is not provided.")
parser.add_argument("--script-name", help="Name of an existing script in CrowdStrike. Required if --script-path is not provided.")
parser.add_argument("--group-name", help="CrowdStrike host group name. Optional. Limited to 5000 hosts.")
parser.add_argument("--hosts-file", help="Path to a text file containing a list of hostnames (one per line).")
parser.add_argument("--host", help="Specify a single hostname to target. Overrides --hosts-file and --group-name.")
parser.add_argument("--queue-offline", action="store_true", help="If set, queues script execution for offline devices.")

if len(sys.argv) == 1:
    parser.print_help()
    sys.exit(1)

args = parser.parse_args()

CLIENT_ID = args.client_id
CLIENT_SECRET = args.client_secret
POWER_SHELL_SCRIPT_PATH = args.script_path
EXISTING_SCRIPT_NAME = args.script_name
TARGET_GROUP_NAME = args.group_name
HOSTS_FILE_PATH = args.hosts_file
SINGLE_HOST = args.host

SLEEP_TIME = 0.1  # Increase if you're running into Crowdstrike API Rate limits.

def upload_script(falcon_rtr_admin, script_path):
    """Upload a script file to CrowdStrike RTR cloud."""
    if not os.path.exists(script_path):
        print("❌ Script file not found.")
        return None

    print("📦 preparing to upload script...")

    platform = input("Please specify the target platform for this script. (windows, mac, linux): ").strip().lower()
    if platform not in ["windows", "mac", "linux"]:
        print("❌ Invalid platform specified.")
        return None

    with open(script_path, "rb") as script_file:
        file_upload = [('file', (os.path.basename(script_path), script_file.read(), 'application/script'))]

    data = {
        "name": os.path.basename(script_path),
        "description": "Uploaded via automation script",
        "comments_for_audit_log": "Automated script upload",
        "platform": [platform],
        "permission_type": "public",
        "share_with_workflow": "False",
        "workflow_is_disruptive": "False"
    }

    response = falcon_rtr_admin.create_scripts(files=file_upload, **data)

    if response.get("status_code") not in [200, 201]:
        print(f"❌ Failed to upload script. Response: {response}")
        return None

    print("📂 Script uploaded successfully.")
    return list_available_scripts(falcon_rtr_admin)

def list_available_scripts(falcon_rtr_admin):
    """Fetch available scripts and allow the user to select one."""

    print(f"🔍 Fetching list of available Scripts...")
    response = falcon_rtr_admin.list_scripts()

    if response.get("status_code") not in [200, 201]:
        print(f"❌ Failed to list scripts. Response: {response}")
        return None

    script_ids = response.get("body", {}).get("resources", [])

    if not script_ids:
        print("⚠️ No scripts available.")
        return None

    script_details_response = falcon_rtr_admin.get_scripts_v2(ids=script_ids)

    if script_details_response.get("status_code") not in [200, 201] or not script_details_response.get("body", {}).get("resources"):
        print(f"❌ Failed to retrieve script details. Response: {script_details_response}")
        return None

    scripts = script_details_response.get("body", {}).get("resources")

    print("\n📜 Available Scripts:")
    script_dict = {}

    for index, script in enumerate(scripts, start=1):
        script_name = script.get("name", "Unknown")
        print(f"{index}. {script_name}")
        script_dict[index] = script_name

    while True:
        try:
            choice = int(input("\nEnter the number of the script to execute: ").strip())
            if choice in script_dict:
                return script_dict[choice]
            else:
                print("❌ Invalid selection. Try again.")
        except ValueError:
            print("❌ Please enter a valid number.")

def execute_script_on_host(falcon_rtr, falcon_rtr_admin, hosts, hostname, script_name, index, total, queue_offline):
    """Find the correct device ID for a hostname and execute a script using RTR."""
    print(f"🔄 Resolving host {index}/{total}: {hostname}...")

    query_response = hosts.query_devices_by_filter(limit=3, filter=f"hostname:'{hostname}'")

    if query_response.get("status_code") not in [200, 201] or not query_response.get("body", {}).get("resources"):
        print(f"⚠️ No device found for {hostname}. Response: {query_response}")
        return

    device_ids = query_response.get("body", {}).get("resources")
    details_response = hosts.get_device_details(ids=device_ids)

    if details_response.get("status_code") not in [200, 201] or not details_response.get("body", {}).get("resources"):
        print(f"⚠️ Failed to retrieve details for {hostname}. Response: {details_response}")
        return

    device_id = None
    for device in details_response.get("body", {}).get("resources"):
        if device.get("hostname") == hostname:
            device_id = device.get("device_id")
            break

    if not device_id:
        print(f"⚠️ No matching device found for {hostname}. Skipping.")
        return

    print(f"✅ Found matching device: {device_id} (Hostname: {hostname})")

    session_response = falcon_rtr.init_session(device_id=device_id, queue_offline=queue_offline)

    if session_response.get("status_code") not in [200, 201] or not session_response.get("body", {}).get("resources"):
        print(f"⚠️ Failed to create RTR session for {hostname}. Response: {session_response}")
        return

    session_id = session_response["body"]["resources"][0].get("session_id")

    if not session_id:
        print(f"❌ RTR session ID not found for {hostname}.")
        return

    print(f"🟢 RTR session initialized for {hostname} (Session ID: {session_id})")

    execute_response = falcon_rtr_admin.execute_admin_command(
        session_id=session_id,
        base_command="runscript",
        command_string=f"runscript -CloudFile=\"{script_name}\""
    )

    if execute_response.get("status_code") in [200, 201]:
        print(f"✅ Successfully executed script on {hostname}")
    else:
        print(f"❌ Script execution failed on {hostname}. Response: {execute_response}")

def load_hostnames_from_file(file_path):
    """Read a list of hostnames from a file."""
    if not os.path.exists(file_path):
        print(f"❌ Hosts file not found: {file_path}")
        sys.exit(1)

    with open(file_path, "r") as file:
        hostnames = [line.strip() for line in file.readlines() if line.strip()]

    if not hostnames:
        print("❌ No hostnames found in the file.")
        sys.exit(1)

    return hostnames

def get_hostnames_from_group(falcon_host_group, group_name):
    """Retrieve hostnames from a specified host group."""
    if not group_name:
        return []

    print(f"🔍 Fetching group ID for: {group_name}")

    group_response = falcon_host_group.query_host_groups(filter=f"name:'{group_name}'")

    if group_response.get("status_code") not in [200, 201] or not group_response.get("body", {}).get("resources"):
        print(f"⚠️ No group found with name: {group_name}. Response: {group_response}")
        return []

    group_id = group_response["body"]["resources"][0]  # ✅ Extract the first matching group ID
    print(f"✅ Found Group ID: {group_id}")

    query_response = falcon_host_group.query_combined_group_members(id=group_id, limit=5000)

    if query_response.get("status_code") not in [200, 201] or not query_response.get("body", {}).get("resources"):
        print(f"⚠️ No devices found in group: {group_name}. Response: {query_response}")
        return []

    # ✅ Extract hostnames directly
    hostnames = [device["hostname"] for device in query_response["body"]["resources"] if "hostname" in device]

    print(f"📜 Retrieved {len(hostnames)} hostnames from group '{group_name}'.")

    return hostnames  # ✅ Returns a list of hostnames

def main():
    """Main execution flow."""
    print(f"🦅 Initializing CrowdStrike Modules...")
    
    falcon_rtr = RealTimeResponse(client_id=CLIENT_ID, client_secret=CLIENT_SECRET)
    falcon_rtr_admin = RealTimeResponseAdmin(client_id=CLIENT_ID, client_secret=CLIENT_SECRET)
    hosts = Hosts(client_id=CLIENT_ID, client_secret=CLIENT_SECRET)
    falcon_host_group = HostGroup(client_id=CLIENT_ID, client_secret=CLIENT_SECRET)

    if EXISTING_SCRIPT_NAME:
        script_name = EXISTING_SCRIPT_NAME
        print(f"🎯 Using specified script: {script_name}")
    else:
        script_name = upload_script(falcon_rtr_admin, POWER_SHELL_SCRIPT_PATH) if POWER_SHELL_SCRIPT_PATH else list_available_scripts(falcon_rtr_admin)

    if not script_name:
        print("❌ No script selected. Exiting.")
        return

    print(f"🎯 Selected Script: {script_name}")

    if SINGLE_HOST:
        all_hostnames = [SINGLE_HOST]
    elif HOSTS_FILE_PATH:
        all_hostnames = load_hostnames_from_file(HOSTS_FILE_PATH)
    elif TARGET_GROUP_NAME:
        all_hostnames = get_hostnames_from_group(falcon_host_group, TARGET_GROUP_NAME)  # ✅ Now passes correct params
    else:
        all_hostnames = []

    if not all_hostnames:
        print("❌ No hosts specified. Exiting.")
        return

    for index, hostname in enumerate(all_hostnames, start=1):
        execute_script_on_host(
            falcon_rtr, falcon_rtr_admin, hosts, hostname, script_name, index, len(all_hostnames), args.queue_offline
        )
        time.sleep(SLEEP_TIME)
    
    print(f"🏁 Deployment Complete!")

if __name__ == "__main__":
    main()