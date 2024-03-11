 <#
.SYNOPSIS
    This script reads a list of hostnames from a text file and executes a separate PowerShell script on each host using PsExec.
.DESCRIPTION
    This script takes two parameters:
    -hosts: Path to the text file containing hostnames (one per line).
    -script: Path to the script to be executed on target hosts.

    If PsExec is not found in the script's directory, it offers to download it.

.PARAMETER hosts
    Path to the text file containing hostnames (one per line).
.PARAMETER script
    Path to the remote script to be executed on target hosts.
.EXAMPLE
    .\RunRemoteScript.ps1 -hosts "C:\path\to\hostnames.txt" -script "C:\path\to\remote_script.ps1"
.NOTES
    Author: Gareth Wood
    Version: 1.1
    Date: November 8, 2023
#>

param (
    [string]$hosts,
    [string]$script
)

# Determine the directory of the currently running script
$scriptDirectory = $PSScriptRoot

# Check if PsExec executable exists in the script's directory
$psexecPath = Join-Path -Path $scriptDirectory -ChildPath "PsExec.exe"

if (-not (Test-Path -Path $psexecPath -PathType Leaf)) {
    Write-Host -ForegroundColor Yellow "PsExec is not found in the script's directory."

    # Prompt the user to download PsExec
    $downloadChoice = Read-Host "Would you like to download PsExec? (Y/N)"

    if ($downloadChoice -eq "Y" -or $downloadChoice -eq "y") {
        # Download PsExec
        $psexecZipPath = Join-Path -Path $scriptDirectory -ChildPath "PSTools.zip"
        $psexecTempDir = Join-Path -Path $scriptDirectory -ChildPath "PSToolsTemp"

        Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile $psexecZipPath
        Expand-Archive -Path $psexecZipPath -DestinationPath $psexecTempDir

        # Copy only PsExec.exe to the script's directory
        Copy-Item -Path (Join-Path -Path $psexecTempDir -ChildPath "PsExec.exe") -Destination $scriptDirectory
        Remove-Item -Path $psexecTempDir -Recurse -Force
        Remove-Item -Path $psexecZipPath -Force

        Write-Host -ForegroundColor Green "PsExec has been downloaded and installed in the script's directory."
        $psexecPath = Join-Path -Path $scriptDirectory -ChildPath "PsExec.exe"
    } else {
        Write-Host -ForegroundColor Yellow "You can manually download PsExec from the following link:"
        Write-Host -ForegroundColor Green "https://download.sysinternals.com/files/PSTools.zip"
        exit 1
    }
}

# Check if the hosts and script parameters are provided
if (-not $hosts -or -not $script) {
    Write-Host -ForegroundColor Red "Usage: .\RunRemoteScript.ps1 -hosts <HostsPath> -script <RemoteScriptPath>"
    Write-Host -ForegroundColor Yellow "       -hosts: Path to the text file containing hostnames (one per line)."
    Write-Host -ForegroundColor Yellow "       -script: Path to the remote script to be executed on target hosts."
    exit 1
}

# Extract the script filename from the script path
$scriptFilename = [System.IO.Path]::GetFileName($script)

# Read hostnames from the text file
$hostnames = Get-Content -Path $hosts

# Prevent PsExec infomrational output
$ErrorActionPreference = "SilentlyContinue"

foreach ($hostname in $hostnames) {
    
    # Copies the script over to the target host's admin$ share. (This will try and run it too, but .ps1 files don't have a native handler on Windows, so we have to execute it later.)
    Write-Host -ForegroundColor Yellow "Sending script to $hostname"
    $psexecCopy = "$psexecPath \\$hostname -accepteula -nobanner -c -f -d $script"

    # Execute the script on the target host using powershell.
    Write-Host -ForegroundColor Yellow "Executing script on $hostname"
    $psexecExecute = "$psexecPath \\$hostname -nobanner -d powershell -File 'C:\Windows\$scriptFilename'"

    # Clean up the copied over script. (This can be handled within the script it's self too, in which case simply comment this line out.)
    Write-Host -ForegroundColor Yellow "Cleaning up script on $hostname"
    $psexecClean = "$psexecPath \\$hostname -nobanner powershell -c Remove-Item –path 'C:\Windows\$scriptFilename'"

    # Execute PsExec command
    try {
        Invoke-Expression -Command $psexecCopy
        Invoke-Expression -Command $psexecExecute
        Invoke-Expression -Command $psexecClean
        Write-Host -ForegroundColor Green "Script passed to PsExec for $hostname. `n"
    } catch {
        Write-Host -ForegroundColor Red "Failed to execute script on $hostname."
        Write-Host -ForegroundColor Red "Error: $_"
    }
} 
