<#
.SYNOPSIS
   Sensitive Command Manager
   
.DESCRIPTION
   This PowerShell script manages sensitive command Tokens by creating, deleting or modifying them. 
   Note: This script must be run with administrative permissions.

.PARAMETER Action
   Specifies the action to perform. Valid values are "create", "delete", "ignoreuser", and "ignoreprocess".
   
.PARAMETER Executable
   Specify the name of the executable to Token.
   
.PARAMETER Domain
   Enter your Canary Console domain. e.g. 1234abc.canary.tools
   
.PARAMETER ApiKey
   Enter your Console Global API key.
   
.PARAMETER IgnoreUser
   Specify the username to exclude from monitoring Token triggering.
   
.PARAMETER IgnoreProcess
   Specify the parent process to exclude from Token Triggering.

.NOTES
   Version: 1.0
   Author: Gareth Wood

.EXAMPLE
   .\SensitiveCommandManager.ps1 -Action create -Executable "example.exe" -Domain "example-domain" -ApiKey "api-key"
   Creates a token for the "example.exe" executable.

.EXAMPLE
   .\SensitiveCommandManager.ps1 -Action delete -Executable "example.exe" -Domain "example-domain" -ApiKey "api-key"
   Deletes the token associated with the "example.exe" from the Console and the local host.

.EXAMPLE
   .\SensitiveCommandManager.ps1 -Action ignoreuser -IgnoreUser "user1" -Executable "example.exe"
   Excludes the user "user1" from triggering the Token.
   Note: This function isn't implemented yet.
.EXAMPLE
   .\SensitiveCommandManager.ps1 -Action ignoreprocess -IgnoreProcess "parent.exe" -Executable "example.exe"
   Excludes the parent process "parent.exe" from triggering the Token.
   Note: This function isn't implemented yet.
#>

Param (
    [string]$Action,
    [string]$Executable,
    [string]$Domain,
    [string]$ApiKey,
    [string]$IgnoreUser,
    [string]$IgnoreProcess
    )

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires administrative privileges. Please run the script as an administrator."
    Exit
}

# Check if $Executable ends with ".exe" and remove it if it does
if ($Executable -like "*.exe") {
    $Executable_trim = $Executable -replace "\.exe$", ""
} else {
# Append ".exe" if not already present
    $Executable += ".exe"
}

# Check if $Domain ends with ".canary.tools" and add it if it doesn't
if ($Domain -notlike "*.canary.tools") {
    $Domain += ".canary.tools"
}

# Function to create token
function Create-Token {
    param (
        [string]$Executable,
        [string]$Domain,
        [string]$ApiKey
    )
    
    try {
        $PostData = @{
            auth_token = "$ApiKey"
            kind       = "sensitive-cmd"
            process_name = "$Executable"
            memo       = "$([System.Net.Dns]::GetHostName()) - $Executable"
        }
        
        $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/create" -Body $PostData
        $Result = $CreateResult.result
        $TokenID = $($CreateResult).canarytoken.canarytoken
        $TokenHostname = $($CreateResult).canarytoken.hostname
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while creating token: $($_.Exception.Message)"
        Exit
    }

    $MonitorProcess = 'cmd.exe /c start /min powershell.exe -windowstyle hidden -command "$($u=$(\"u$env:username\" -replace(''[^a-zA-Z0-9\-]+'', ''''))[0..63] -join '''';$c=$(\"c$env:computername\" -replace(''[^a-zA-Z0-9\-]+'', ''''))[0..63] -join '''';'+' Resolve-DnsName -Name \"$c.UN.$u-'+$Executable_trim+'.CMD.'+$TokenHostname+'\")"'

    # Create registry keys in both 64-bit and 32-bit hives.
    try {
        # Create Debug flag key for process in both hives
        New-Item -Force -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Executable" | Out-Null
        New-Item -Force -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Executable" | Out-Null
        # Create trigger process key in both hives
        New-Item -Force -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" | Out-Null
        New-Item -Force -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" | Out-Null
        # -- #
        # Set Debug flag for process in both hives
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Executable" -Name "GlobalFlag" -Value 0x00000200 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Executable" -Name "GlobalFlag" -Value 0x00000200 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
        # Set reporting mode flags in both hives
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "ReportingMode" -Value 0x00000001 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "ReportingMode" -Value 0x00000001 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
        # Set trigger process in both hives
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -Value $MonitorProcess -PropertyType String -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -Value $MonitorProcess -PropertyType String -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while setting registry key: $($_.Exception.Message)"
        Exit
    }
}

# Function to delete token
function Delete-Token {
    param (
        [string]$Executable,
        [string]$Domain,
        [string]$ApiKey
    )

    # Define the registry path
    $RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable"
    
    try {
        # Get the MonitorProcess value from the registry
        $MonitorProcessValue = Get-ItemPropertyValue -Path $RegistryPath -Name "MonitorProcess" -ErrorAction Stop
        
        # Extract the relevant information from the MonitorProcess value
        $TokenHostname = $MonitorProcessValue -replace '.*\.CMD\.(.+?)\\.*', '$1'

        # Extract the TokenID from TokenHostname
        $TokenID = $TokenHostname -replace '^(.*?)\..*', '$1'
        
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while searching for Token locally: $($_.Exception.Message)"
        Write-Host -ForegroundColor Yellow "Will still try to delete local keys anyway."
    }
    # Delete Token from Console
    try{
       $PostData = @{
           auth_token = "$ApiKey"
           canarytoken = "$TokenID"
           clear_incidents = "True"
       }
        
       $DeleteResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/delete" -Body $PostData
     }
     catch {
         Write-Host -ForegroundColor Red "Error occurred while deleting Token: $($_.Exception.Message)"
         Write-Host -ForegroundColor Yellow "Couldn't Delete Token from Console, trying to delete it locally anyway."
     }


    # Delete registry keys values in both 64-bit and 32-bit hives.
    try {
        # Remove Debug flag for process in both hives
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Executable" -Name "GlobalFlag" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$Executable" -Name "GlobalFlag" -ErrorAction SilentlyContinue
        # Remove Reporting Mode for process in both hives
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "ReportingMode" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "ReportingMode" -ErrorAction SilentlyContinue
        # Remove Debug Process command in both hives
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while setting registry key: $($_.Exception.Message)"
        Exit
    }

    Write-Host -ForegroundColor Green "Deleted sensitive command Token for $Executable - $TokenID "
}

# Function to exclude user
function Exclude-User {
    param (
        [string]$IgnoreUser,
        [string]$Process
    )

    Write-Host "Excluding user $IgnoreUser from monitoring process $Process"
    Write-Host "Function not implemented yet"
    Exit
}

# Function to exclude parent process
function Exclude-ParentProcess {
    param (
        [string]$IgnoreProcess,
        [string]$Process
    )

    Write-Host "Excluding parent process $IgnoreProcess from monitoring process $Process"
    Write-Host "Function not implemented yet"
    Exit
}

# Execute appropriate function based on provided action parameter
switch ($Action) {
    "create" {
        Create-Token -Executable $Executable -Domain $Domain -ApiKey $ApiKey
    }
    "delete" {
        Delete-Token -Executable $Executable -Domain $Domain -ApiKey $ApiKey
    }
    "ignoreuser" {
        Exclude-User -IgnoreUser $IgnoreUser -Process $Executable
    }
    "ignoreprocess" {
        Exclude-ParentProcess -IgnoreProcess $IgnoreProcess -Process $Executable
    }
    default {
        Write-Host "Invalid action. Please provide a valid action."
    }
}