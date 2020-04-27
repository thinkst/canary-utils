#!/usr/bin/env python
#
# Generate AWS Creds 0.1
# canarygen_awscreds.py
#
# This is the "auto" version of this script. Run it unattended and it will 
# automatically grab username and hostname variables from the system it is
# run on.
#
# PREREQS (works with python 2.7 and 3.x)
#pip -q install canarytools
#pip3 -q install canarytools
import canarytools
import getpass
import socket
import datetime

# Prep canarytools - the first parameter is the CName for your console (e.g. 
# the first part of ab1234ef.canary.tools) and the second is your Canary
# Console API key.
console = canarytools.Console("ab1234ef","deadbeef02082f1ad8bbc9cdfbfffeef")

# By default, this script uses the current user and system as the token memo
# The memo can be manually changed in the Canary Console later on. Otherwise,
# customize tokenmemo's text below.
username = getpass.getuser()
hostname = socket.gethostname()
tokenmemo = "Fake AWS creds: {} on {}".format(username, hostname)

# Create AWS Creds token
result = console.tokens.create(memo=tokenmemo, kind=canarytools.CanaryTokenKinds.AWS)
print("[default]")
print(result.access_key_id)
print(result.secret_access_key)

# Pull AWS Creds token into a file
currdatetime = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
filename = "awscreds_{}.txt".format(currdatetime)
print("\nWriting file to {}".format(filename))
f= open(filename,"w+")
f.write("[default]\n")
f.write("aws_access_key_id = {}\n".format(result.access_key_id))
f.write("aws_secret_access_key = {}\n".format(result.secret_access_key))
f.close()
