#!/usr/bin/env python3
"""
Canary HTTPS Certificate Update Tool

Purpose:
  Replace the HTTPS web server certificate and key on a Canary device.
  Supports selecting HTTPS "instances" (multiple web servers) by port, name, or all.

Usage examples:
  # Update the instance on port 443
  python update_canary_https_certificate.py -domain a123456b -apikey YOUR_API_KEY -node 00000000fc738ff7 -key /path/to/privkey.key -cert /path/to/fullchain.crt --https-port 443

  # Update multiple ports (repeatable)
  python update_canary_https_certificate.py ... --https-port 443 --https-port 444

  # Match by name (case-insensitive substring; repeatable)
  python update_canary_https_certificate.py ... --https-name "Synology"

  # Update all instances
  python update_canary_https_certificate.py ... --all-instances
"""

import argparse
import json
import sys
import urllib.parse
import urllib.request


def bail(msg: str, code: int = 1) -> None:
    print(msg)
    sys.exit(code)


def fetch_device_settings(domain: str, apikey: str, node: str) -> dict:
    url = f"https://{domain}.canary.tools/api/v1/device/info"
    data = {
        "auth_token": apikey,
        "node_id": node,
        "settings": True,
        "exclude_fixed_settings": True,
    }
    # Use GET with query params (matches existing patterns)
    req = urllib.request.Request(url + "?" + urllib.parse.urlencode(data), method="GET")
    with urllib.request.urlopen(req) as resp:
        payload = resp.read().decode("utf-8")
    js = json.loads(payload)
    if js.get("result") != "success":
        bail(f"\nFailed to retrieve settings for Canary {node}: {js!r}")
    try:
        return js["device"]["settings"]
    except KeyError:
        bail("\nUnexpected API response: 'device.settings' not found.")


def push_device_settings(domain: str, apikey: str, node: str, settings: dict) -> None:
    url = f"https://{domain}.canary.tools/api/v1/device/configure"
    data = {
        "auth_token": apikey,
        "node_id": node,
        "settings": json.dumps(settings),
    }
    data_encoded = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(url, data=data_encoded, method="POST")
    with urllib.request.urlopen(req) as resp:
        payload = resp.read().decode("utf-8")
    js = json.loads(payload)
    if js.get("result") == "success":
        print(f"\nSuccessfully pushed new certificates to Canary: {node}")
        return
    bail(f"\nFailed to push updated settings for Canary {node}: {js!r}")


def load_file(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        bail(f"\nFailed to read file '{path}': {e}")


def select_https_instances(settings: dict, ports: list[int], names: list[str], all_instances: bool) -> list[int]:
    https = settings.get("services", {}).get("https", {})
    instances = https.get("instances", [])
    if not instances:
        bail("\nNo HTTPS instances found on this Canary. Nothing to update.")

    if all_instances:
        return list(range(len(instances)))

    sel = []
    port_set = set(ports or [])
    name_terms = [(n or "").strip().lower() for n in (names or []) if (n or "").strip()]
    for idx, inst in enumerate(instances):
        name = (inst.get("name") or "").lower()
        port = inst.get("port")
        port_match = (port in port_set) if port_set else False
        name_match = any(term in name for term in name_terms) if name_terms else False
        # Match if either criterion is supplied and satisfied
        if (port_set and port_match) or (name_terms and name_match):
            sel.append(idx)

    if not sel:
        print("\nNo HTTPS instances matched your selection. Available instances:")
        for inst in instances:
            print(f"  - name='{inst.get('name')}', port={inst.get('port')}, enabled={inst.get('enabled')}")
        bail("")
    return sel


def main() -> None:
    parser = argparse.ArgumentParser(description="Canary HTTPS Certificate Update Tool")
    parser.add_argument("-domain", required=True, help="Your Canary Console Domain Hash (e.g., a123456b)")
    parser.add_argument("-apikey", required=True, help="Your Canary API Key")
    parser.add_argument("-node", required=True, help="Target Canary Node ID")
    parser.add_argument("-key", required=True, help="Path to new TLS private key (.key)")
    parser.add_argument("-cert", required=True, help="Path to new TLS certificate (.crt)")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--https-port", dest="https_ports", action="append", type=int,
                       help="HTTPS instance port to update (repeatable)")
    group.add_argument("--https-name", dest="https_names", action="append",
                       help="HTTPS instance name to match (case-insensitive, substring; repeatable)")
    group.add_argument("--all-instances", action="store_true", help="Update all HTTPS instances")
    args = parser.parse_args()

    current_settings = fetch_device_settings(args.domain, args.apikey, args.node)

    # Ensure HTTPS service is enabled, else exit with specific error
    https_enabled = current_settings.get("services", {}).get("https", {}).get("enabled", False)
    if not https_enabled:
        bail("\nHTTPS service is disabled on this Canary. Please enable it (services.https.enabled = true) and re-run this tool.")

    # Read new key/cert
    new_key = load_file(args.key)
    new_cert = load_file(args.cert)

    # Select instances
    indices = select_https_instances(
        current_settings,
        ports=args.https_ports or [],
        names=args.https_names or [],
        all_instances=bool(args.all_instances),
    )

    # Apply new material to selected instances
    instances = current_settings["services"]["https"]["instances"]
    for idx in indices:
        inst = instances[idx]
        inst["key"] = new_key
        inst["certificate"] = new_cert
        print(f"Updated HTTPS instance: name='{inst.get('name')}', port={inst.get('port')}")

    # Push back
    push_device_settings(args.domain, args.apikey, args.node, current_settings)


if __name__ == "__main__":
    main()