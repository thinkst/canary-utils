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

curl.exe -s https://$ApiHost$ApiBaseURL/flocks/summary `
    -d auth_token=$ApiToken `
    -G | convertfrom-json | convertto-json -depth 100 
