#Canary Token Multi-Dropper
Param (
    [string]$Domain = 'xxxx.canary.tools', # Enter your Console domain between the . e.g. 1234abc.canary.tools
    [string]$FactoryAuth = 'xxxx', # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    [string]$FlockID = 'flock:default' # Enter desired flock to place tokens in. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors
    )

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

#Drops a Windows Folder Token
function Drop-Token_Folder{
    param (
        [string]$TokenType_Folder = 'windows-dir', # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename_Folder = "token-folder.zip", # Desired Token file name.
        [string]$TargetDirectory_Folder = "c:\folder_directory" # Local location to drop the token into.
    )
    If (!(Test-Path $TargetDirectory_Folder)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory_Folder"
    }
    
    $OutputFileName = "$TargetDirectory_Folder\$TokenFilename_Folder"
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType_Folder"
        flock_id = "$FlockID"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory_Folder"
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
    Expand-Archive $TargetDirectory_Folder\$TokenFilename_Folder -DestinationPath $TargetDirectory_Folder\
    Remove-item $TargetDirectory_Folder\$TokenFilename_Folder
    $attrib = Get-ChildItem $TargetDirectory_Folder\ -Recurse | foreach{$_.Attributes = 'System'}
    
    Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername"
}

Drop-Token_Folder
Write-Host -ForegroundColor Green "[*] Folder Token Dropped"

#Drops an AWS API Token
function Drop-Token_AWS{
    param (
        [string]$TokenType_AWS = 'aws-id' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename_AWS = "aws-keys.txt", # Desired Token file name.
        [string]$TargetDirectory_AWS = "c:\aws_directory" # Local location to drop the token into.
    )
    If (!(Test-Path $TargetDirectory_AWS)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory_AWS"
    }
    
    $OutputFileName = "$TargetDirectory_AWS\$TokenFilename_AWS"
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType_AWS"
        flock_id = "$FlockID"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory_AWS"
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
Write-Host -ForegroundColor Green "[*] AWS Token Dropped"

#Drops a Word Token
function Drop-Token_Word{
    param (
        [string]$TokenType_Word = 'doc-msword' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename_Word = "secrets.doc", # Desired Token file name.
        [string]$TargetDirectory_Word = "c:\word_directory" # Local location to drop the token into.
    )
    If (!(Test-Path $TargetDirectory_Word)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory_Word"
    }
    
    $OutputFileName = "$TargetDirectory_Word\$TokenFilename_Word"
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType_Word"
        flock_id = "$FlockID"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory_Word"
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
Write-Host -ForegroundColor Green "[*] Word Token Dropped"

#Drops a Word Macro Token
function Drop-Token_Word-Macro{
    param (
        [string]$TokenType_Word_Macro = 'doc-msword' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename_Word_Macro = "secrets.docm", # Desired Token file name.
        [string]$TargetDirectory_Word_Macro = "c:\word_macro_directory" # Local location to drop the token into.
    )
    If (!(Test-Path $TargetDirectory_Word_Macro)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory_Word_Macro"
    }
    
    $OutputFileName = "$TargetDirectory_Word_Macro\$TokenFilename_Word_Macro"
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType_Word_Macro"
        flock_id = "$FlockID"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory_Word_Macro"
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

Drop-Token_Word-Macro
Write-Host -ForegroundColor Green "[*] Word-Macro Token Dropped"

#Drops an Excel-Macro Token
function Drop-Token_Excel-Macro{
    param (
        [string]$TokenType_Excel = 'msexcel-macro' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename_Excel = "excel-macro.xlsm", # Desired Token file name.
        [string]$TargetDirectory_Excel = "c:\excel_directory" # Local location to drop the token into.
    )
    If (!(Test-Path $TargetDirectory_Excel)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory_Excel"
    }
    
    $OutputFileName = "$TargetDirectory_Excel\$TokenFilename_Excel"
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType_Excel"
        flock_id = "$FlockID"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory_Excel"
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

Drop-Token_Excel-Macro
Write-Host -ForegroundColor Green "[*] Excel-Macro Token Dropped"

#Drops a PDF Token
function Drop-Token_PDF{
    param (
        [string]$TokenType_PDF = 'pdf-acrobat-reader' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename_PDF = "PDF_Doc.pdf", # Desired Token file name.
        [string]$TargetDirectory_PDF = "c:\pdf_directory" # Local location to drop the token into.
    )
    If (!(Test-Path $TargetDirectory_PDF)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory_PDF"
    }
    
    $OutputFileName = "$TargetDirectory_PDF\$TokenFilename_PDF"
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType_PDF"
        flock_id = "$FlockID"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory_PDF"
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
Write-Host -ForegroundColor Green "[*] PDF Token Dropped"

#Drops a QR-Code Token
function Drop-Token_QR-Code{
    param (
        [string]$TokenType_QR = 'qr-code' , # Enter your required token type. Full list available here. https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
        [string]$TokenFilename_QR = "QR_Code.png", # Desired Token file name.
        [string]$TargetDirectory_QR = "c:\QR_Code_directory" # Local location to drop the token into.
    )
    If (!(Test-Path $TargetDirectory_QR)) {
        New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory_QR"
    }
    
    $OutputFileName = "$TargetDirectory_QR\$TokenFilename_QR"
    
    $PostData = @{
        factory_auth = "$FactoryAuth"
        kind       = "$TokenType_QR"
        flock_id = "$FlockID"
        memo       = "$([System.Net.Dns]::GetHostName()) - $TargetDirectory_QR"
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

Drop-Token_QR-Code
Write-Host -ForegroundColor Green "[*] QR-Code Token Dropped"

Write-Host -ForegroundColor Green "[*] Multi-token dropper Complete"