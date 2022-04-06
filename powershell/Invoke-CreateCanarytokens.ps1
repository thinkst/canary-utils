<#
.SYNOPSIS
    Creates Canarytokens and drops them to local host. Uses Canarytoken Factory, so it can be safely used for mass deployment without revealing your API key.
.NOTES
    You will need your API enabled on your Console, A guide to enable it is available here. https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-

    ###################
    How does this work?
    ###################
    1. Create the flock you want the tokens to be part of in your console.
    2. Get the Flock ID (https://docs.canary.tools/flocks/queries.html#list-flocks-summary)
    3. Create a Canarytoken Factory (https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string)
    4. Make sure the host has access to the internet.
    5. Run powershell as a user that has read/write access on the target directory.
    
    Last Edit: 2021-07-15
    Version 1.1 - Condensed Instructions
.EXAMPLE
    .\Invoke-CreateCanarytokensFactoryLocal.ps1
    This will run the tool with the default params, asking interactively for missing ones.

    .\Invoke-CreateCanarytokensFactoryLocal.ps1 -Domain aabbccdd.canary.tools -FactoryAuth XXYYZZ -TargetDirectory "c:\secret" -TokenType aws-id -TokenFilename aws_secret.txt
    creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and place it under c:\secret
#>

Param (
    [string]$Domain = '', # Enter your Console domain between the quotes. e.g. 1234abc.canary.tools
    [string]$FactoryAuth = '', # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    [string]$FlockID = 'flock:default', # Enter desired flock to place tokens in. This mis required. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors
    [string]$TargetDirectory = "c:\Backup", # Local location to drop the token into. This will be created if it does not exist.
    [string]$TokenType = 'doc-msword' , # Enter your desired token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factoryif
    [string]$TokenFilename = "credentials.docx" # Desired Token file name. Make sure to pick an appropriate filename extension in next line.
)

# We force TLS1.2 since our API doesn't support lower.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

# Connect to API
# Get Console Domain
$ApiHost = [string]::Empty
if ($Domain -ne '') {
    $ApiHost = $Domain
} else {
    Do {
        $ApiHost = Read-Host -Prompt "[+] Enter your Full Canary domain (e.g. 'xyz.canary.tools')"
    } Until (($ApiHost.Length -gt 0) -and ([System.Net.Dns]::GetHostEntry($ApiHost).AddressList[0].IPAddressToString))
}

# Get API Auth Token
$ApiToken = [string]::Empty
if ($FactoryAuth -ne '') {
    $ApiToken = $FactoryAuth
} else {
    $ApiTokenSecure = New-Object System.Security.SecureString
    Do {
        $ApiTokenSecure = Read-Host -AsSecureString -Prompt "[+] Enter your Canary Factory Auth key"
    } Until ($ApiTokenSecure.Length -gt 0)
    $ApiToken = (New-Object System.Management.Automation.PSCredential "user", $ApiTokenSecure).GetNetworkCredential().Password
}

Write-Host -ForegroundColor Green "[*] Starting Script with the following params:
        Console Domain   = $ApiHost
        Flock ID         = $FlockID
        Target Directory = $TargetDirectory 
        Token Type       = $TokenType
        Token Filename   = $TokenFilename
"

$ApiBaseURL = '/api/v1'

Write-Host -ForegroundColor Green "[*] Checking if '$TargetDirectory' exists..."

# Creates the target directory if it does not exist
If (!(Test-Path $TargetDirectory)) {
    Write-Host -ForegroundColor Green "[*] '$TargetDirectory' doesn't exist, creating it ..."
    New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory"
}
# Check whether token file already exists on the local machine
$OutputFileName = "$TargetDirectory\$TokenFilename"
Write-Host -ForegroundColor Green "[*] Dropping '$OutputFileName' ..."

If (Test-Path $OutputFileName) {
    Write-Host Skipping $OutputFileName, file already exists.
    Continue        
}

# Create token on Console
$TokenName = $OutputFileName
$PostData = @{
    factory_auth = "$ApiToken"
    kind       = "$TokenType"
    flock_id = "$FlockID"
    memo       = "$([System.Net.Dns]::GetHostName()) - $TokenName"
}
Write-Host -ForegroundColor Green "[*] Hitting API to create token ..."
$CreateResult = Invoke-RestMethod -Method Post -Uri "https://$ApiHost$ApiBaseURL/canarytoken/factory/create" -Body $PostData
$Result = $CreateResult.result
If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Creation of $TokenName failed."
    Exit
}
Else {
    $TokenID = $($CreateResult).canarytoken.canarytoken
    Write-Host -ForegroundColor Green "[*] Token Created (ID: $TokenID)."
}

# Downloads token and places it in the destination folder.
Write-Host -ForegroundColor Green "[*] Downloading Token from Console..."
Invoke-RestMethod -Method Get -Uri "https://$ApiHost$ApiBaseURL/canarytoken/factory/download?factory_auth=$ApiToken&canarytoken=$TokenID" -OutFile "$OutputFileName"
Write-Host -ForegroundColor Green "[*] Token Successfully written to destination: '$OutputFileName'."
