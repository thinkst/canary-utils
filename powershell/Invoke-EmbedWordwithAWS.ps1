# This script will download a sample docx from a private github repo,
# find text within the document, and replace with an AWS API key token.
# The original document will also be tokenised.
# The result is a stacked-token (word token embedded with aws token) deployed into a randomised folder path and file name

$Domain = '1234abc.canary.tools' # Enter your Console domain between the quotes. e.g. 1234abc.canary.tools
$FactoryAuth = 'a1bc3e769fg832hij3' # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
#$FlockID = 'flock:default' # Enter desired flock to place tokens in. This mis required. Docs available here. https://docs.canary.tools/flocks/queries.html#list-flock-sensors
$aws_FlockID = 'flock:default' # Enter desired flock to place tokens in.
$word_FlockID = 'flock:default' # Enter desired flock to place tokens in.
$tokeneniseFile = 'C:\ProgramData\template.docx' # This is location and filename of the template that will be downloaded and tokenised.
$pathToTemplateFile = 'https://api.github.com/repos/repo_owner/private_repo_name/contents/sample.docx' # This is where the word template is hosted
$FindText = "AKIASJ2WZMVFQGNWG4HA" # This string should be present in your template, and will then be updated with the newly created AWS API Key ID
$FindText2 = "zXqAw2NlqNdha1IVCBNkIdv74AdfPw6MMb6xKBw5" # This string should be present in your template, and will then be updated with the newly created AWS API Key
$Personal_Access_Token = "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" # Personal access token generated on Github

# randomise the filename and folder drop path

$mainFolder = @('Application1','Application2','Application3')
$subFolder = @('Temp','Backup')
$randomCanaryToken = @('doc1.docx', 'doc2.docx')

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

# Get API Auth Token
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
#$TokenName = $OutputFileName
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

# Download the word template here
iwr $pathToTemplateFile -Headers @{'Authorization' = "token $Personal_Access_Token"; 'Accept' = 'application/vnd.github.v3.raw'} -OutFile $tokeneniseFile

# Create token on Console
$TokenName = $OutputFileName
$contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
$httpBoundary = [guid]::NewGuid().ToString()
$tokeneniseFileName = Split-Path $tokeneniseFile -Leaf
$tokeneniseFileBin = [System.IO.File]::ReadAllBytes($tokeneniseFile)
$encodingScheme = [System.Text.Encoding]::GetEncoding("iso-8859-1")
$encodedFile = $encodingScheme.GetString($tokeneniseFileBin)

$TokenType = 'doc-msword'

$requestBody = @"
--$httpBoundary
Content-Disposition: form-data; name="factory_auth"

$ApiToken
--$httpBoundary
Content-Disposition: form-data; name="memo"

$([System.Net.Dns]::GetHostName()) | $TokenName
--$httpBoundary
Content-Disposition: form-data; name="kind"

$TokenType
--$httpBoundary
Content-Disposition: form-data; name="flock_id"

$word_FlockID
--$httpBoundary
Content-Disposition: form-data; name ="doc"; filename ="$tokeneniseFileName"
Content-Type: $contentType

$encodedFile

--$httpBoundary--
"@


Write-Host -ForegroundColor Green "[*] Hitting API to create token ..."
$CreateResultDocToken = Invoke-RestMethod -Method Post -Uri "https://$ApiHost$ApiBaseURL/canarytoken/factory/create" -Body $requestBody -ContentType "multipart/form-data; boundary=$httpBoundary;"
$Result = $CreateResultDocToken.result
If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Creation of $TokenName failed."
    Exit
}
Else {
    $TokenID = $($CreateResultDocToken).canarytoken.canarytoken
    Write-Host -ForegroundColor Green "[*] Token Created (ID: $TokenID)."
}

# Downloads token and places it in the destination folder.
Write-Host -ForegroundColor Green "[*] Downloading Token from Console..."
Invoke-RestMethod -Method Get -Uri "https://$ApiHost$ApiBaseURL/canarytoken/factory/download?factory_auth=$ApiToken&canarytoken=$TokenID" -OutFile "$OutputFileName"
Write-Host -ForegroundColor Green "[*] Token Successfully written to destination: '$OutputFileName'."

$ReplaceText = $CreateResult.canarytoken.access_key_id # <= Replace it with this text
$ReplaceText2 = $CreateResult.canarytoken.secret_access_key

$zipName = $OutputFileName.Split('.')[0] + '.zip'
mv $OutputFileName $zipName
Expand-Archive -path $zipName -DestinationPath $tokeneniseFile.Split('.')[0]

$xmlToEdit = $tokeneniseFile.Split('.')[0] + '\word\document.xml'
(Get-Content -Path $xmlToEdit) -replace 'AKIASJ2WZMVFQGNWG4HA', $ReplaceText | Set-Content $xmlToEdit
(Get-Content -Path $xmlToEdit) -replace 'zXqAw2NlqNdha1IVCBNkIdv74AdfPw6MMb6xKBw5', $ReplaceText2 | Set-Content $xmlToEdit

Remove-Item $zipName
$compressPath = $tokeneniseFile.Split('.')[0] + "\*"
Compress-Archive -Path $compressPath -DestinationPath $zipName

$wordName = $zipName.Split('.')[0] + '.docx'
Move-Item $zipName $wordName
Remove-Item $tokeneniseFile.Split('.')[0] -Force -Recurse

# Remove template file

Remove-Item $tokeneniseFile

# Random date stuff goes here
# https://gist.githubusercontent.com/emyann/826d9f799fb5f0d115ac3b9eaaa3a958/raw/9fca347bd0a84c448bef153ea536c788079c6b92/RandomDateTimeGenerator.ps1

function Get-RandomDateBetween{
    <#
    .EXAMPLE
    Get-RandomDateBetween -StartDate (Get-Date) -EndDate (Get-Date).AddDays(15)
    #>
    [Cmdletbinding()]
    param(
        [parameter(Mandatory=$True)][DateTime]$StartDate,
        [parameter(Mandatory=$True)][DateTime]$EndDate
        )

    process{
       return Get-Random -Minimum $StartDate.Ticks -Maximum $EndDate.Ticks | Get-Date -Format d
    }
}


function Get-RandomTimeBetween{
  <#
    .EXAMPLE
    Get-RandomTimeBetween -StartTime "08:30" -EndTime "16:30"
    #>
     [Cmdletbinding()]
    param(
        [parameter(Mandatory=$True)][string]$StartTime,
        [parameter(Mandatory=$True)][string]$EndTime
        )
    begin{
        $minuteTimeArray = @("00","15","30","45")
    }    
    process{
        $rangeHours = @($StartTime.Split(":")[0],$EndTime.Split(":")[0])
        $hourTime = Get-Random -Minimum $rangeHours[0] -Maximum $rangeHours[1]
        $minuteTime = "00"
        if($hourTime -ne $rangeHours[0] -and $hourTime -ne $rangeHours[1]){
            $minuteTime = Get-Random $minuteTimeArray
            return "${hourTime}:${minuteTime}"
        }
        elseif ($hourTime -eq $rangeHours[0]) { # hour is the same as the start time so we ensure the minute time is higher
            $minuteTime = $minuteTimeArray | ?{ [int]$_ -ge [int]$StartTime.Split(":")[1] } | Get-Random # Pick the next quarter
            #If there is no quarter available (eg 09:50) we jump to the next hour (10:00)
            return (.{If(-not $minuteTime){ "${[int]hourTime+1}:00" }else{ "${hourTime}:${minuteTime}" }})               
         
        }else { # hour is the same as the end time
            #By sorting the array, 00 will be pick if no close hour quarter is found
            $minuteTime = $minuteTimeArray | Sort-Object -Descending | ?{ [int]$_ -le [int]$EndTime.Split(":")[1] } | Get-Random
            return "${hourTime}:${minuteTime}"
        }
    }
}

# function to modify file attributes
# https://raw.githubusercontent.com/BC-SECURITY/Empire/master/empire/server/data/module_source/management/Set-MacAttribute.ps1

function Set-MacAttribute {
<#
.SYNOPSIS

    Sets the modified, accessed and created (Mac) attributes for a file based on another file or input.

    PowerSploit Function: Set-MacAttribute
    Author: Chris Campbell (@obscuresec)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None
    Version: 1.0.0
 
.DESCRIPTION

    Set-MacAttribute sets one or more Mac attributes and returns the new attribute values of the file.

.EXAMPLE

    PS C:\> Set-MacAttribute -FilePath c:\test\newfile -OldFilePath c:\test\oldfile

.EXAMPLE

    PS C:\> Set-MacAttribute -FilePath c:\demo\test.xt -All "01/03/2006 12:12 pm"

.EXAMPLE

    PS C:\> Set-MacAttribute -FilePath c:\demo\test.txt -Modified "01/03/2006 12:12 pm" -Accessed "01/03/2006 12:11 pm" -Created "01/03/2006 12:10 pm"

.LINK
    
    http://www.obscuresec.com/2014/05/touch.html
  
#>
    [CmdletBinding(DefaultParameterSetName = 'Touch')] 
        Param (
    
        [Parameter(Position = 1,Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $FilePath,
    
        [Parameter(ParameterSetName = 'Touch')]
        [ValidateNotNullOrEmpty()]
        [String]
        $OldFilePath,
    
        [Parameter(ParameterSetName = 'Individual')]
        [DateTime]
        $Modified,

        [Parameter(ParameterSetName = 'Individual')]
        [DateTime]
        $Accessed,

        [Parameter(ParameterSetName = 'Individual')]
        [DateTime]
        $Created,
    
        [Parameter(ParameterSetName = 'All')]
        [DateTime]
        $AllMacAttributes
    )

    Set-StrictMode -Version 2.0
    
    #Helper function that returns an object with the MAC attributes of a file.
    function Get-MacAttribute {
    
        param($OldFileName)
        
        if (!(Test-Path $OldFileName)){Throw "File Not Found"}
        $FileInfoObject = (Get-Item $OldFileName)

        $ObjectProperties = @{'Modified' = ($FileInfoObject.LastWriteTime);
                              'Accessed' = ($FileInfoObject.LastAccessTime);
                              'Created' = ($FileInfoObject.CreationTime)};
        $ResultObject = New-Object -TypeName PSObject -Property $ObjectProperties
        Return $ResultObject
    } 
    
    #test and set variables
    if (!(Test-Path $FilePath)){Throw "$FilePath not found"}

    $FileInfoObject = (Get-Item $FilePath)
    
    if ($PSBoundParameters['AllMacAttributes']){
        $Modified = $AllMacAttributes
        $Accessed = $AllMacAttributes
        $Created = $AllMacAttributes
    }

    if ($PSBoundParameters['OldFilePath']){

        if (!(Test-Path $OldFilePath)){Write-Error "$OldFilePath not found."}

        $CopyFileMac = (Get-MacAttribute $OldFilePath)
        $Modified = $CopyFileMac.Modified
        $Accessed = $CopyFileMac.Accessed
        $Created = $CopyFileMac.Created
    }

    if ($Modified) {$FileInfoObject.LastWriteTime = $Modified}
    if ($Accessed) {$FileInfoObject.LastAccessTime = $Accessed}
    if ($Created) {$FileInfoObject.CreationTime = $Created}

    Return (Get-MacAttribute $FilePath)
}

# Set the attributes
# Can confirm attributes using Get-MacAttribute

$mainFolderPath = 'C:\ProgramData\' + $mainFolder
$subFolderPath = 'C:\ProgramData\' + $mainFolder + '\' + $subFolder

$mainAttribute = ((Get-RandomDateBetween -StartDate (Get-Date).AddDays(-(Get-Random -Minimum 1000 -Maximum 1500)) -EndDate (Get-Date)) + " " + (Get-RandomTimeBetween -StartTime "08:00" -EndTime "20:00"))
$subAttribute = ((Get-RandomDateBetween -StartDate (Get-Date).AddDays(-(Get-Random -Minimum 700 -Maximum 999)) -EndDate (Get-Date)) + " " + (Get-RandomTimeBetween -StartTime "08:00" -EndTime "20:00"))

Set-MacAttribute -FilePath $mainFolderPath -Created $mainAttribute -Modified $mainAttribute -Accessed $mainAttribute
Set-MacAttribute -FilePath $subFolderPath -Created $subAttribute -Modified $subAttribute -Accessed $subAttribute
Set-MacAttribute -FilePath $OutputFileName -Created ((Get-RandomDateBetween -StartDate (Get-Date).AddDays(-(Get-Random -Minimum 400 -Maximum 699)) -EndDate (Get-Date)) + " " + (Get-RandomTimeBetween -StartTime "08:00" -EndTime "20:00"))
Set-MacAttribute -FilePath $OutputFileName -Modified ((Get-RandomDateBetween -StartDate (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 399)) -EndDate (Get-Date)) + " " + (Get-RandomTimeBetween -StartTime "08:00" -EndTime "20:00")) 