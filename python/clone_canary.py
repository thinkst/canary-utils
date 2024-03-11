import requests
import json

# Canary.tools domain hash
CONSOLE_DOMAIN="abc123"
# Console's API KEY
CONSOLE_API_KEY="abc012defghi7890"
# NodeID of source Canary
CANARY_SOURCE="000abc123456789"
# NodeID of target Canary
CANARY_TARGET="111defghi999000"

# Fetch source Canary settings
source_info_url = f'https://{CONSOLE_DOMAIN}.canary.tools/api/v1/device/info'
source_info_payload = {
  'auth_token': CONSOLE_API_KEY,
  'node_id': CANARY_SOURCE,
  'settings': 'true',
  'exclude_fixed_settings' : 'true'
}

r = requests.get(source_info_url, params=source_info_payload)
source_result = r.json()["device"]
source_settings = source_result["settings"]
with open('source_settings.json', 'w') as f:
    json.dump(source_settings, f)

# Fetch target Canary settings
target_info_url = f'https://{CONSOLE_DOMAIN}.canary.tools/api/v1/device/info'
target_info_payload = {
  'auth_token': CONSOLE_API_KEY,
  'node_id': CANARY_TARGET,
  'settings': 'true',
  'exclude_fixed_settings' : 'true'
}

r = requests.get(target_info_url, params=target_info_payload)
target_result = r.json()["device"]
target_settings = target_result["settings"]
with open('target_settings.json', 'w') as f:
    json.dump(target_settings, f)

# Replace target Canary settings with source Canary settings
def replace_values(source, target, exceptions):
    for key in source.keys():
        if key not in exceptions:
            if key in target:
                source[key] = target[key]
            else:
                print("Warning: Key '{}' not found in JSON 2".format(key))

# Fields to exclude while replacing
exceptions =['https.certificate','device.custom_dns','device.desc','device.dns1','device.dns2','device.gw','device.ip_address','device.ippers','device.name','device.netmask','doh.dns_stamp','doh.enabled','doh.server_address','doh.server','firewall.enabled','firewall.rulelist']
replace_values(target_settings, source_settings, exceptions)
with open('target_settings_updated.json', 'w') as f:
    json.dump(target_settings, f)

# Push replaced settings to target Canary
configure_device_url = f'https://{CONSOLE_DOMAIN}.canary.tools/api/v1/device/configure'

configure_device_payload = {
  'auth_token': CONSOLE_API_KEY,
  'node_id': CANARY_TARGET,
  'settings': json.dumps(target_settings)
}

r = requests.post(configure_device_url, data=configure_device_payload)

print(r.json())