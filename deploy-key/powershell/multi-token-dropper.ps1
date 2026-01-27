#Canary Token Multi-Dropper
Param (
    [string]$Domain = '.canary.tools',     # Your Console domain, for example 1234abc.canary.tools
    [string]$CanarytokenDeployKey = '',    # Canarytoken Deploy Key (Flock API key)
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
        [string]$TokenType = 'aws-id' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }

    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_AWS

####################################################################################################################################################################################################################################

# Drops an Azure API Token
function Deploy-Token_Azure{
    param (
        [string]$TokenType = 'azure-id' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
        [string]$TokenFilename = 'azure_prod', # Desired Token file name.
        [string]$TargetDirectory = "c:\azure_token" # Local location to drop the token into.
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
        kind       = "$TokenType"
        azure_id_cert_file_name = "$TokenFilename"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"

    Expand-Archive $OutputFileName -DestinationPath $TargetDirectory
    Remove-Item $OutputFileName

    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName' complete on $env:computername"
}

Deploy-Token_Azure

####################################################################################################################################################################################################################################

# Drops a DNS Token as a batch script.
function Deploy-Token_DNS{
    param (
        [string]$TokenType = 'dns', # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
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
        [string]$TokenType = 'doc-msexcel' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Excel

####################################################################################################################################################################################################################################

#Drops an Excel-Macro Token
function Deploy-Token_Excel_Macro{
    param (
        [string]$TokenType = 'msexcel-macro' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Excel_Macro

####################################################################################################################################################################################################################################

# Drops a Windows Folder Token
function Deploy-Token_Folder{
    param (
        [string]$TokenType = 'windows-dir', # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
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

    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$TargetDirectory\$TempZipFilename"
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
        [string]$TokenType = 'pdf-acrobat-reader' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_PDF

####################################################################################################################################################################################################################################

#Drops a QR-Code Token
function Deploy-Token_QR{
    param (
        [string]$TokenType = 'qr-code' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_QR

####################################################################################################################################################################################################################################

# Drops a sensitive command Token
# Note : In order for the registry file to be imported, the script needs to be run as an Administrator
function Deploy-Token_Sensitive_command{
    param (
        [string]$TokenType = 'sensitive-cmd' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
        [string]$WatchedProcess = "calc.exe" # Process you'd like to alert on
    )
    
     $OutputFileName = "C:\Windows\Temp\sensitive_cmd.reg"
    
    # Check if the Token exists first
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$WatchedProcess"
    if ((Test-Path $registryPath)) {
        Write-Host -ForegroundColor Green "[*] Token for: '$WatchedProcess' already exists, skipping..."
        return
    }
    
    $PostData = @{
        kind       = "$TokenType"
        process_name = "$WatchedProcess"
        memo       = "$([System.Net.Dns]::GetHostName()) - $WatchedProcess"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"

    reg import $OutputFileName /reg:32
    reg import $OutputFileName /reg:64
    
    Remove-Item $OutputFileName
}

Deploy-Token_Sensitive_command

####################################################################################################################################################################################################################################

# Tokens an executable.
function Deploy-Token_Signed_EXE{
    param (
        [string]$TokenTemplate = "C:\Users\Administrator\Downloads\cports.exe", # Path to the executable you'd like to Token.
        [string]$TargetDirectory = "c:\exe_directory" # Local location to drop the token into. (The executable will keep it's name.)
    )

    $ExecutableName = Split-Path $TokenTemplate -Leaf

    $OutputFileName = "$TargetDirectory\$ExecutableName"

    If ((Test-Path $OutputFileName)) {
        Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
        return
    }

    If (!(Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
    }
    
    $formData = @{
    kind = "signed-exe"
    memo = "$([System.Net.Dns]::GetHostName()) - $OutputFileName"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }

    $fileContent = [System.IO.File]::ReadAllBytes($TokenTemplate)
    $fileName = [System.IO.Path]::GetFileName($TokenTemplate)

    $boundary = [System.Guid]::NewGuid().ToString()

    $body = ""

    foreach ($key in $formData.Keys) {
        $body += "--$boundary`r`n"
        $body += "Content-Disposition: form-data; name=`"$key`"`r`n`r`n"
        $body += "$($formData[$key])`r`n"
    }

    $body += "--$boundary`r`n"
    $body += "Content-Disposition: form-data; name=`"exe`"; filename=`"$fileName`"`r`n"
    $body += "Content-Type: application/x-msdownload`r`n`r`n"
    $body += [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileContent) + "`r`n"
    $body += "--$boundary--`r`n"

    $bodyBytes = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetBytes($body)

    $headers = @{
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    $response = Invoke-RestMethod -Uri "https://$Domain/api/v1/canarytoken/create" -Method Post -Headers $headers -Body $bodyBytes

    $TokenID = $response.canarytoken.canarytoken

    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"

    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}
# Disabled unless required, simply uncomment the the below line to deploy the Token.
#Deploy-Token_Signed_EXE

####################################################################################################################################################################################################################################

# Drops a Web Bug as a Shortcut.
function Deploy-Token_Web{
    param (
        [string]$TokenType = 'http', # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
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
        [string]$TokenType = 'doc-msword' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Word

####################################################################################################################################################################################################################################

#Drops a Word Macro Token
function Deploy-Token_Word_Macro{
    param (
        [string]$TokenType = 'doc-msword' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_Word_Macro

####################################################################################################################################################################################################################################

#Drops a MySQL Dump Token
#Function to expand GZ on Windows

function Expand-GZipFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,

        [Parameter(Mandatory = $false)]
        [string]$DestinationFile
    )

    if (-not $DestinationFile) {
        $DestinationFile = [System.IO.Path]::ChangeExtension($SourceFile, $null)
    }

    if (-not (Test-Path $SourceFile)) {
        Write-Host -ForegroundColor Red "[X] Source file not found, $SourceFile"
        return
    }

    try {
        $input = [System.IO.File]::OpenRead($SourceFile)
        $gzip = New-Object System.IO.Compression.GzipStream(
            $input,
            [System.IO.Compression.CompressionMode]::Decompress
        )
        $output = [System.IO.File]::Create($DestinationFile)

        $gzip.CopyTo($output)

        $gzip.Dispose()
        $output.Dispose()
        $input.Dispose()

        Write-Host -ForegroundColor Green "[*] Extracted ${SourceFile} to $DestinationFile"

        # Delete the original .gz file after successful extraction
        Remove-Item -Path $SourceFile -Force
        Write-Host -ForegroundColor Yellow "[*] Removed compressed file: $SourceFile"
    }
    catch {
        Write-Host -ForegroundColor Red "[X] Extraction failed for ${SourceFile}: $($_.Exception.Message)"
    }
}

#Function to deploy MySQL Dump Token
function Deploy-MySQL_Dump {
    param (
        [string]$TokenType = 'mysql-dump',
        [string]$TokenFilename = "prod-db-dump.sql.gz",
        [string]$TargetDirectory = "C:\db-backup\"
    )

    $OutputFileName = Join-Path $TargetDirectory $TokenFilename

    if (-not (Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -ErrorAction Stop -Path $TargetDirectory > $null
    }

    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Yellow "[*] File already exists, $OutputFileName"
    }
    else {
        $PostData = @{
            kind         = "$TokenType"
            memo         = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
            industry     = "corporate"
        }
        $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
        }

        try {
            $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
        }
        catch {
            Write-Host -ForegroundColor Red "[X] Token creation request failed: $($_.Exception.Message)"
            return
        }

        $Result = $CreateResult.result
        if ($Result -ne 'success') {
            Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed"
            return
        }

        $TokenID = $CreateResult.canarytoken.canarytoken

        try {
            Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile $OutputFileName
            Write-Host -ForegroundColor Green "[*] Token downloaded to: $OutputFileName"
        }
        catch {
            Write-Host -ForegroundColor Red "[X] Download failed: $($_.Exception.Message)"
            return
        }
    }

    # Extract and remove gz file
    Expand-GZipFile -SourceFile $OutputFileName

    Write-Host -ForegroundColor Green "[*] Token script complete on $env:COMPUTERNAME"
}

####################################################################################################################################################################################################################################

#Drops a WireGuard Config file Token
function Deploy-Token_WireGuard{
    param (
        [string]$TokenType = 'wireguard' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/actions.html#list-kinds-of-canarytokens
        [string]$TokenFilename = "wg0-prod.conf", # Desired Token file name.
        [string]$TargetDirectory = "c:\wireguard-config_directory" # Local location to drop the token into.
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
        kind       = "$TokenType"
        memo       = "$([System.Net.Dns]::GetHostName()) - $env:USERNAME - $TargetDirectory"
    }
    $Header = @{
        "X-Canary-Auth-Token" = "$CanarytokenDeployKey"
    }
    
    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData -Headers $Header
    $Result = $CreateResult.result
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/download?auth_token=$CanarytokenDeployKey&canarytoken=$TokenID" -OutFile "$OutputFileName"
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Deploy-Token_WireGuard

Write-Host -ForegroundColor Green "[*] Multi-Token dropper Complete"
Exit 0
