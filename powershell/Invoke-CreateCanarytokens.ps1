<#
.SYNOPSIS
    Creates a Canarytoken and drops it to the local host.

.NOTES
    You will need a Canarytoken Deploy Key
    https://help.canary.tools/hc/en-gb/articles/7111549805213-Flock-API-Keys

.EXAMPLE
    .\Invoke-CreateCanarytokens.ps1 -Domain aabbccdd.canary.tools -CDK XXYYZZ -TargetDirectory "c:\secret" -TokenType aws-id -TokenFilename aws_secret.txt
    Creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and places it under c:\secret
#>

Param (
    [string]$Domain = '', # e.g. 1234abc.canary.tools
    [string]$CDK = '', # Canarytoken Deploy Key
    [string]$TargetDirectory = "C:\Backup", # Local location to drop the token into
    [string]$TokenType = 'doc-msword', # e.g. aws-id, doc-msword, etc. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
    [string]$TokenFilename = "credentials.docx" # Pick an appropriate filename/extension
)

# Force TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Normalize-CanaryDomain {
    param([string]$DomainInput)

    $d = $DomainInput.Trim()

    if ($d -match '^(?i)https?://') {
        try {
            $d = ([Uri]$d).Host
        } catch {
            throw "Invalid domain/URL: $DomainInput"
        }
    }

    $d = ($d -split '/')[0].Trim().TrimEnd('.')

    if ($d -notmatch '(?i)\.canary\.tools$') {
        $d = "$d.canary.tools"
    }

    while ($d -match '(?i)\.canary\.tools\.canary\.tools$') {
        $d = $d -replace '(?i)\.canary\.tools\.canary\.tools$', '.canary.tools'
    }

    return $d
}

# Get Console Domain
$ApiHost = [string]::Empty
if ($Domain -ne '') {
    $ApiHost = Normalize-CanaryDomain -DomainInput $Domain
} else {
    do {
        $ApiHost = Read-Host -Prompt "[+] Enter your Full Canary domain (e.g. 'aabbccdd.canary.tools')"
        if ($ApiHost -ne '') {
            $ApiHost = Normalize-CanaryDomain -DomainInput $ApiHost
        }
    } until ($ApiHost.Length -gt 0)
}

# Get API Auth Token
$ApiToken = [string]::Empty
if ($CDK -ne '') {
    $ApiToken = $CDK
} else {
    $ApiTokenSecure = New-Object System.Security.SecureString
    do {
        $ApiTokenSecure = Read-Host -AsSecureString -Prompt "[+] Enter your Canary Deployment Key"
    } until ($ApiTokenSecure.Length -gt 0)

    $ApiToken = (New-Object System.Management.Automation.PSCredential "user", $ApiTokenSecure).GetNetworkCredential().Password
}

Write-Host -ForegroundColor Green "[*] Starting Script with the following params:
        Console Domain   = $ApiHost
        Target Directory = $TargetDirectory
        Token Type       = $TokenType
        Token Filename   = $TokenFilename
"

$ApiBaseURL = '/api/v1'

Write-Host -ForegroundColor Green "[*] Checking if '$TargetDirectory' exists..."

if (!(Test-Path -LiteralPath $TargetDirectory)) {
    Write-Host -ForegroundColor Green "[*] '$TargetDirectory' doesn't exist, creating it ..."
    New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path $TargetDirectory | Out-Null
}
$TargetDirectory = [System.IO.Path]::GetFullPath($TargetDirectory)
$OutputFileName = Join-Path -Path $TargetDirectory -ChildPath $TokenFilename
Write-Host -ForegroundColor Green "[*] Dropping '$OutputFileName' ..."

if (Test-Path -LiteralPath $OutputFileName) {
    Write-Host -ForegroundColor Yellow "[*] Skipping '$OutputFileName', file already exists."
    exit 0
}

$PostData = @{
    auth_token = $ApiToken
    kind       = $TokenType
    memo       = "$([System.Net.Dns]::GetHostName()) | $OutputFileName"
}

Write-Host -ForegroundColor Green "[*] Hitting API to create token ..."
$CreateResult = Invoke-RestMethod -Method Post -Uri "https://$ApiHost$ApiBaseURL/canarytoken/create" -Body $PostData

$Result = $CreateResult.result
if ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Creation of '$OutputFileName' failed."
    exit 1
} else {
    $TokenID = $CreateResult.canarytoken.canarytoken
    Write-Host -ForegroundColor Green "[*] Token Created (ID: $TokenID)."
}

# Download token to destination folder
Write-Host -ForegroundColor Green "[*] Downloading token from Console..."
$DownloadUrl = "https://$ApiHost$ApiBaseURL/canarytoken/download?auth_token=$([Uri]::EscapeDataString($ApiToken))&canarytoken=$([Uri]::EscapeDataString($TokenID))"

Invoke-RestMethod -Method Get -Uri $DownloadUrl -OutFile $OutputFileName

Write-Host -ForegroundColor Green "[*] Token successfully written to destination: '$OutputFileName'."
