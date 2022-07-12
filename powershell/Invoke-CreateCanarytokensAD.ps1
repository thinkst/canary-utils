<#
.SYNOPSIS
Creates Canarytokens and drops them on a list of remote windows in an AD OU,

.NOTES
For this tool to work, you must have your Canary Console API enabled, please
follow this link to learn how to do so:
https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-

###################
How does this work?
###################
1. Place the computers you want to drop tokens to in an OU
2. Run powershell as a user that has remote read/write access on the admin shares
of the remote hosts 'namely C$' ... either log in as such user, or use `runas /user:...`
3. Provide your Console domain + API auth
4. Type the name of the OU

Last Edit: 2022-06-29
Version 1.0 - initial release

.EXAMPLE
.\Invoke-CreateCanarytokensAD.ps1
This will run the tool with the default params

.\Invoke-CreateCanarytokensAD.ps1 -TargetDirectory secret -TokenType aws-id -TokenFilename aws_secret.txt
creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and place it under c:\secret
#>

Param (
    # Full canary domain (e.g. aabbccdd.canary.tools),
    # if empty, will be asked for interactively
    [string]$Domain = '',

    # API Auth token,
    # if empty, will be asked for interactively
    [string]$ApiAuth = '',

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

    # Name or DistinguishedName of the OU.
    # Each computer in this OU will have a token dropped to it.
    # The user that invoked the script should be able to map and write to admin shares
    # on those hosts.
    # Example of a DistinguishedName "OU=Finance,OU=OurWorkstations,DC=stretch,DC=local"
    # if empty, will be asked for interactively
    [string]$OU = ''
    )

    # We force TLS1.2 since our API doesn't support lower.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
    Set-StrictMode -Version 2.0

    Write-Host -ForegroundColor Green "[***] Thinkst Canarytoken Dropper [***]"
    Write-Host -ForegroundColor Green "              Version: 1.1`n`n"

    # Import ActiveDirectory functions
    Import-Module ActiveDirectory

    # Connect to API
    # Get Console Domain
    $ApiHost = [string]::Empty
    if ($Domain -ne '') {
        $ApiHost = $Domain
    }
    else {
        Do {
            $ApiHost = Read-Host -Prompt "[+] Enter your Full Canary domain (e.g. 'xyz.canary.tools')"
        } Until (($ApiHost.Length -gt 0) -and ([System.Net.Dns]::GetHostEntry($ApiHost).AddressList[0].IPAddressToString))
    }

    # Get API Auth Token
    $ApiToken = [string]::Empty
    if ($ApiAuth -ne '') {
        $ApiToken = $ApiAuth
    }
    else {
        $ApiTokenSecure = New-Object System.Security.SecureString
        Do {
        $ApiTokenSecure = Read-Host -AsSecureString -Prompt "[+] Enter your Canary API key"
    } Until ($ApiTokenSecure.Length -gt 0)
    $ApiToken = (New-Object System.Management.Automation.PSCredential "user", $ApiTokenSecure).GetNetworkCredential().Password
}

# Get Dir name if not provided
if ($TargetDirectory -eq '') {
    Do {
        $TargetDirectory = Read-Host -Prompt "[+] Enter the Target Dir name 'e.g. Backup'"
    } Until ($TargetDirectory.Length -gt 0)
}

# Get token type if not provided
if ($TokenType -eq '') {
    Do {
        $TokenType = Read-Host -Prompt "[+] Enter the token type 'e.g. doc-msword'"
    } Until ($TokenType.Length -gt 0)
}

# Get token filename if not provided
if ($TokenFilename -eq '') {
    Do {
        $TokenFilename = Read-Host -Prompt "[+] Enter the token filename 'e.g. confidential.docx'"
    } Until ($TokenFilename.Length -gt 0)
}

Write-Host -ForegroundColor Green "[*] Starting Script with the following params:
Console Domain   = $ApiHost
Target Directory = $TargetDirectory
Token Type       = $TokenType
Token Filename   = $TokenFilename
"

$ApiBaseURL = '/api/v1'
Write-Host -ForegroundColor Green "[*] Pinging Console..."

$PingResult = Invoke-RestMethod -Method Get -Uri "https://$ApiHost$ApiBaseURL/ping?auth_token=$ApiToken" -ErrorAction Stop
$Result = $PingResult.result
If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Cannot ping Canary API. Bad token? Network issues?"
    Exit
}
Else {
    Write-Host -ForegroundColor Green "[*] Canary API available for service!"
}

# this will host the OU that the tool will work on
$ChosenOU = New-Object -TypeName Microsoft.ActiveDirectory.Management.ADOrganizationalUnit -ErrorAction Stop

# Get the OU
if ($OU -eq '') {
    Do {
        $OU = Read-Host -Prompt "[+] Enter the name of the OU"
    } Until ($OU.Length -gt 0)
}

$OUs = Get-ADOrganizationalUnit -Filter "Name -Like `"$OU`"" -ErrorAction Stop

# Nothing matched the OU? Checking DistinguishedName
If (-Not ($OUs)) {
    $OUs = Get-ADOrganizationalUnit -Filter "DistinguishedName -Like `"$OU`"" -ErrorAction Stop
}

# Nothing matched the OU?
If (-Not ($OUs)) {
    Write-Host -ForegroundColor Red "[X] we didn't find any OUs matching `"$OU`", please verify the spelling."
    Exit
}

# If we reached this stage, this means the seearch resulted in "something"
# Results can be either a single object (for single matche),
# or an array of objects (if the pattern matches more than one OU in their domain)

If ($OUs -isnot [System.Array]) {
    # single match
    $ChosenOU = $OUs
}
else {
    Write-Host -ForegroundColor Yellow "[*] We found *more* than one OU that match the filter!"
    $chosenOUInt = 0
    Do {
        $i = 0
        Write-Host -ForegroundColor Yellow "[*] List of OUs that match '$OU':"
        foreach ($eachOU in $OUs) {
            Write-Host -ForegroundColor Yellow "    [$i] Name: $($eachOU.Name), DistinguishedName: $($eachOU.DistinguishedName)"
            $i += 1
        }
        $chosenOU = Read-Host -Prompt "[!] Please type the number corresponding to the OU you want to drop Canarytokens to (e.g. 0 or 1 or 2 ... etc.)"
        $chosenOUInt = $chosenOU -as [int]
    } Until (($chosenOUInt -lt $OUs.Count) -and ($chosenOUInt -ge 0))

    # they picked one
    $ChosenOU = $OUs[$chosenOUInt]
}

Write-Host -ForegroundColor Yellow "[*] The following OU has been picked:
OU Name = $($ChosenOU.Name)
OU DistinguishedName = $($ChosenOU.DistinguishedName)
"

# fetching list of computers...
Write-Host -ForegroundColor Green "[*] Getting list of computers under this OU..."
$Targets = Get-ADComputer -Filter * -SearchBase $($ChosenOU.DistinguishedName) -SearchScope 2 -ErrorAction Stop

# Not hosts under this OU?
If (-Not ($Targets)) {
    Write-Host -ForegroundColor Red "[X] We didn't find any Hosts under `"$($ChosenOU.Name)`", gonna have to bail out."
    Exit
}

# To simplify next code block, we want $Targets to be an array,
# even if there's only one match ... this should do the trick
$Targets = @() + $Targets


function DropTokens {
    param(
        # Array of targets
        [string[]]
        $TargetsToToken
    )
    # Last chance to verify parameters (and bail out)
    Write-Host -ForegroundColor Green "[*] Found a total number of '$($Targets.length)' targets:"
    ForEach ($Target in $Targets) {
        $TargetHostname = $Target.DNSHostName
        Write-Host -ForegroundColor Yellow "    - $TargetHostname"
    }
    Write-Host -ForegroundColor Yellow "[!] Please verify the list of hosts!"
    Do {
        $proceed = Read-Host -Prompt "[!] ARE YOU SURE YOU WANT TO PROCEED? [Y/N]"
        If ($proceed -eq "n") { Exit }
    } Until ($proceed -eq "y")

    # We should be good to go!
    ForEach ($Target in $Targets) {
        $TargetHostname = $Target.DNSHostName
        Write-Host -ForegroundColor Green "[*] Working with '$TargetHostname' ..."

        $NetworkPath = "\\$TargetHostname\C`$\$TargetDirectory"
        Write-Host -ForegroundColor Green "[*] Checking if '$NetworkPath' exists..."

        # Create the target Dir if not exist
        If (!(Test-Path $NetworkPath)) {
            Write-Host -ForegroundColor Green "[*] '$NetworkPath' doesn't exist, creating it ..."
            New-Item -ItemType Directory -Force -Verbose -Path "$NetworkPath"
            if (-not $?) {
                Write-Host -ForegroundColor Red "[X] Error Creating '$NetworkPath', skipping to next host"
                Continue
            }
        }
        # Check whether token already exists
        $OutputFileName = "$NetworkPath\$TokenFilename"
        Write-Host -ForegroundColor Green "[*] Dropping '$OutputFileName' ..."

        If (Test-Path $OutputFileName) {
            Write-Host -ForegroundColor Yellow "[!] Skipping $TargetHostname, file already exists."
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
            Write-Host -ForegroundColor Red "[X] Creation of $TokenName failed."
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

    Write-Host -ForegroundColor Green "`n[*] Done!"
}
DropTokens -TargetsToToken $Targets
