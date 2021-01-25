<#
.SYNOPSIS
    Creates Canarytokens and drops them on a list of remote windows hosts specified in a hosts.txt file,

.NOTES
    For this tool to work, you must have your Canary Console API enabled, please 
    follow this link to learn how to do so:
    https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-

    ###################
    How does this work?
    ###################
    1. Create a 'hosts.txt' file which contains the target hosts where you want to
    drop the Canarytokens 'hostname or IP', each host in a line.
    2. Place 'hosts.txt' in the same directory as the script.
    3. Run powershell as a user that has remote read/write access on the admin shares 
    of the remote hosts 'namely C$' ... either log in as such user, or use `runas /user:...`
    4. Provide your Console domain + API auth ... the tool will run.
    
    Last Edit: 2021-01-25
    Version 1.0 - initial release

.EXAMPLE
    .\Invoke-CreateCanarytokens.ps1
    This will run the tool with the default params

    .\Invoke-CreateCanarytokens.ps1 -TargetDirectory secret -TokenType aws-id -TokenFilename aws_secret.txt
    creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and place it under c:\secret
#>

Param (
    # Set the target Directory on hosts' root
    # tokens will be dropped at 'c:\$TargetDirectory'
    # e.g. 'c:\Backup'
    # will be created if not exists
    [string]$TargetDirectory = "Backup",

    # Valid TokenType are as follows:
    #   "aws-id":"Amazon API Key",
    #   "doc-msword":"MS Word .docx Document",
    #   "msexcel-macro":"MS Excel .xlsm Document",
    #   "msword-macro":"MS Word .docm Document",
    #   "pdf-acrobat-reader":"Acrobat Reader PDF Document",
    # if you change $TokenType, make sure to pick an appropriate filename extension in next line
    [string]$TokenType = 'doc-msword' ,
    [string]$TokenFilename = "credentials.docx",

    # Hosts file should contain the hosts on which tokens will be dropped.
    # Each host in one line.
    # The user that invoked the script should be able to map and write to admin shares
    # on those hosts.
    [string]$HostsFile = 'hosts.txt'
)

# We force TLS1.2 since our API doesn't support lower.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

# Does the file exist?
if (-not (Test-Path $HostsFile)) {
    Write-Error -ErrorAction Stop "[X] The file `'$HostsFile`' does not exist!
    ... make sure you create a file that has all the target hosts in it, each host in one line. " 
}

# Connect to API
# Get Console Domain
$ApiHost = [string]::Empty
Do {
    $ApiHost = Read-Host -Prompt "[+] Enter your Full Canary domain (e.g. 'xyz.canary.tools')"
} Until (($ApiHost.Length -gt 0) -and ([System.Net.Dns]::GetHostEntry($ApiHost).AddressList[0].IPAddressToString))

# Get API Auth Token
$ApiTokenSecure = New-Object System.Security.SecureString
Do {
    $ApiTokenSecure = Read-Host -AsSecureString -Prompt "[+] Enter your Canary API key"
} Until ($ApiTokenSecure.Length -gt 0)
$ApiToken = (New-Object System.Management.Automation.PSCredential "user", $ApiTokenSecure).GetNetworkCredential().Password

Write-Host -ForegroundColor Green "[*] Starting Script with the following params:
        Console Domain   = $ApiHost
        Target Directory = $TargetDirectory 
        Token Type       = $TokenType
        Token Filename   = $TokenFilename
"

$ApiBaseURL = '/api/v1'
Write-Host -ForegroundColor Green "[*] Pinging Console..."

$PingResult = Invoke-RestMethod -Method Get -Uri "https://$ApiHost$ApiBaseURL/ping?auth_token=$ApiToken"
$Result = $PingResult.result
If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Cannot ping Canary API. Bad token?"
    Exit
}
Else {
    Write-Host -ForegroundColor Green "[*] Canary API available for service!"
}

# Getting content of the Targets TXT file
# this should have a list of Targets' host names, each on its own line.
Write-Host -ForegroundColor Green "[+] Reading targets' Hostnames from '$HostsFile'"
$TargetsText = Get-Content $HostsFile -ErrorAction Stop


# convert the file content to an array, skipping empty lines
$Targets = $($TargetsText -split "`n").Where( { $_.Trim() -ne "" })
Write-Host -ForegroundColor Green "[*] Found a total number of '$($Targets.length)' targets..."

ForEach ($TargetHostname in $Targets) {
    Write-Host -ForegroundColor Green "[*] Working with '$TargetHostname' ..."

    $NetworkPath = "\\$TargetHostname\C`$\$TargetDirectory"
    Write-Host -ForegroundColor Green "[*] Checking if '$NetworkPath' exists..."

    # Create the target Dir if not exist
    If (!(Test-Path $NetworkPath)) {
        Write-Host -ForegroundColor Green "[*] '$NetworkPath' doesn't exist, creating it ..."
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$NetworkPath"
    }
    # Check whether token already exists
    $OutputFileName = "$NetworkPath\$TokenFilename"
    Write-Host -ForegroundColor Green "[*] Dropping '$OutputFileName' ..."

    If (Test-Path $OutputFileName) {
        Write-Host Skipping $TargetHostname, file already exists.
        Continue        
    }

    # Create token
    $TokenName = $OutputFileName
    $PostData = @{
        auth_token = "$ApiToken"
        kind       = "$TokenType"
        memo       = "$TargetHostname - $TokenName"
    }
    Write-Host -ForegroundColor Green "[*] Hitting API to create token ..."
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$ApiHost$ApiBaseURL/canarytoken/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host "Creation of $TokenName failed."
        Exit
    }
    Else {
        $WordTokenID = $($CreateResult).canarytoken.canarytoken
        Write-Host -ForegroundColor Green "[*] Token Created (ID: $WordTokenID)."
    }

    # Download token
    Write-Host -ForegroundColor Green "[*] Downloading Token from Console..."
    Invoke-RestMethod -Method Get -Uri "https://$ApiHost$ApiBaseURL/canarytoken/download?auth_token=$ApiToken&canarytoken=$WordTokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Successfully written to destination: '$OutputFileName'."
}
