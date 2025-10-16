# -----------------------------------------------------------------------------
# Creates a bat file that contains an SMB lure script pointing towards a Canary
# -----------------------------------------------------------------------------

$ConsoleDomain    = '.canary.tools'

# Read-only Console API key
$ApiKey           = ''

$Breadcrumb_ScriptPath = 'C:\tools'
$Breadcrumb_ScriptName = 'remote_copy.bat'

# SMB defaults
$SMBShare         = 'admintools'
$SMBUsername      = 'admin'
$SMBPassword      = 't00l$@dm1n!'
$SMBLocalDir      = 'C:\Users\%USERNAME%\Downloads\remote_copy'
$SMBDriveLetter   = 'Z'

# Canary defaults
$CanaryNodes      = @('')

# Enforce TLS1.2 and strict mode
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
        [string]$SMBShare,
        [string]$SMBUsername,
        [string]$SMBPassword,
        [string]$SMBLocalDir,
        [string]$SMBDriveLetter
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

    # Fill SMB placeholders
    $Breadcrumb_Content = $Breadcrumb_Content.Replace('<SMB_REMOTE_HOST>', $CanaryIPAddress)
    $Breadcrumb_Content = $Breadcrumb_Content.Replace('<SMB_SHARE>', $SMBShare)
    $Breadcrumb_Content = $Breadcrumb_Content.Replace('<SMB_USERNAME>', $SMBUsername)
    $Breadcrumb_Content = $Breadcrumb_Content.Replace('<SMB_PASSWORD>', $SMBPassword)
    $Breadcrumb_Content = $Breadcrumb_Content.Replace('<SMB_LOCAL_DIR>', $SMBLocalDir)
    $Breadcrumb_Content = $Breadcrumb_Content.Replace('<SMB_DRIVE_LETTER>', $SMBDriveLetter)
    $Breadcrumb_Content = $Breadcrumb_Content.Replace('<CANARY_IP>', $CanaryIPAddress)

    # Ensure the target directory exists
    try {
        if (-not (Test-Path -LiteralPath $Breadcrumb_ScriptPath)) {
            New-Item -Path $Breadcrumb_ScriptPath -ItemType Directory -Force | Out-Null
        }
    }
    catch {
        return "bc-scriptpath-create-$($_.Exception.Message)"
    }

    # Write the lure script
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($Breadcrumb_ScriptFullPath, $Breadcrumb_Content, $utf8NoBom)
    }
    catch {
        return "bc-write-failed-$($_.Exception.Message)"
    }

    return "Success"
}

# Lure script template for SMB copy
$Breadcrumb_Content = @'
@echo off
setlocal

:: === Configuration ===
set "REMOTE_HOST=\\<SMB_REMOTE_HOST>"
set "SHARE=<SMB_SHARE>"
set "USERNAME=<SMB_USERNAME>"
set "PASSWORD=<SMB_PASSWORD>"
set "LOCAL_DIR=<SMB_LOCAL_DIR>"
set "DRIVE_LETTER=<SMB_DRIVE_LETTER>"

:: Create local directory if it does not exist
if not exist "%LOCAL_DIR%" (
    mkdir "%LOCAL_DIR%"
)

:: Map the network drive temporarily
net use %DRIVE_LETTER%: "%REMOTE_HOST%\%SHARE%" /user:%USERNAME% %PASSWORD% /persistent:no

:: Check if the mapping was successful
if not exist "%DRIVE_LETTER%:\" (
    echo Failed to connect to shared folder.
    goto end
)

:: Copy files from the network share to local directory
xcopy "%DRIVE_LETTER%:\*" "%LOCAL_DIR%\" /E /H /C /I /Y
echo Files copied successfully to %LOCAL_DIR%.

:: Disconnect the mapped drive
net use %DRIVE_LETTER%: /delete

:end
echo Done.
endlocal
'@

# Deploy
$resBc = Deploy-Breadcrumb `
    -ConsoleDomain $ConsoleDomain `
    -ApiKey $ApiKey `
    -CanaryNodes $CanaryNodes `
    -Breadcrumb_ScriptPath $Breadcrumb_ScriptPath `
    -Breadcrumb_ScriptName $Breadcrumb_ScriptName `
    -Breadcrumb_Content $Breadcrumb_Content `
    -SMBShare $SMBShare `
    -SMBUsername $SMBUsername `
    -SMBPassword $SMBPassword `
    -SMBLocalDir $SMBLocalDir `
    -SMBDriveLetter $SMBDriveLetter `
    -Verbose

$resBc
