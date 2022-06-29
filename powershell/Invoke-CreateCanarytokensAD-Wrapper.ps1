<#
.SYNOPSIS
    Wraps the `Invoke-CreateCanarytokensAD.ps1` script which is called for all OU
    entries in `-OUFilename` file.

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
    4. Type the path of the OUFilename

    Last Edit: 2021-01-25
    Version 1.0 - initial release

.EXAMPLE
    .\Invoke-CreateCanarytokensAD-Wrapper.ps1 -OUFilename "/Full/Path/TO/List of OUs.csv"  -TargetDirectory secret -TokenType aws-id -TokenFilename aws_secret.txt
    creates an AWS-ID Canarytoken, using aws_secret.txt as the filename, and place it under c:\secret
    for all Computers in all OUs listed in `-OUFilename`.
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

    # Name of the file containing OU's. One OU per line.
    # eg: TEST.COM\TEST\NESTED\OUNAMES\Users
    # Each computer in this OU will have a token dropped to it.
    # The user that invoked the script should be able to map and write to admin shares
    # on those hosts.
    # if empty, will be asked for interactively
    [string]$OUFilename = ''
)
Get-Content $OUFilename | ForEach-Object {
    Write-Output "Running Invoke-CreateCanarytokensAD.ps1 with -OU $_"
    & "$PSScriptRoot\Invoke-CreateCanarytokensAD.ps1" -OU $_ -TargetDirectory $TargetDirectory -TokenFilename $TokenFilename -TokenType $TokenType -Domain $Domain -ApiAuth $ApiAuth
}