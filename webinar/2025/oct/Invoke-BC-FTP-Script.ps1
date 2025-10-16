# -----------------------------------------------------------------------------
# Creates a cmd file that contains an FTP lure script pointing towards a Canary
# -----------------------------------------------------------------------------

$ConsoleDomain    = '.canary.tools'

# Read-only Console API key:
$ApiKey           = ''

$Breadcrumb_ScriptPath = 'C:\tools'
$Breadcrumb_ScriptName = 'gettools.cmd'
$FTPUsername = 'ftpadmin'
$FTPPassword = 'FTP@dm1nT00l$'
$FTPRemoteDir = '/baseimage/tools'
$FTPLocalDir = 'C:\tools'
$FTPTempScriptName = 'ftpsync'

# Breadcrumb defaults
$CanaryNodes     = @('')

# Enforce TLS1.2 & strict mode
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-StrictMode -Version 4

function Deploy-Breadcrumb {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$ConsoleDomain,
        [string]$ApiKey,
        [string[]]$CanaryNodes,
        [string]$Breadcrumb_ScriptPath,
        [string]$Breadcrumb_ScriptName,
        [string]$Breadcrumb_Content,
        [string]$FTPUsername,
        [string]$FTPPassword,
        [string]$FTPRemoteDir,
        [string]$FTPLocalDir,
        [string]$FTPTempScriptName
    )

    if (-not $ApiKey) { return "bc-APIkey-not-set" }
    if (-not $ConsoleDomain) { return "bc-console-domain-not-set" }
    if (-not $CanaryNodes -or $CanaryNodes.Count -eq 0) { return "bc-no-nodes" }

    if ($Breadcrumb_ScriptPath -match '\\$') { $Breadcrumb_ScriptPath = $Breadcrumb_ScriptPath.TrimEnd('\') }
    $Breadcrumb_ScriptFullPath = "$Breadcrumb_ScriptPath\$Breadcrumb_ScriptName"

    try {
        $RandomNode = Get-Random -InputObject $CanaryNodes
        $params = @{
            Uri    = "https://$ConsoleDomain/api/v1/device/info"
            Method = 'GET'
            Body   = @{
                auth_token = $ApiKey
                node_id    = $RandomNode
            }
        }
        $CanaryResult = Invoke-RestMethod @params
    }
    catch {
        return "bc-api-req-$($_.Exception.Message)"
    }

    if (-not $CanaryResult.device.ip_address) { return "bc-api-resp" }
    $CanaryIPAddress = $CanaryResult.device.ip_address

    $Breadcrumb_Content = $Breadcrumb_Content -replace '<FTP_HOST>', $CanaryIPAddress
    $Breadcrumb_Content = $Breadcrumb_Content -replace '<FTP_USER>', $FTPUsername
    $Breadcrumb_Content = $Breadcrumb_Content -replace '<FTP_PASSWORD>', $FTPPassword
    $Breadcrumb_Content = $Breadcrumb_Content -replace '<FTP_REMOTE_DIR>', $FTPRemoteDir
    $Breadcrumb_Content = $Breadcrumb_Content -replace '<FTP_LOCAL_DIR>', $FTPLocalDir
    $Breadcrumb_Content = $Breadcrumb_Content -replace '<FTP_TEMP_SCRIPT_NAME>', $FTPTempScriptName

    # Ensure the target directory exists
    try {
        if (-not (Test-Path -LiteralPath $Breadcrumb_ScriptPath)) {
            New-Item -Path $Breadcrumb_ScriptPath -ItemType Directory -Force | Out-Null
        }
    }
    catch {
        return "bc-scriptpath-create-$($_.Exception.Message)"
    }

    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($Breadcrumb_ScriptFullPath, $Breadcrumb_Content, $utf8NoBom)
    }
    catch {
        return "bc-write-failed-$($_.Exception.Message)"
    }

    return "Success"
}

# Lure script template
$Breadcrumb_Content = @'
@echo off
setlocal

:: Configuration
set FTP_HOST=<FTP_HOST>
set FTP_USER=<FTP_USER>
set FTP_PASS=<FTP_PASSWORD>
set REMOTE_DIR=<FTP_REMOTE_DIR>
set LOCAL_DIR=<FTP_LOCAL_DIR>

:: Change to local destination directory
pushd "%LOCAL_DIR%"
if errorlevel 1 (
    echo Failed to change to local directory: %LOCAL_DIR%
    exit /b 1
)

:: Create FTP script file
set FTP_SCRIPT=%TEMP%\<FTP_TEMP_SCRIPT_NAME>
echo open %FTP_HOST% > "%FTP_SCRIPT%"
echo user %FTP_USER% %FTP_PASS% >> "%FTP_SCRIPT%"
echo cd %REMOTE_DIR% >> "%FTP_SCRIPT%"
echo lcd %LOCAL_DIR% >> "%FTP_SCRIPT%"
echo binary >> "%FTP_SCRIPT%"
echo prompt >> "%FTP_SCRIPT%"       :: Disable prompting for multiple files
echo mget * >> "%FTP_SCRIPT%"
echo bye >> "%FTP_SCRIPT%"

:: Run FTP
ftp -n -s:"%FTP_SCRIPT%"

:: Clean up
del "%FTP_SCRIPT%"
popd

endlocal
'@ 

$resBc = Deploy-Breadcrumb `
    -ConsoleDomain $ConsoleDomain `
    -ApiKey $ApiKey `
    -CanaryNodes $CanaryNodes `
    -Breadcrumb_ScriptPath $Breadcrumb_ScriptPath `
    -Breadcrumb_ScriptName $Breadcrumb_ScriptName `
    -Breadcrumb_Content $Breadcrumb_Content `
    -FTPUsername $FTPUsername `
    -FTPPassword $FTPPassword `
    -FTPRemoteDir $FTPRemoteDir `
    -FTPLocalDir $FTPLocalDir `
    -FTPTempScriptName $FTPTempScriptName `
    -Verbose 

$resBc
