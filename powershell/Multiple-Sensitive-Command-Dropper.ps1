 # Multiple Sensitive Command Canarytoken Dropper
 Param (
    [string]$ConsoleDomain = 'CONSOLE_DOMAIN_HERE.canary.tools', #  Enter your Console domain  for example 1234abc.canary.tools
    [string]$FactoryAuth = 'FACTORY_AUTHSTRING_HERE', # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    )

####################################################################################################################################################################################################################################

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

####################################################################################################################################################################################################################################

# Drops Sensitive Command Token(s)
# Note : In order for the registry file to be imported, the script needs to be run as an Administrator
function Deploy-Token_Sensitive_command{
    # List of processes to alert on
    param (
        [string]$TokenType = 'sensitive-cmd',
        [string[]]$WatchedProcesses = @("mimikatz.exe" "netscan.exe", "adfind.exe", "speedtest.exe", "rclone.exe")
    )

    # Check for administrative privileges (required for registry keys
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        #Write-Host -ForegroundColor Red "[X] This script requires administrative privileges to run."
        Exit
    }
    
    foreach ($WatchedProcess in $WatchedProcesses) {
        $OutputFileName = "C:\Windows\Temp\sensitive_cmd_$($WatchedProcess).reg"
    
        # Check if the Token exists first
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$WatchedProcess"
        if ((Test-Path $registryPath)) {
            #Write-Host -ForegroundColor Green "[*] Token for: '$WatchedProcess' already exists, skipping..."
            continue
        }
    
        $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $PostData = @{
            factory_auth = "$FactoryAuth"
            kind         = "$TokenType"
            process_name = "$WatchedProcess"
            memo         = "hostname: $([System.Net.Dns]::GetHostName())|process: $WatchedProcess|created: $currentDateTime"
        }
    
        $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$ConsoleDomain/api/v1/canarytoken/factory/create" -Body $PostData
        $Result = $CreateResult.result
        If ($Result -ne 'success') {
            #Write-Host -ForegroundColor Red "[X] Creation of Canarytoken failed."
            continue
        }
        Else {
            $TokenID = $($CreateResult).canarytoken.canarytoken
        }
    
        Invoke-RestMethod -Method Get -Uri "https://$ConsoleDomain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
       
        Start-Process -FilePath "reg" -ArgumentList "import `"$OutputFileName`" /reg:32" -NoNewWindow -Wait
        Start-Process -FilePath "reg" -ArgumentList "import `"$OutputFileName`" /reg:64" -NoNewWindow -Wait
    
        Remove-Item $OutputFileName
         #Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
    }
}

Deploy-Token_Sensitive_command
#Write-Host -ForegroundColor Green "[*] Multiple Sensitive Command Token Dropper Complete"
Exit 0 
