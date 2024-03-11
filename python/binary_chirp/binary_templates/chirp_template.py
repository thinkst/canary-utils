import socket
import os
import platform
import base64
import re
import random
import dns.resolver

HOSTNAME = (socket.gethostname())
OS_NAME = (os.name)
OS_PLATFORM = (platform.system())
OS_RELEASE = (platform.release())

# The template file must have this variable (exactly as is) as this is replaced from the builder script.
TOKEN_DOMAIN = 'abc123.o3n.io'

resolver = dns.resolver.Resolver(configure=False)
resolver.nameservers = ['8.8.8.8']
answer = resolver.resolve(TOKEN_DOMAIN)

data = "hostname: {hostname}, OS: {os_name}|{os_platform}|{os_release}".format(
    hostname=HOSTNAME,
    os_name=OS_NAME,
    os_platform=OS_PLATFORM,
    os_release=OS_RELEASE
)

CHIRP_DOMAIN = '.'.join(filter(lambda x: x,re.split(r'(.{63})', base64.b32encode(data.encode('utf8')).decode('utf8').replace('=','')) + ['G'+str(random.randint(10,99)), TOKEN_DOMAIN]))

resolver.nameservers = [answer.rrset[0].to_text(True)]
answer2 = resolver.resolve(CHIRP_DOMAIN)