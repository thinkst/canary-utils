import argparse
import base64
import csv
import json
import sys
import textwrap
import time
from dataclasses import dataclass
from distutils.util import strtobool
from io import StringIO
from typing import Literal, Union

from rich.markdown import Markdown

if sys.version_info < (3, 10):
    print("Please use Python 3.10 or higher")
    raise SystemExit(1)
try:
    import nacl.public
    import requests
    from rich.console import Console
    from rich.prompt import Prompt
    from rich.table import Table
except ModuleNotFoundError:
    print("Please install rich, nacl and requests")
    print("python -m pip install rich nacl requests")
    raise SystemExit(1)


@dataclass
class ADJobResponse:
    result: str
    job_id: Union[str, None] = None
    job_type: Literal["join"] = "join"


@dataclass
class ADJobRequest:
    auth_token: str
    remote_ad_crypted: str
    node_id: str
    job_type: Literal["join"] = "join"

    def to_dict(self) -> str:
        data = self.__dict__.copy()
        data["type"] = data.pop("job_type")
        return data


@dataclass
class RemoteADInfo:
    node_id: str
    user: str
    password: str
    smb__domain: str
    smb__advanced_enabled: bool = False
    smb__advanced__preferred_dc__enabled: bool = False
    smb__join_serversigning: Literal["disabled", "mandatory", "auto"] = "disabled"
    smb__advanced__preferred_dc__servers: str = ""
    smb__advanced__timeserver: Union[str, None] = None
    smb__guest__enabled: bool = True
    smb__netbios_domain__enabled: bool = False
    smb__netbios_domain: str = ""

    def __post_init__(self):
        if isinstance(self.smb__advanced_enabled, str):
            self.smb__advanced_enabled = bool(strtobool(self.smb__advanced_enabled))
        if isinstance(self.smb__advanced__preferred_dc__enabled, str):
            self.smb__advanced__preferred_dc__enabled = bool(
                strtobool(self.smb__advanced__preferred_dc__enabled)
            )
        if isinstance(self.smb__join_serversigning, str):
            self.smb__join_serversigning = self.smb__join_serversigning.lower()
        if isinstance(self.smb__guest__enabled, str):
            self.smb__guest__enabled = bool(strtobool(self.smb__guest__enabled))
        if isinstance(self.smb__netbios_domain__enabled, str):
            self.smb__netbios_domain__enabled = bool(
                strtobool(self.smb__netbios_domain__enabled)
            )

    def to_json(self) -> str:
        data = self.__dict__.copy()
        data.pop("node_id")
        return json.dumps({k.replace("__", "."): v for k, v in data.items()})

    @classmethod
    def get_csv_header(cls) -> str:
        return ",".join(cls.__dataclass_fields__.keys())

    @classmethod
    def get_table_fields(cls) -> list[str]:
        return [
            o
            for o in cls.__dataclass_fields__.keys()
            if str(o) in ["node_id", "smb__domain", "user", "password"]
        ]


def encrypt_payload(payload: str, recipient_public_key_b64: str) -> str:
    sender_key_pair = nacl.public.PrivateKey.generate()
    sender_public_key = sender_key_pair.public_key.encode()

    recipient_public_key = base64.b64decode(recipient_public_key_b64)

    nonce = nacl.utils.random(nacl.public.Box.NONCE_SIZE)
    box = nacl.public.Box(
        sender_key_pair,
        nacl.public.PublicKey(recipient_public_key),
    )

    plaintext = payload.encode("utf-8")
    ciphertext = box.encrypt(plaintext, nonce)

    assert nonce == ciphertext[:24]
    encrypted = nonce + sender_public_key + ciphertext[24:]
    return base64.b64encode(encrypted)


def is_smb_enabled(settings: dict) -> bool:
    if settings is None:
        console.print("Failed to get Canary settings. Skipping", style="bold red")
        return False
    return settings["smb.enabled"]


def is_doh_enabled(settings: dict) -> bool:
    if settings is None:
        console.print("Failed to get Canary settings. Skipping", style="bold red")
        return False
    return settings["doh.enabled"]


def is_bird_ad_joined(settings: dict) -> bool:
    if settings is None:
        console.print("Failed to get Canary settings. Skipping", style="bold red")
        return False
    return settings["smb.mode"] == "domain" and settings["smb.enabled"]


def get_canary_settings(console_hash: str, node_id: str, auth_token: str) -> dict:
    url = f"https://{console_hash}.canary.tools/api/v1/device/configuration_settings"
    resp = requests.get(url, params={"auth_token": auth_token, "node_id": node_id})

    try:
        resp.raise_for_status()
        return resp.json()["settings"]
    except Exception:
        console.print(
            f"Failed to get Canary settings for {node_id}. Use python {__file__} --verbose for details.",
            style="bold red",
        )
        if args.verbose:
            console.print_exception()
        return None


def get_ad_public_key(settings) -> str:
    return settings["device.ad_pubkey"]


def start_ad_join(
    ad_pubkey: str, auth_token: str, console_hash: str, remote_ad_info: RemoteADInfo
) -> str:
    url_new_job = f"https://{console_hash}.canary.tools/api/v1/remotead/newjob"

    crypt = encrypt_payload(
        payload=remote_ad_info.to_json(), recipient_public_key_b64=ad_pubkey
    )
    join_request = ADJobRequest(
        auth_token=auth_token, remote_ad_crypted=crypt, node_id=info.node_id
    )

    resp_join = requests.post(url_new_job, data=join_request.to_dict())
    try:
        resp_join.raise_for_status()
        return resp_join.json()["job_id"]
    except Exception:
        console.print(f"Failed to start AD join", style="bold red")
        if args.verbose:
            console.print_exception()
        return None


def poll_ad_join_status(job_id: str, auth_token: str, console_hash: str):
    """Returns None if failed to poll status, otherwise returns dict of status"""
    url = f"https://{console_hash}.canary.tools/api/v1/remotead/status"
    resp = requests.get(url, params={"job_id": job_id, "auth_token": auth_token})
    try:
        resp.raise_for_status()
        return resp.json()
    except Exception:
        console.print(f"Failed to poll AD join status", style="bold red")
        if args.verbose:
            console.print_exception()
        return None


def get_args_from_file(file_path: str) -> list[RemoteADInfo]:
    with open(file_path, "r") as f:
        info_of_nodes_to_join = [
            RemoteADInfo(**{k: v for k, v in o.items() if v is not None})
            for o in csv.DictReader(f)
        ]
    return info_of_nodes_to_join


def print_table(info_of_nodes_to_join: list[RemoteADInfo], console):
    console.clear()
    table = Table(title="The following Canaries will be joined to AD")
    table_fields = RemoteADInfo.get_table_fields()
    for field in table_fields:
        table.add_column(field, style="cyan", no_wrap=True)

    for node_ad_join_info in info_of_nodes_to_join:
        table.add_row(
            *[
                str(v)
                for (k, v) in node_ad_join_info.__dict__.items()
                if str(k) in table_fields
            ]
        )

    console = Console()
    console.print(table)


def generate_file(file_path):
    with open(file_path, "w") as fp:
        fp.write(RemoteADInfo.get_csv_header() + "\n")


usage_message_markdown = Markdown(
    textwrap.dedent(
        """
# Usage
## CLI Arguments:

**To join a single canary to a single domain:**

```
python ad_join.py  cli_args --console <console_hash>        \\
                            --auth-token <auth_token>       \\
                            --node-ids <node_id>            \\
                            --username <username>           \\
                            --password '<password>'         \\
                            --domain <domain>
```

**To join multiple canaries to a single domain:**

```
python ad_joiner.py cli_args --console <console_hash>                \\
                             --auth-token <auth_token>               \\
                             --node-ids <node_id> <node_id> <...>    \\
                             --username <username>                   \\
                             --password '<password>'                 \\
                             --domain <domain>
```

## From File:
**To join multiple canaries each to a potentially different domain use the `to_file` / `from_file` options:**

__To Generate a CSV file with the required headers:__
```
python ad_joiner.py to_file --file-path <file_path>
```
__Once populated with the details of the canaries to join and AD domain then run:__
```
python ad_joiner.py from_file --console <console_hash>                \\
                              --auth-token <auth_token>               \\
                              --file-path <file_path>
```

**Degguging:**
To get verbose output add `--verbose` as the first cli argument.
```
python ad_joiner,py --verbose ...
```
"""
    )
)


def get_usage_message() -> str:
    console = Console()
    usage_message = StringIO()
    console.print(usage_message_markdown)
    return usage_message.getvalue()


if __name__ == "__main__":
    console = Console()
    parser = argparse.ArgumentParser(usage=get_usage_message())

    parser.add_argument("--verbose", help="Verbose output", action="store_true")
    subparsers = parser.add_subparsers(dest="inputs_from", required=True)
    to_file_parser = subparsers.add_parser(
        "to_file", help="creates a CSV file with the needed headers"
    )
    to_file_parser.add_argument(
        "--file-path",
        help="Generate CSV with required headers",
        default="ad_join_canary_details.csv",
    )
    cli_parser = subparsers.add_parser(
        "cli_args", help="Pass arguments from the command line"
    )
    cli_parser.add_argument(
        "--console",
        help="Console hash",
        required=True,
    )
    cli_parser.add_argument(
        "--auth-token",
        help="Console API Key",
        required=True,
    )
    cli_parser.add_argument(
        "--node-ids",
        help="Node IDs to join",
        nargs="+",
        required=True,
    )
    cli_parser.add_argument(
        "--username",
        help="Username to authenticate with",
        required=True,
    )
    cli_parser.add_argument(
        "--password",
        help="Password to authenticate with",
        required=True,
    )
    cli_parser.add_argument(
        "--domain",
        help="Domain to join",
        required=True,
    )
    file_args = subparsers.add_parser(
        "from_file", help="Pass arguments from --file-path"
    )
    file_args.add_argument(
        "--console",
        help="Console hash",
        required=True,
    )
    file_args.add_argument(
        "--auth-token",
        help="Console API Key",
        required=True,
    )
    file_args.add_argument(
        "--file-path", help="Path to CSV file with arguments", required=True
    )

    args = parser.parse_args()
    if args.inputs_from == "to_file":
        if args.file_path:
            generate_file(args.file_path)
            console.print(
                textwrap.dedent(
                    f"""
                Populate {args.file_path} with the details. 
                Only `node_id,user,password,smb__domain` are required for the rest sensible defaults are used. 
                You can specify them as needed as one would do using your Canary Console.
                Then run:"""
                ),
                style="bold green",
            )
            console.print(
                f"python {__file__} from_file --file-path {args.file_path}",
                style="bold green",
            )
            raise SystemExit(0)

    elif args.inputs_from == "from_file":
        info_of_nodes_to_join: list[RemoteADInfo] = get_args_from_file(args.file_path)

    elif args.inputs_from == "cli_args":
        domains = [args.domain] * len(args.node_ids)

        passwords = [args.password] * len(args.node_ids)
        usernames = [args.username] * len(args.node_ids)
        node_ids = args.node_ids
        info_of_nodes_to_join: list[RemoteADInfo] = [
            RemoteADInfo(
                node_id=node_id, user=username, password=password, smb__domain=domain
            )
            for node_id, username, password, domain in zip(
                node_ids, usernames, passwords, domains
            )
        ]
    else:
        console.print(
            "Must pass use `to_file` or `from_file` of `cli_args`", style="bold red"
        )
        raise SystemExit(1)

    print_table(info_of_nodes_to_join, console=console)

    all_good = Prompt.ask(
        "Confirm this is correct", choices=["Y", "N"], default="Y"
    ).upper()
    if all_good == "N":
        console.print("Exiting", style="bold red")
        raise SystemExit(1)
    canaries_to_enable_smb = []
    canaries_to_disable_doh = []
    for node_ad_join_info in info_of_nodes_to_join:
        console.print("=" * console.width)
        settings = get_canary_settings(
            console_hash=args.console,
            node_id=node_ad_join_info.node_id,
            auth_token=args.auth_token,
        )
        if settings is None:
            console.print(
                f"Failed to get Canary settings. Skipping Node ID: {node_ad_join_info.node_id}",
                style="bold red",
            )
            continue
        if is_doh_enabled(settings):
            canaries_to_disable_doh.append(node_ad_join_info.node_id)
            console.print(
                f"Node {node_ad_join_info.node_id} has DoH enabled. Cannot join AD until DoH is disabled. Skipping AD join"
            )
            node_link = Markdown(
                textwrap.dedent(
                    f"""
            Go to your [Console](https://{args.console}.canary.tools/nest/canary/{node_ad_join_info.node_id}) and disable DoH.
            """
                )
            )
            console.print(
                node_link,
                style="bold red",
            )
            continue
        if not is_smb_enabled(settings):
            canaries_to_enable_smb.append(node_ad_join_info.node_id)
            console.print(
                f"Node {node_ad_join_info.node_id} does not have SMB enabled. Skipping AD join",
            )
            node_link = Markdown(
                textwrap.dedent(
                    f"""
            Go to your [Console](https://{args.console}.canary.tools/nest/canary/{node_ad_join_info.node_id}) and enable Windows File Share.
            """
                )
            )
            console.print(
                node_link,
                style="bold red",
            )
            continue
        if is_bird_ad_joined(settings):
            console.print(
                f"Node {node_ad_join_info.node_id} is already joined",
                style="bold yellow",
            )
            continue
        ad_pubkey = get_ad_public_key(settings)
        console.print(
            f"Joining node {node_ad_join_info.node_id} to {node_ad_join_info.smb__domain}",
            style="bold green",
        )
        info = RemoteADInfo(
            node_id=node_ad_join_info.node_id,
            user=node_ad_join_info.user,
            password=node_ad_join_info.password,
            smb__domain=node_ad_join_info.smb__domain,
        )
        job_id = start_ad_join(
            ad_pubkey=ad_pubkey,
            auth_token=args.auth_token,
            console_hash=args.console,
            remote_ad_info=info,
        )
        if job_id is None:
            console.print(
                f"Skipping Node: {node_ad_join_info.node_id} failed to start join",
                style="bold red",
            )
            continue
        status = poll_ad_join_status(
            job_id=job_id, auth_token=args.auth_token, console_hash=args.console
        )
        if status is None:
            console.print(
                f"Error polling status for {node_ad_join_info.node_id}",
                style="bold red",
            )
            console.print(
                f"Skipping Node: {node_ad_join_info.node_id}", style="bold red"
            )
            console.print(
                f"Rerun with python {__file__} --verbose ...", style="bold red"
            )
            console.print(
                f"If the problem persists, contact support@canary.tools",
                style="bold red",
            )
            continue
        console.print(
            f"Waiting for node {node_ad_join_info.node_id} to join {node_ad_join_info.smb__domain}",
            style="bold yellow",
        )
        while status["result"] not in ["success", "error"]:
            console.print(f"Status: {status['result']}", style="bold yellow")
            time.sleep(5)
            status = poll_ad_join_status(
                job_id=job_id, auth_token=args.auth_token, console_hash=args.console
            )
        if status["result"] == "success":
            console.print(
                f"Node {node_ad_join_info.node_id} joined successfully {node_ad_join_info.smb__domain}",
                style="bold green",
            )
        else:
            console.print(
                f"Node {node_ad_join_info.node_id} failed to join {node_ad_join_info.smb__domain}",
                style="bold red",
            )
            try:
                console.print(f"Error: {status['data']['exception']}", style="bold red")
            except KeyError:
                console.print(
                    f"An Error occurred. Skipping {node_ad_join_info.node_id}",
                    style="bold red",
                )
                console.print(
                    f"Rerun with python {__file__} --verbose ...", style="bold red"
                )
                console.print_json(status)

    console.print("=" * console.width)
    if canaries_to_enable_smb:
        table = Table(
            title="The following Canaries must have SMB enabled before they can be joined."
        )
        table_fields = ["Node ID", "Link to Device Page (click to open)"]
        for field in table_fields:
            table.add_column(field, style="cyan", no_wrap=True)
        for node_id in canaries_to_enable_smb:
            table.add_row(
                node_id, f"https://{args.console}.canary.tools/nest/canary/{node_id}"
            )
        console.print(table)

    if canaries_to_disable_doh:
        table = Table(
            title="The following Canaries must have DoH disabled before they can be joined."
        )
        table_fields = ["Node ID", "Link to Device Page (click to open)"]
        for field in table_fields:
            table.add_column(field, style="cyan", no_wrap=True)
        for node_id in canaries_to_disable_doh:
            table.add_row(
                node_id, f"https://{args.console}.canary.tools/nest/canary/{node_id}"
            )
        console.print(table)
