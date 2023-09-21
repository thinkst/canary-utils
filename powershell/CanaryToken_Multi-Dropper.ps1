#Canary Token Multi-Dropper
Param (
    [string]$Domain = 'ABC123.canary.tools', # Enter your Console domain between the . e.g. 1234abc.canary.tools
    [string]$FactoryAuth = 'ABC123', # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    [string]$intro = 'ON'
    )

####################################################################################################################################################################################################################################

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

#PRINT MINYONI INTRO

if ($intro -eq 'ON') {
    Write-Host -ForegroundColor Green "         _______________"
    Write-Host -ForegroundColor Green "        |HAPPY TOKENING!|"
    Write-Host -ForegroundColor Green "        |___________   /"
    Write-Host -ForegroundColor Green "           ....    / /"
    Write-Host -ForegroundColor Green "         / ^  ^ \ //"
    Write-Host -ForegroundColor Green "        (   \/   )"
    Write-Host -ForegroundColor Green "         )      ("
    Write-Host -ForegroundColor Green "       (          )"
    Write-Host -ForegroundColor Green "      (            )"
    Write-Host -ForegroundColor Green "       (          )"
    Write-Host -ForegroundColor Green "        [        ]"
    Write-Host -ForegroundColor Green "       --/\ --- /\-----"
    Write-Host -ForegroundColor Green "      ---------------"
    Write-Host -ForegroundColor Green "        /   /"
    Write-Host -ForegroundColor Green "       /___/"
}
else {
    Write-Host -ForegroundColor Yellow "[X] Skipping Intro..."
}

####################################################################################################################################################################################################################################

#Drops an AWS API Token
function Deploy-Token_AWS{
    param (
        [string]$TokenType = 'aws-id' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "aws-keys.txt", # Desired Token file name.
        [string]$TargetDirectory = "c:\aws_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_AWS

####################################################################################################################################################################################################################################

# Drops an Azure API Token
function Deploy-Token_Azure{
    param (
        [string]$TokenType = 'azure-id' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = 'azure_prod', # Desired Token file name.
        [string]$TargetDirectory = "c:\operate\thinkst" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename.zip"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        azure_id_cert_file_name = "$TokenFilename"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"

    Expand-Archive $OutputFileName -DestinationPath $TargetDirectory
    Remove-Item $OutputFileName

    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName' complete on $env:computername"
}

Deploy-Token_Azure

####################################################################################################################################################################################################################################

# Drops a DNS Token as a batch script.
function Deploy-Token_DNS{
    param (
        [string]$TokenType = 'dns', # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "runme.bat", # Desired Token file name.
        [string]$TargetDirectory = "c:\dns_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $Tokenhostname = $($CreateResult).canarytoken.hostname
    }
    
    $Scriptcontents = "@echo off`nnslookup $Tokenhostname`npause"

    Set-Content -Path $OutputFileName -Value $Scriptcontents
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_DNS

####################################################################################################################################################################################################################################

#Drops an Excel Token
function Deploy-Token_Excel{
    param (
        [string]$TokenType = 'doc-msexcel' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "excel.xlsx", # Desired Token file name.
        [string]$TargetDirectory = "c:\excel_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Excel

####################################################################################################################################################################################################################################

#Drops an Excel-Macro Token
function Deploy-Token_Excel_Macro{
    param (
        [string]$TokenType = 'msexcel-macro' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "excel-macro.xlsm", # Desired Token file name.
        [string]$TargetDirectory = "c:\excel_macro_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Excel_Macro

####################################################################################################################################################################################################################################

# Drops a Windows Folder Token
function Deploy-Token_Folder{
    param (
        [string]$TokenType = 'windows-dir', # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TargetFolderName = "Folder_Token", # Desired Token Folder name.
        [string]$TargetDirectory = "c:\folder_directory", # Local location to drop the token into.
        [string]$TempZipFilename = "token-folder.zip" 
    )

    $OutputFileName = "$TargetDirectory\$TargetFolderName"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }

#   If the Token does not trigger, this may be due to EnableShellShortcutIconRemotePath being disabled, uncommenting the below section will try set the registry key. This means the script needs be run as administrator.
#    try {
#        Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "EnableShellShortcutIconRemotePath" -ErrorAction Stop
#    }
#    catch [System.Management.Automation.ItemNotFoundException] {
#        Write-Host -ForegroundColor Green "[*] Registry Key: EnableShellShortcutIconRemotePath, not set. Configuring...."
#        
#        try {
#            New-Item –Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\" –Name Explorer -ErrorAction Stop
#            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'EnableShellShortcutIconRemotePath' -Value 1 -Type DWord -Force
#        }
#        catch [System.Security.SecurityException] {
#        Write-Host -ForegroundColor Green "[!] Error: Cannot set registry key, Are we running as administrator?"
#        Write-Host -ForegroundColor Green "[*] Deploying Token Anyway..."
#        }
#    }

    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$TargetDirectory\$TempZipFilename"
    Expand-Archive $TargetDirectory\$TempZipFilename -DestinationPath $TargetDirectory\
    Remove-item $TargetDirectory\$TempZipFilename
    Rename-Item "$TargetDirectory\My Documents" "$TargetDirectory\$TargetFolderName"
    $attrib = Get-ChildItem $TargetDirectory\ -Recurse | foreach{$_.Attributes = 'System'}
    
    Write-Host -ForegroundColor Green "[*] Token Script for: '$TargetDirectory\$TargetFolderName'. Complete on $env:computername"
}

Deploy-Token_Folder

####################################################################################################################################################################################################################################

#Drops a PDF Token
function Deploy-Token_PDF{
    param (
        [string]$TokenType = 'pdf-acrobat-reader' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "PDF_Doc.pdf", # Desired Token file name.
        [string]$TargetDirectory = "c:\pdf_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_PDF

####################################################################################################################################################################################################################################

#Drops a QR-Code Token
function Deploy-Token_QR{
    param (
        [string]$TokenType = 'qr-code' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "QR_Code.png", # Desired Token file name.
        [string]$TargetDirectory = "c:\QR_Code_directory" # Local location to drop the token into.
    )
    
    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }
    
    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_QR

####################################################################################################################################################################################################################################

# Drops a sensitive command Token
# Note : In order for the registry file to be imported, the script needs to be run as an Administrator
function Deploy-Token_Sensitive_command{
    param (
        [string]$TokenType = 'sensitive-cmd' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "sensitive_cmd.reg", # Desired Token file name.
        [string]$TargetDirectory = "c:\Sensitive_command_directory", # Local location to drop the token into.
        [string]$WatchedProcess = "calc.exe" # Process you'd like to alert on
    )
    
    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }
    
    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        process_name = "$WatchedProcess"
        memo       = "$([System.Net.Dns]::GetHostName()) - $WatchedProcess"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"

    Start-Process reg -ArgumentList "import $OutputFileName /reg:32"
    Start-Process reg -ArgumentList "import $OutputFileName /reg:64"
    Remove-Item $OutputFileName
    Remove-Item $TargetDirectory 
}

Deploy-Token_Sensitive_command

####################################################################################################################################################################################################################################

# Drops a Web Bug as a Shortcut.
function Deploy-Token_Web{
    param (
        [string]$TokenType = 'http', # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "example.com.url", # Desired Token file name.
        [string]$TargetDirectory = "c:\web_bug_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenURL = $($CreateResult).canarytoken.url
    }
    
    $wshshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshshell.CreateShortcut($OutputFileName)
    $shortcut.TargetPath = $TokenURL
    $shortcut.Save()

    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Web

####################################################################################################################################################################################################################################

# Drops a Word Token
function Deploy-Token_Word{
    param (
        [string]$TokenType = 'doc-msword' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "secrets.docx", # Desired Token file name.
        [string]$TargetDirectory = "c:\word_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Word

####################################################################################################################################################################################################################################

#Drops a Word Macro Token
function Deploy-Token_Word_Macro{
    param (
        [string]$TokenType = 'doc-msword' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "secrets.docm", # Desired Token file name.
        [string]$TargetDirectory = "c:\word_macro_directory" # Local location to drop the token into.
    )

    $OutputFileName = "$TargetDirectory\$TokenFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Word_Macro

####################################################################################################################################################################################################################################

# Create RDP Shortcut pointing towards a Canary
# Note : this should be accessible from your Tokened Host.

function Deploy-RDP_Shortcut{
    param (
        [string]$CanaryIP = '192.168.1.1' , # Enter your Canaries IP Address.
        [string]$ShortcutFilename = "SRV01.lnk", # Enter your preferred shortcut name, usually your Canaries Hostname.
        [string]$TargetDirectory = "c:\RDP_Shortcut_directory", # Local location to drop the shortcut into.
        [string]$RDPPass = "Rn55ae5$$A!" # Enter your preferred password
    )
    
    $OutputFileName = "$TargetDirectory\$ShortcutFilename"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }
    
    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }

    cmdkey /generic:$CanaryIP /user:$env:UserName /pass:$RDPPass
    
    $wshshell = New-Object -ComObject WScript.Shell
    $lnk = $wshshell.CreateShortcut($OutputFileName)
    $lnk.TargetPath = "%windir%\system32\mstsc.exe"
    $lnk.Arguments = "/v:$CanaryIP"
    $lnk.Description = "RDP"
    $lnk.Save()
}

Deploy-RDP_Shortcut

# Adding generic creds to cmdkey
# Reference : https://blog.thinkst.com/2021/06/rdp-cmdkey-canary-and-thee_10.html

cmdkey /add:02-FINANCE-02 /user:administrator /pass:super-secret123

####################################################################################################################################################################################################################################

Write-Host -ForegroundColor Green "[*] Multi-Token dropper Complete"
