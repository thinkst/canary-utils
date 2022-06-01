#Canary Token Multi-Dropper
Param (
    [string]$Domain = 'ABC123.canary.tools', # Enter your Console domain between the . e.g. 1234abc.canary.tools
    [string]$FactoryAuth = 'ABC123', # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    [string]$FlockID = 'flock:default', # Enter desired flock to place tokens in. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors
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

#Drops a Windows Folder Token
function Drop-Token_Folder{
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
        flock_id = "$FlockID"
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
    
    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$TargetDirectory\$TempZipFilename"
    Expand-Archive $TargetDirectory\$TempZipFilename -DestinationPath $TargetDirectory\
    Remove-item $TargetDirectory\$TempZipFilename
    Rename-Item "$TargetDirectory\My Documents" "$TargetDirectory\$TargetFolderName"
    $attrib = Get-ChildItem $TargetDirectory\ -Recurse | foreach{$_.Attributes = 'System'}
    
    Write-Host -ForegroundColor Green "[*] Token Script for: '$TargetDirectory\$TargetFolderName'. Complete on $env:computername"
}

Drop-Token_Folder

####################################################################################################################################################################################################################################

#Drops an AWS API Token
function Drop-Token_AWS{
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
        flock_id = "$FlockID"
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

Drop-Token_AWS

####################################################################################################################################################################################################################################

#Drops a Word Token
function Drop-Token_Word{
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
        flock_id = "$FlockID"
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

Drop-Token_Word

####################################################################################################################################################################################################################################

#Drops a Word Macro Token
function Drop-Token_Word_Macro{
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
        flock_id = "$FlockID"
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

Drop-Token_Word_Macro

####################################################################################################################################################################################################################################

#Drops an Excel Token
function Drop-Token_Excel{
    param (
        [string]$TokenType = 'doc-msexcel' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename = "excel.xls", # Desired Token file name.
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
        flock_id = "$FlockID"
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

Drop-Token_Excel

####################################################################################################################################################################################################################################

#Drops an Excel-Macro Token
function Drop-Token_Macro{
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
        flock_id = "$FlockID"
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

Drop-Token_Macro

####################################################################################################################################################################################################################################

#Drops a PDF Token
function Drop-Token_PDF{
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
        flock_id = "$FlockID"
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

Drop-Token_PDF

####################################################################################################################################################################################################################################

#Drops a QR-Code Token
function Drop-Token_QR{
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
        flock_id = "$FlockID"
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

Drop-Token_QR

####################################################################################################################################################################################################################################

Write-Host -ForegroundColor Green "[*] Multi-Token dropper Complete"
