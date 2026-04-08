<#
Deploy an RDP Breadcrumb without making any API calls to the Canary Console.
#>

Param (
  [string]$TargetDirectory = 'C:\jumpboxes',
  [string]$RdpFilename = 'server.rdp',
  [string]$RdpServerHost = '127.0.0.1' # Canary IP Address or Hostname

)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-Log {
  param(
    [Parameter(Mandatory)] [string]$Stage,
    [Parameter(Mandatory)] [string]$Message,
    [ValidateSet('INFO','WARN','ERROR','OK')] [string]$Level = 'INFO'
  )

  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  $line = "[$ts][$Level][$Stage] $Message"

  switch ($Level) {
    'OK'    { Write-Host -ForegroundColor Green  $line }
    'WARN'  { Write-Host -ForegroundColor Yellow $line }
    'ERROR' { Write-Host -ForegroundColor Red    $line }
    default { Write-Host $line }
  }
}

function Ensure-Directory([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Log -Stage 'fs' -Level 'INFO' -Message "Creating directory: $Path"
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  } else {
    Write-Log -Stage 'fs' -Level 'INFO' -Message "Directory exists: $Path"
  }
}

function Deploy-RDP-Crumb {
  param(
    [Parameter(Mandatory)] [string]$TargetFolder,
    [Parameter(Mandatory)] [string]$FileName,
    [Parameter(Mandatory)] [string]$RDPServerHostOrIP
  )

  Write-Log -Stage 'rdp' -Level 'INFO' -Message "Starting RDP breadcrumb deployment (file='$FileName', dir='$TargetFolder', host='$RDPServerHostOrIP')."

  Ensure-Directory $TargetFolder
  $outPath = Join-Path -Path $TargetFolder -ChildPath $FileName
  Write-Log -Stage 'rdp' -Level 'INFO' -Message "Target path: $outPath"

  $rdpContent = @"
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
winposstr:s:0,1,387,0,1427,802
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:${RDPServerHostOrIP}:3389
audiomode:i:0
redirectprinters:i:1
redirectlocation:i:0
redirectcomports:i:0
redirectsmartcards:i:1
redirectwebauthn:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:1
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
enablerdsaadauth:i:0
"@

  Write-Log -Stage 'write' -Level 'INFO' -Message "Writing RDP file (ASCII) to: $outPath"
  Set-Content -LiteralPath $outPath -Value $rdpContent -Encoding ASCII -Force

  Write-Log -Stage 'verify' -Level 'INFO' -Message "Verifying file exists and is non-empty: $outPath"
  $fi = Get-Item -LiteralPath $outPath
  if ($fi.Length -le 0) { throw "Wrote '$outPath' but it is empty." }

  Write-Log -Stage 'rdp' -Level 'OK' -Message "RDP breadcrumb written successfully: $outPath (bytes=$($fi.Length)) on $env:COMPUTERNAME"
}

# ------------------------------------
# Main
# ------------------------------------
try {

  Ensure-Directory $TargetDirectory
  Write-Log -Stage 'init' -Level 'INFO' -Message "RDP: filename='$RdpFilename' host='$RdpServerHost'"

  Deploy-RDP-Crumb -TargetFolder $TargetDirectory -FileName $RdpFilename -RDPServerHostOrIP $RdpServerHost
  Write-Log -Stage 'done' -Level 'OK' -Message "All tasks completed."
}
catch {
  Write-Log -Stage 'fatal' -Level 'ERROR' -Message $_.Exception.Message
  exit 1
}
