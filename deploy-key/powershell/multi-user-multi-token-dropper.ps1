 Param (
    [string]$Domain = '.canary.tools',      # Your Console domain, for example 1234abc.canary.tools
    [string]$CanarytokenDeployKey = '',    # Canarytoken Deploy Key (Flock API key)
    [string]$PerUserPath = 'Documents\backup\2024'  # Relative path under each profile
)
####################################################################################################################################################################################################################################

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

####################################################################################################################################################################################################################################

# Common helper to create and download a token via the standard API
function New-CanaryTokenFile {
    param (
        [string]$TokenType,
        [string]$OutputFileName
    )

    $targetDirectory = Split-Path $OutputFileName -Parent

    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    if (-not (Test-Path $targetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$targetDirectory" > $null
    }

    $PostData = @{
        kind = "$TokenType"
        memo = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $OutputFileName"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }

    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    if ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed. API result: $Result"
        return
    }

    $TokenID = $CreateResult.canarytoken.canarytoken
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?canarytoken=$TokenID" -OutFile "$OutputFileName" -Headers $Header
}

####################################################################################################################################################################################################################################

# Drops an AWS API Token
function Deploy-Token_AWS {
    param (
        [string]$TokenType = 'aws-id',         # Token type
        [string]$TokenFilename = "aws.txt",    # Desired token file name
        [string]$TargetDirectory               # Target directory passed in from the profile loop
    )

    $OutputFileName = Join-Path $TargetDirectory $TokenFilename
    New-CanaryTokenFile -TokenType $TokenType -OutputFileName $OutputFileName

    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Green "[*] AWS token for '$OutputFileName' complete on $env:computername"
    }
}

####################################################################################################################################################################################################################################

# Drops a Word Token
function Deploy-Token_Word {
    param (
        [string]$TokenType = 'doc-msword',       # Word token type
        [string]$TokenFilename = "secrets.docx", # Desired token file name
        [string]$TargetDirectory                 # Target directory passed in from the profile loop
    )

    $OutputFileName = Join-Path $TargetDirectory $TokenFilename
    New-CanaryTokenFile -TokenType $TokenType -OutputFileName $OutputFileName

    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Green "[*] Word token for '$OutputFileName' complete on $env:computername"
    }
}

####################################################################################################################################################################################################################################

# Drops a PDF Token
function Deploy-Token_PDF {
    param (
        [string]$TokenType = 'pdf-acrobat-reader', # PDF token type
        [string]$TokenFilename = "PDF_Doc.pdf",    # Desired token file name
        [string]$TargetDirectory                   # Target directory passed in from the profile loop
    )

    $OutputFileName = Join-Path $TargetDirectory $TokenFilename
    New-CanaryTokenFile -TokenType $TokenType -OutputFileName $OutputFileName

    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Green "[*] PDF token for '$OutputFileName' complete on $env:computername"
    }
}

####################################################################################################################################################################################################################################

# Drops an Excel Token
function Deploy-Token_Excel {
    param (
        [string]$TokenType = 'doc-msexcel',      # Excel token type
        [string]$TokenFilename = "excel.xlsx",   # Desired token file name
        [string]$TargetDirectory                 # Target directory passed in from the profile loop
    )

    $OutputFileName = Join-Path $TargetDirectory $TokenFilename
    New-CanaryTokenFile -TokenType $TokenType -OutputFileName $OutputFileName

    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Green "[*] Excel token for '$OutputFileName' complete on $env:computername"
    }
}

####################################################################################################################################################################################################################################

# Drops a QR-Code Token
function Deploy-Token_QR {
    param (
        [string]$TokenType = 'qr-code',          # QR code token type
        [string]$TokenFilename = "QR_Code.png",  # Desired token file name
        [string]$TargetDirectory                 # Target directory passed in from the profile loop
    )

    $OutputFileName = Join-Path $TargetDirectory $TokenFilename
    New-CanaryTokenFile -TokenType $TokenType -OutputFileName $OutputFileName

    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Green "[*] QR code token for '$OutputFileName' complete on $env:computername"
    }
}

####################################################################################################################################################################################################################################

# Loop through user profiles, deploy into each user's chosen relative path
$profiles = Get-ChildItem -Path 'C:\Users' -Directory | Where-Object {
    $_.Name -notin @('Public','Default','Default User','All Users')
}

# Normalize any accidental leading backslash in PerUserPath
$relative = $PerUserPath.TrimStart('\')

foreach ($p in $profiles) {
    try {
        $target = Join-Path $p.FullName $relative
        Write-Host "[*] Deploying tokens for $($p.Name) at $target"

        Deploy-Token_AWS   -TargetDirectory $target
        #Deploy-Token_Word  -TargetDirectory $target
        #Deploy-Token_PDF   -TargetDirectory $target
        #Deploy-Token_Excel -TargetDirectory $target
        #Deploy-Token_QR    -TargetDirectory $target
    }
    catch {
        Write-Host -ForegroundColor Red "[X] $($p.Name): $($_.Exception.Message)"
    }
}
####################################################################################################################################################################################################################################
 
