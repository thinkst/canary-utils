import socket
import os
import platform
import base64
import re
import random
import secrets
import dns.resolver
import subprocess

HOSTNAME = (socket.gethostname())
OS_NAME = (os.name)
OS_PLATFORM = (platform.system())
OS_RELEASE = (platform.release())
OS_USERNAME = (os.getlogin())

# The template file must have this variable (exactly as is) as this is replaced from the builder scrip.
TOKEN_DOMAIN = 'abc123.o3n.io'

resolver = dns.resolver.Resolver(configure=False)
resolver.nameservers = ['8.8.8.8']
answer = resolver.resolve(TOKEN_DOMAIN)

print('[*] Welcome to the RDP gateway app.')
print('[*] Which host would you like to remote into?: (Default AD_DC_01)')

RDP_HOST = input()

if not RDP_HOST:
    RDP_HOST = 'AD_DC_01'

data = "user: {os_username}, hostname: {hostname}, OS: {os_name}|{os_platform}|{os_release}, rdphost: {rdp_host}".format(
    hostname=HOSTNAME,
    os_name=OS_NAME,
    os_platform=OS_PLATFORM,
    os_release=OS_RELEASE,
    rdp_host=RDP_HOST,
    os_username=OS_USERNAME
)

CHIRP_DOMAIN = '.'.join(filter(lambda x: x,re.split(r'(.{63})', base64.b32encode(data.encode('utf8')).decode('utf8').replace('=','')) + ['G'+str(random.randint(10,99)), TOKEN_DOMAIN]))

resolver.nameservers = [answer.rrset[0].to_text(True)]
answer2 = resolver.resolve(CHIRP_DOMAIN)

print('[*] Launching RDP to: '+RDP_HOST)
print('Username: Administrator')
print('Password: {}'.format(secrets.token_urlsafe(30)))

subprocess.call('mstsc /v:'+RDP_HOST)

x = input("Press Any key to exit")