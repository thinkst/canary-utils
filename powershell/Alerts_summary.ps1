[string]$CANARYDOMAIN = $args[0] # Enter your Console domain between the . e.g. 1234abc.canary.tools
[string]$CANARYAPIKEY = $args[1] # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
[string]$DATE = $args[2] # Timestamp used to filter returned incidents in the format yyyy-mm-dd-hh:mm:ss. All incidents created after this timestamp will be returned. i.e. 2022-11-24-00:00:00  https://docs.canary.tools/incidents/queries.html#all-incidents

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

if($DATE) {
    Write-Host "`n [*] Date provided, summarizing alerts since $DATE"

    $Fetch_Alert_Summaries = Invoke-WebRequest -Uri "https://$CANARYDOMAIN.canary.tools/api/v1/incidents/all" -Method GET -Body @{auth_token=$CANARYAPIKEY; newer_than=$DATE} | ConvertFrom-Json | Select-Object -ExpandProperty incidents | Select-Object summary

    $Summary_Groups = $Fetch_Alert_Summaries | Group-Object -Property summary

    $Summary_Groups | Select-Object Name, Count
}
else {
    Write-Host "`n [*] Date not provided, summarizing all alerts"

    $Fetch_Alert_Summaries = Invoke-WebRequest -Uri "https://$CANARYDOMAIN.canary.tools/api/v1/incidents/all" -Method GET -Body @{auth_token=$CANARYAPIKEY} | ConvertFrom-Json | Select-Object -ExpandProperty incidents | Select-Object summary

    $Summary_Groups = $Fetch_Alert_Summaries | Group-Object -Property summary

    $Summary_Groups | Select-Object Name, Count
}