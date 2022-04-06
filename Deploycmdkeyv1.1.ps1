# Creates credential in "Windows credential manager"
# Revision 1.1
#Enter Birdname below.
Param (
[string]$Birdname = 'PUT_YOUR_CANARY_NAME_HERE'
)
#Imports Password Generation
Add-Type -AssemblyName System.Web
#Generates Random password. Edit last 2 numbers for password complexity. Length, Symbols
$Password=[System.Web.Security.Membership]::GeneratePassword(15,5)
cmdkey /generic:TERMSRV/$BIRDNAME /user:$env:username" /pass:$PASSWORD
Write-Output "Credential added to $env:COMPUTERNAME with $Password"