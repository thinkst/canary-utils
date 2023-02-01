$Domain = '1234abc.canary.tools' # Enter your Console domain between the quotes. e.g. 1234abc.canary.tools
$FactoryAuth = 'a1bc3e769fg832hij3' # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
$FlockID = 'flock:default' # Enter desired flock to place tokens in. This is required. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors
$aws_FlockID = 'flock:default' # Enter desired flock to place tokens in.
$tokeneniseFile = "C:\ProgramData\template.txt" # This is location and filename of the template that will be downloaded and tokenised.
$pathToTemplateFile = 'https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx' # URL of your template, Private Repo's should follow the format of https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx,
$FindText = 'AKIASJ2WZMVFQGNWG4HA' # This string should be present in your template, and will then be updated with the newly created AWS API Key ID
$FindText2 = 'zXqAw2NlqNdha1IVCBNkIdv74AdfPw6MMb6xKBw5' # This string should be present in your template, and will then be updated with the newly created AWS API Key
$Personal_Access_Token = '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' # Personal access token generated on Github

# randomise the filename and folder drop path

$mainFolder = @('Application1','Application2','Application3')
$subFolder = @('Temp','Backup')
$randomCanaryToken = @('doc1.txt', 'doc2.txt')

$mainFolder = Get-Random -InputObject $mainFolder
$subFolder = Get-Random -InputObject $subFolder
$TokenFilename = Get-Random -InputObject $randomCanaryToken

$TargetDirectory = 'C:\ProgramData\' + $mainFolder + '\' + $subFolder
 
# We force TLS1.2 since our API doesn't support lower.
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

# Connect to API
# Get Console Domain
$ApiHost = [string]::Empty
if ($Domain -ne '') {
    $ApiHost = $Domain
} else {
    Do {
        $ApiHost = Read-Host -Prompt "[+] Enter your Full Canary domain (e.g. 'xyz.canary.tools')"
    } Until (($ApiHost.Length -gt 0) -and ([System.Net.Dns]::GetHostEntry($ApiHost).AddressList[0].IPAddressToString))
}

# Get Factory Auth String
$ApiToken = [string]::Empty
if ($FactoryAuth -ne '') {
    $ApiToken = $FactoryAuth
} else {
    $ApiTokenSecure = New-Object System.Security.SecureString
    Do {
        $ApiTokenSecure = Read-Host -AsSecureString -Prompt "[+] Enter your Canary Factory Auth key"
    } Until ($ApiTokenSecure.Length -gt 0)
    $ApiToken = (New-Object System.Management.Automation.PSCredential "user", $ApiTokenSecure).GetNetworkCredential().Password
}

$TokenType = 'aws-id'
Write-Host -ForegroundColor Green "[*] Starting Script with the following params:
        Console Domain   = $ApiHost
        Flock ID         = $aws_FlockID
        Token Type       = $TokenType
"

$ApiBaseURL = '/api/v1'

# Creates the target directory if it does not exist
If (!(Test-Path $TargetDirectory)) {
    Write-Host -ForegroundColor Green "[*] '$TargetDirectory' doesn't exist, creating it ..."
    New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory"
}
# Check whether token file already exists on the local machine
$OutputFileName = "$TargetDirectory\$TokenFilename"
Write-Host -ForegroundColor Green "[*] Dropping '$OutputFileName' ..."

If (Test-Path $OutputFileName) {
    Write-Host Skipping $OutputFileName, file already exists.
    Continue        
}

# Create token on Console
$TokenName = "Embedded AWS Token in $OutputFileName"
$PostData = @{
    factory_auth = "$ApiToken"
    kind       = "$TokenType"
    flock_id = "$aws_FlockID"
    memo       = "$([System.Net.Dns]::GetHostName()) | $TokenName"
}
Write-Host -ForegroundColor Green "[*] Hitting API to create token ..."
$CreateResult = Invoke-RestMethod -Method Post -Uri "https://$ApiHost$ApiBaseURL/canarytoken/factory/create" -Body $PostData
$Result = $CreateResult.result
If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Creation of $TokenName failed."
    Exit
}
Else {
    $TokenID = $($CreateResult).canarytoken.canarytoken
    Write-Host -ForegroundColor Green "[*] Token Created (ID: $TokenID)."
}

# Download the template here
iwr $pathToTemplateFile -Headers @{'Authorization' = "token $Personal_Access_Token"; 'Accept' = 'application/vnd.github.v3.raw'} -OutFile $OutputFileName

$ReplaceText = $CreateResult.canarytoken.access_key_id
$ReplaceText2 = $CreateResult.canarytoken.secret_access_key

#replace text in template file

$content = Get-Content -Path $OutputFileName

$replaceID = $content -replace $FindText, $ReplaceText
$replaceKey = $replaceID -replace $FindText2, $ReplaceText2

$replaceKey | Set-Content -Path $OutputFileName

# Set random MAC attributes 

$mainFolderPath = 'C:\ProgramData\' + $mainFolder
$subFolderPath = 'C:\ProgramData\' + $mainFolder + '\' + $subFolder

$dt1 = (Get-Date).AddDays(-(Get-Random -Minimum 1000 -Maximum 1500)).AddMinutes(-(Get-Random -Minimum 1 -Maximum 1440)) 
$dt2 = (Get-Date).AddDays(-(Get-Random -Minimum 700 -Maximum 999)).AddMinutes(-(Get-Random -Minimum 1 -Maximum 1440))
$dt3 = (Get-Date).AddDays(-(Get-Random -Minimum 400 -Maximum 699)).AddMinutes(-(Get-Random -Minimum 1 -Maximum 1440))
$dt4 = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 399)).AddMinutes(-(Get-Random -Minimum 1 -Maximum 1440))

$(Get-Item $mainFolderPath).CreationTimeUTC=$dt1 
$(Get-Item $mainFolderPath).LastAccessTimeUTC=$dt1
$(Get-Item $mainFolderPath).LastWriteTimeUTC=$dt1

$(Get-Item $subFolderPath).CreationTimeUTC=$dt2 
$(Get-Item $subFolderPath).LastAccessTimeUTC=$dt2
$(Get-Item $subFolderPath).LastWriteTimeUTC=$dt2

$(Get-Item $OutputFileName).CreationTimeUTC=$dt3
$(Get-Item $OutputFileName).LastAccessTimeUTC=$dt4
$(Get-Item $OutputFileName).LastWriteTimeUTC=$dt4 

Write-Host "Token Successfuly dropped to $OutputFileName"
