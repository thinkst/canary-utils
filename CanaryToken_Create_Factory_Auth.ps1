Param (
    [string]$Domain = 'xxxx.canary.tools', # Enter your Console domain between the "" e.g. 1234abc.canary.tools
    [string]$APIKEY = 'abc' # Enter your Console API Key e.g. abc123def456ghi789 Docs can be found here. https://help.canary.tools/hc/en-gb/articles/360012727537-How-does-the-API-work-
)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

$PostData = @{
    auth_token = "$APIKEY"
    memo       = "$([System.Net.Dns]::GetHostName()) - Factory Auth Key"
}

$CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create_factory" -Body $PostData
$Result = $CreateResult.result
$Authkey = $CreateResult.factory_auth
If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Creation of Factory Auth Key failed."
    Exit
}
Else {
    Write-Host -ForegroundColor Green "Successfuly created Factory Auth Key: $Authkey"
}

Write-Host -ForegroundColor Green "[*] Factory Token Creation Script Complete."  