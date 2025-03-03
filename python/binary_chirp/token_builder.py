#!/usr/bin/env python3

"""
Binary_Chirp : Token Builder
Generates executables embedded with a Token to fingerprint a host running them.

Exectuables can be compiled for any OS supported by PyInstaller, not only Windows. Run this on the target OS, to generate a tokened binary for that OS.
[Remember to exclude .exe from the token-filename if compiling for Linux or MacOS]

Requires pyinstaller to be installed.
$ pip install pyinstaller

Author: Gareth Wood

Date: 03 Mar 2025
Version: 1.6

Usage example:
    python token_builder.py \
        --domain abc123.canary.tools \
        --factory-auth example \
        --token-directory ~/tokened_binary \
        --token-filename admin_password_resetter.exe \
        --template chirp_template.py
"""
import argparse,os,re,shutil,socket,sys,json,urllib.request,urllib.error,urllib.parse,subprocess,http.client

def check_pyinstaller():
    try:
        import PyInstaller.__main__
    except ImportError:
        print("[!] PyInstaller is not installed.")
        choice = input("Install PyInstaller now? (y/n): ").strip().lower()
        if choice == 'y':
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
                import PyInstaller.__main__
            except Exception as e:
                print(f"[!] Failed to install PyInstaller: {e}")
                sys.exit(1)
        else:
            sys.exit("[!] PyInstaller is required. Exiting...")

def generate_token(domain, factory_auth, memo_hostname, memo_filepath):
    url = f"https://{domain}/api/v1/canarytoken/factory/create"
    payload = {
        'factory_auth': factory_auth,
        'kind': 'http',
        'memo': f"Tokened_binary - Binary_chirp - {memo_hostname} - {memo_filepath}"
    }
    try:
        request_object = urllib.request.Request(
            url,
            data=urllib.parse.urlencode(payload).encode('utf-8'),
            method='POST'
        )
        with urllib.request.urlopen(request_object, timeout=60) as response:
            response_text = response.read().decode('utf-8')
    except (urllib.error.URLError, http.client.HTTPException) as e:
        sys.exit(f"[!] Error creating token: {e}")

    try:
        response_json = json.loads(response_text)
        return response_json['canarytoken']['url']
    except (KeyError, json.JSONDecodeError) as e:
        sys.exit(f"[!] Unexpected response from token API: {e}")

def main():
    parser = argparse.ArgumentParser(
        description="""
Generates an executable embedded with a Canary token.

If you run this script without specifying any parameters, the following default
values are used:

    --domain=example.canary.tools
    --factory-auth=example
    --token-directory=.
    --token-filename=admin_password_resetter.exe
    --template=chirp_template.py
    --icon=icon.ico
    --memo-hostname=<your machine's hostname>
    --memo-filepath=./

Example usage with custom parameters:
    python script.py --domain=xyz.canary.tools --factory-auth=abc123 \
        --token-directory=/tmp/token_binaries --token-filename=my_binary.exe \
        --template=another_template.py --icon=my_icon.ico
""",
    )

    parser.add_argument('--domain',
                        default="example.canary.tools",
                        help="Your Canary Console domain (default: example.canary.tools).")

    parser.add_argument('--factory-auth',
                        default="example",
                        help="Your Factory auth key (default: 'abc123').")

    parser.add_argument('--token-directory',
                        default=".",
                        help="Directory for the tokened binary (default: current directory).")

    parser.add_argument('--token-filename',
                        default="binary_chirp.exe",
                        help="Name of the output executable (default: binary_chirp.exe).")

    parser.add_argument('--template',
                        default="chirp_template.py",
                        help="Path to the template script for embedding the token (default: chirp_template.py).")

    parser.add_argument('--icon',
                        default="icon.ico",
                        help="Icon file used by PyInstaller (default: icon.ico).")

    parser.add_argument('--memo-hostname',
                        default=socket.gethostname(),
                        help="Hostname included in the memo when creating the token (default: current hostname).")

    parser.add_argument('--memo-filepath',
                        default="./",
                        help="File path included in the memo when creating the token (default: './').")

    args = parser.parse_args()

    domain           = args.domain
    factory_auth     = args.factory_auth
    token_directory  = os.path.expanduser(args.token_directory)
    token_filename   = args.token_filename
    template_file    = args.template
    icon_file        = args.icon
    memo_hostname    = args.memo_hostname
    memo_filepath    = args.memo_filepath

    check_pyinstaller()
    token_url = generate_token(domain, factory_auth, memo_hostname, memo_filepath)
    print(f"[+] Token created successfully at: {token_url}")

    if not os.path.exists(template_file):
        sys.exit(f"[!] Template script {template_file} not found.")

    with open(template_file, 'r', encoding='utf-8') as file_in:
        script_data = file_in.read()

    script_data = re.sub(
        r"trigger_token\('.*'\)",
        f"trigger_token('{token_url}')",
        script_data
    )

    with open(template_file, 'w', encoding='utf-8') as file_out:
        file_out.write(script_data)

    import PyInstaller.__main__
    PyInstaller.__main__.run([template_file,'--onefile','--name',token_filename,'--distpath','.', '--clean','--icon',icon_file,'-y'])

    spec_file = token_filename + '.spec'
    build_dir = 'build'
    if os.path.exists(spec_file):
        os.remove(spec_file)
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)

    if not os.path.exists(token_directory):
        os.makedirs(token_directory)

    shutil.move(token_filename, os.path.join(token_directory, token_filename))
    print(f"[+] Built file moved to {os.path.join(token_directory, token_filename)}")

if __name__ == "__main__":
    main()