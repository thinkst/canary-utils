# This script grabs word documents and Tokens them.
# Edit all lines in the below section to match your requirements.

Param (
    [string]$Domain = 'ABC123.canary.tools', # Enter your Console domain between the . e.g. 1234abc.canary.tools
    [string]$FactoryAuth = 'DEF456', # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    [string]$intro = 'ON' # [ON | OFF] Prints ASCII Art Intro.
    )

# Token details
$TokenFilename = "secrets.docx" # Desired Token file name.
$TargetDirectory = "C:\Users\admin\Desktop" # Local location to drop the token into, please exclude the last slash "\""

# List of accessible template word documents
$TokenTemplates = @(
    "https://github.com/USER/REPO/raw/main/template_1.docx",
    "https://myfilehost.example/template_2.docx",
    "https://cdn.create.microsoft.com/catalog-assets/en-us/2228e0d1-b139-4b3c-89ef-4892b23b5e90/tf34003419_wac-68ef7751e2bf.docx" # please exclude a comma from the last entry
)

####################################################################################################################################################################################################################################

# Enforce TLS 1.2
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

# Select a random template from the list
$TemplateFile = $TokenTemplates | Get-Random

# Extract the file name from the full path
$TemplateFileName = [System.IO.Path]::GetFileName($TemplateFile)

Write-Host -ForegroundColor Green "[*] Working with Templatefile: $TemplateFileName"

# Grab Host network details based on default route
$defaultRoute = (Get-NetRoute | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' })
$interfaceIndex = $defaultRoute.InterfaceIndex
$MAC = (Get-NetAdapter | Where-Object { $_.IfIndex -eq $interfaceIndex }).MacAddress
$IP = (Get-NetIPAddress | Where-Object { $_.InterfaceIndex -eq $interfaceIndex -and $_.AddressFamily -eq 'IPv4' }).IPAddress
$HOSTNAME = $env:COMPUTERNAME

# Build Token target path
$OutputFileName = "$TargetDirectory\$TokenFilename"

# Check if Token already exists
If ((Test-Path $OutputFileName)) {
    Write-Host -ForegroundColor Yellow "[*] '$OutputFileName' exists, skipping..."
    exit 1
}

# Create directory if it doesn't exist
If (!(Test-Path $TargetDirectory)) {
    New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory" > $null
}

# Download the template file
Invoke-WebRequest -Uri $TemplateFile -OutFile "$TargetDirectory\$TemplateFileName"

# Creating the Token on Console

# Encode template file
$encodedFile = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString([System.IO.File]::ReadAllBytes("$TargetDirectory\$TemplateFileName"))

$httpBoundary = [System.Guid]::NewGuid().ToString() 

# Build HTTP multipart/form-data
$requestBody = @"
--$httpBoundary
Content-Disposition: form-data; name="factory_auth"

$FactoryAuth
--$httpBoundary
Content-Disposition: form-data; name="memo"

$HOSTNAME - $OutputFileName - $MAC - $IP
--$httpBoundary
Content-Disposition: form-data; name="kind"

doc-msword
--$httpBoundary
Content-Disposition: form-data; name ="doc"; filename ="$TemplateFileName"
Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document

$encodedFile

--$httpBoundary--
"@

# Submit request to Console API
$CreateTokenResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $requestBody -ContentType "multipart/form-data; boundary=$httpBoundary;"

# Check creation result from API.
$Result = $CreateTokenResult.result
If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Creation of $TokenFilename failed."
    exit 1
}
Else {
    $TokenID = $($CreateTokenResult).canarytoken.canarytoken
    Write-Host -ForegroundColor Green "[*] Token Created (ID: $TokenID)."
}

# Clean up template file
Remove-Item -Force "$TargetDirectory\$TemplateFileName"

# Download Token
Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"

Write-Host -ForegroundColor Green "[*] Token Script for: '$OutputFileName'. Complete on $env:computername" 
