# Script to create Canary tokens for a list of hosts.
# We force TLS1.2 since our API doesn't support lower.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

# Connect to API
$ApiHost = [string]::Empty
Do {
    $ApiHost = Read-Host -Prompt "Enter your Canary API domain"
} Until (($ApiHost.Length -gt 0) -and ((Resolve-DnsName -DnsOnly -NoHostsFile -Name $ApiHost -Type A -ErrorAction SilentlyContinue)[0].IPAddress))
$ApiTokenSecure = New-Object System.Security.SecureString
Do {
    $ApiTokenSecure = Read-Host -AsSecureString -Prompt "Enter your Canary API key"
} Until ($ApiTokenSecure.Length -gt 0)
$ApiToken = (New-Object System.Management.Automation.PSCredential "user",$ApiTokenSecure).GetNetworkCredential().Password
$ApiBaseURL = '/api/v1'
$PingResult = Invoke-RestMethod -Method Get -Uri "https://$ApiHost$ApiBaseURL/ping?auth_token=$ApiToken"
$Result = $PingResult.result
If ($Result -ne 'success') {
    Write-Host "Cannot ping Canary API. Bad token?"
    Exit
} Else {
    Write-Host "Canary API available for service!"
}

$Targets = (
'HOST1',
'HOST2',
'HOST3')

ForEach ($TargetHostname in $Targets) {

    # Check whether token already exists
    $OutputFileName = "$TargetHostname-MSWORD.docx"
    If (Test-Path $OutputFileName) {
        Write-Host Skipping $TargetHostname, file already exists.
        Continue        
    }

    # Create token
    $TokenName = "$TargetHostname-MSWORD"
    $PostData = @{
        auth_token = "$ApiToken"
        kind = "doc-msword"
        memo = "$TokenName"
    }
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$ApiHost$ApiBaseURL/canarytoken/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host "Creation of $TokenName failed."
        Exit
    } Else {
        $WordTokenID = $($CreateResult).canarytoken.canarytoken
        Write-Host "$TokenName created (ID: $WordTokenID)."
    }

    # Download token
    Invoke-RestMethod -Method Get -Uri "https://$ApiHost$ApiBaseURL/canarytoken/download?auth_token=$ApiToken&canarytoken=$WordTokenID" -OutFile "$OutputFileName"
}
