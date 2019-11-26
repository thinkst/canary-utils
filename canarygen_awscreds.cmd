@echo off
REM Test script to generate AWS creds

REM Requires curl and jq. Customize name/path to EXEs below.
set curl=curl
set jq=jq-win64.exe

REM Grab the date and time for creating unique files
for /f "tokens=1,2,3,4 delims=/ " %%a in ('date /t') do set currdate=%%d%%c%%b
for /f "tokens=1,2,3,4 delims=.:" %%a in ("%time%") do set currtime=%%a%%b%%c

REM Set this variable to your API token
set token=abcdef123456789

REM Customize this variable to match your console URL
set console=ab123456.canary.tools
ECHO Using console %console%

REM Token memo
set tokenmemo=\"Consider any AWS creds from %USERNAME% on %COMPUTERNAME% compromised\"

REM Base URL
set baseurl="https://$console/api/v1/canarytoken/create?auth_token=%token%&memo=%tokenmemo%&kind=aws-id&aws_id_username=%USERNAME%"

REM Run the jewels
ECHO Creating token. One moment...
%curl% -s -X POST https://%console%/api/v1/canarytoken/create -d "auth_token=%token%&memo=%tokenmemo%&kind=aws-id" | %jq% -r ".canarytoken.renders.\"aws-id\"" > awscreds_%currdate%%currtime%.txt

ECHO New AWS Credentials Canarytoken written to file awscreds_%currdate%%currtime%.txt
pause
