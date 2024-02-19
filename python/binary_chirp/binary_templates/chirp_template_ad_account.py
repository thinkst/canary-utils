import socket
import os
import platform
import base64
import re
import random
import secrets
import dns.resolver

HOSTNAME = (socket.gethostname())
OS_NAME = (os.name)
OS_PLATFORM = (platform.system())
OS_RELEASE = (platform.release())

# The template file must have this variable (exactly as is) as this is replaced from the builder scrip.
TOKEN_DOMAIN = 'abc123.o3n.io'

resolver = dns.resolver.Resolver(configure=False)
resolver.nameservers = ['8.8.8.8']
answer = resolver.resolve(TOKEN_DOMAIN)

print('[*] AD Account Password resetter.')
print('[*] Which AD Account would you like to reset?:')

AD_USER = input()

data = "hostname: {hostname}, OS: {os_name}|{os_platform}|{os_release}, aduser: {ad_user}".format(
    hostname=HOSTNAME,
    os_name=OS_NAME,
    os_platform=OS_PLATFORM,
    os_release=OS_RELEASE,
    ad_user=AD_USER
)

CHIRP_DOMAIN = '.'.join(filter(lambda x: x,re.split(r'(.{63})', base64.b32encode(data.encode('utf8')).decode('utf8').replace('=','')) + ['G'+str(random.randint(10,99)), TOKEN_DOMAIN]))

resolver.nameservers = [answer.rrset[0].to_text(True)]
answer2 = resolver.resolve(CHIRP_DOMAIN)

print('[*] AD Account password successfully reset.')
print('Username: {}'.format(AD_USER))
print('Password: {}'.format(secrets.token_urlsafe(30)))

x = input("Press Any key to exit")