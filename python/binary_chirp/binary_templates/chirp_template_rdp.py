import os, socket, platform, time, uuid, urllib.request, urllib.parse, getpass, secrets, subprocess

def safe_get(func, default="unknown"):
    try:
        return func()
    except Exception:
        return default

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        return s.getsockname()[0]
    except Exception:
        return "unknown"
    finally:
        s.close()

def gather_system_info():
    mac_int = safe_get(uuid.getnode, default=0)
    mac_address = "unknown" if mac_int == 0 else ':'.join([f'{(mac_int >> ele) & 0xff:02x}' for ele in range(0, 8*6, 8)][::-1])
    return {
        'hostname': safe_get(socket.gethostname),
        'os_name': safe_get(lambda: os.name),
        'os_platform': safe_get(platform.system),
        'os_release': safe_get(platform.release),
        'machine': safe_get(platform.machine),
        'processor': safe_get(platform.processor),
        'current_user': safe_get(getpass.getuser, default=os.environ.get('USER', "unknown")),
        'local_time': safe_get(time.ctime),
        'mac_address': mac_address,
        'local_ip': safe_get(get_local_ip),
        'RDP_HOST': RDP_HOST
    }

def trigger_token(endpoint_url):
    data = gather_system_info()
    encoded_data = urllib.parse.urlencode(data).encode('utf-8')
    req = urllib.request.Request(endpoint_url, data=encoded_data, method='POST')
    try:
        urllib.request.urlopen(req)
    except Exception:
        pass

def fake():
    print('[*] Welcome to the RDP gateway app.')
    print('[*] Which host would you like to remote into?: (Default AD_DC_01)')

    global RDP_HOST
    RDP_HOST = input()

    if not RDP_HOST:
        RDP_HOST = 'AD_DC_01'

    print('[*] Launching RDP to: '+RDP_HOST)
    print('Username: Administrator')
    print('Password: {}'.format(secrets.token_urlsafe(30)))

    subprocess.call('mstsc /v:'+RDP_HOST)

    x = input("Press Any key to exit")

if __name__ == '__main__':
    fake()
    trigger_token("http://example.com")