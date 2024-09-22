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
   Version: 1.2
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
.EXAMPLE
   .\SensitiveCommandManager.ps1 -Action ignoreprocess -IgnoreProcess "parent.exe" -Executable "example.exe"
   Excludes the parent process "parent.exe" from triggering the Token.
#>

Param (
    [string]$Action,
    [string]$Executable,
    [string]$Domain,
    [string]$ApiKey,
    [string]$IgnoreUser,
    [string]$IgnoreProcess
)

function Show-Help {
    Write-Host "Usage: "
    Write-Host "    -Action <create|delete|ignoreuser|ignoreprocess> (Required)"
    Write-Host "    -Executable <Name of the executable> (Required for create, delete, ignoreuser, ignoreprocess)"
    Write-Host "    -Domain <Domain> (Required for create, delete)"
    Write-Host "    -ApiKey <API Key> (Required for create, delete)"
    Write-Host "    -IgnoreUser <User to ignore> (Required for ignoreuser)"
    Write-Host "    -IgnoreProcess <Process to ignore> (Required for ignoreprocess)"
    Write-Host "Example:"
    Write-Host "    ./script.ps1 -Action create -Executable myapp -Domain mydomain -ApiKey myapikey"
    Exit
}

# Check if required parameters are missing
if (-not $Action) {
    Write-Host "Error: The -Action parameter is required."
    Show-Help
}

# Validate the required parameters for each action
switch ($Action.ToLower()) {
    "create" {
        if (-not $Executable -or -not $Domain -or -not $ApiKey) {
            Write-Host "Error: -Executable, -Domain, and -ApiKey are required for create/delete actions."
            Show-Help
        }
    }
    "delete" {
        if (-not $Executable -or -not $Domain -or -not $ApiKey) {
            Write-Host "Error: -Executable, -Domain, and -ApiKey are required for create/delete actions."
            Show-Help
        }
    }
    "ignoreuser" {
        if (-not $IgnoreUser -or -not $Executable) {
            Write-Host "Error: -IgnoreUser and -Executable are required for ignoreuser action."
            Show-Help
        }
    }
    "ignoreprocess" {
        if (-not $IgnoreProcess -or -not $Executable) {
            Write-Host "Error: -IgnoreProcess and -Executable are required for ignoreprocess action."
            Show-Help
        }
    }
    default {
        Write-Host "Error: Invalid action specified."
        Show-Help
    }
}

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

# Check if $IgnoreProcess ends with ".exe" and remove it if it does
if ($IgnoreProcess -like "*.exe") {
    $IgnoreProcess_trim = $IgnoreProcess -replace "\.exe$", ""
} else {
# Append ".exe" if not already present
    $IgnoreProcess += ".exe"
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

        Write-Host -ForegroundColor Green "Successfully Created Sensitive Command Token. ID: $($CreateResult.canarytoken.canarytoken) Reminder: $($CreateResult.canarytoken.memo)"
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while creating token: $($_.Exception.Message)"
        Exit
    }

    $MonitorProcess = 'cmd.exe /c start /min powershell.exe -windowstyle hidden -command "$($u=$(\"u$env:username\" -replace ''[^a-zA-Z0-9\-]+'', '''')[0..63] -join ''''; $c=$(\"c$env:computername\" -replace ''[^a-zA-Z0-9\-]+'', '''')[0..63] -join ''''; $id=\"\"; 1..8 | foreach-object { $id += [Char[]]\"abcdefhijklmnonpqrstuvwxyz0123456789\" | Get-Random }; Resolve-DnsName -Name \"$c.UN.$u.CMD.$id.'+$TokenHostname+'\")"'
    
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
        $TokenHostname = $MonitorProcessValue -replace '.*\.CMD\.\$id\.(.+?)\\.*', '$1'

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
        [string]$Executable
    )

    Write-Host "Excluding user $IgnoreUser from monitoring process $Executable"

    # Define the registry path
    $RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable"
    
    try {
        # Get the MonitorProcess value from the registry
        $MonitorProcessValue = Get-ItemPropertyValue -Path $RegistryPath -Name "MonitorProcess" -ErrorAction Stop
        
        # Extract the relevant information from the MonitorProcess value
        $TokenHostname = $MonitorProcessValue -replace '.*\.CMD\.\$id\.(.+?)\\.*', '$1'

        # Extract the TokenID from TokenHostname
        $TokenID = $TokenHostname -replace '^(.*?)\..*', '$1'

        Write-Host -ForegroundColor Green "Found installed Token. ID: $TokenID"
        
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while searching for Token locally: $($_.Exception.Message)"
    }

    # Set new monitor process to ignore users
    $MonitorProcess = 'cmd.exe /c start /min powershell.exe -windowstyle hidden -command "$($u=$(\"u$env:username\" -replace ''[^a-zA-Z0-9\-]+'', '''')[0..63] -join ''''; $c=$(\"c$env:computername\" -replace ''[^a-zA-Z0-9\-]+'', '''')[0..63] -join ''''; if ($env:username -in @('''+$IgnoreUser+''')) { exit }; $id=\"\"; 1..8 | foreach-object { $id += [Char[]]\"abcdefhijklmnonpqrstuvwxyz0123456789\" | Get-Random }; Resolve-DnsName -Name \"$c.UN.$u.CMD.$id.'+$TokenHostname+'\")"'

   # Create registry keys in both 64-bit and 32-bit hives.
    try {
        # Set trigger process in both hives
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -Value $MonitorProcess -PropertyType String -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -Value $MonitorProcess -PropertyType String -Force -ErrorAction Stop | Out-Null

        Write-Host -ForegroundColor Green "Successfully modified Token to ignore user: $IgnoreUser"   
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while setting registry key: $($_.Exception.Message)"
        Exit
    }
}

# Function to exclude parent process
function Exclude-ParentProcess {
    param (
        [string]$IgnoreProcess,
        [string]$Executable
    )

    Write-Host "Excluding parent process $IgnoreProcess from monitoring process $Executable"

    # Define the registry path
    $RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable"
    
    try {
        # Get the MonitorProcess value from the registry
        $MonitorProcessValue = Get-ItemPropertyValue -Path $RegistryPath -Name "MonitorProcess" -ErrorAction Stop
        
        # Extract the relevant information from the MonitorProcess value
        $TokenHostname = $MonitorProcessValue -replace '.*\.CMD\.\$id\.(.+?)\\.*', '$1'

        # Extract the TokenID from TokenHostname
        $TokenID = $TokenHostname -replace '^(.*?)\..*', '$1'

        Write-Host -ForegroundColor Green "Found installed Token. ID: $TokenID"        
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while searching for Token locally: $($_.Exception.Message)"
    }

    # Set new monitor process to ignore users
    $MonitorProcess = 'cmd.exe /c powershell.exe -windowstyle hidden -Command "$a=(Get-CimInstance -ClassName win32_process -Filter ''ProcessID = %e''); $ppid = $a.ParentProcessID; $ppidc=$(Get-CimInstance Win32_Process -Filter \"ProcessID=$ppid\").CommandLine; if ($ppidc -match '''+$IgnoreProcess+''') { exit } else {$($u=$(\"u$env:username\" -replace(''[^a-zA-Z0-9\-]+'', ''''))[0..63] -join '''';$c=$(\"c$env:computername\" -replace(''[^a-zA-Z0-9\-]+'', ''''))[0..63] -join ''''; $id=\"\"; 1..8 | foreach-object { $id += [Char[]]\"abcdefhijklmnonpqrstuvwxyz0123456789\" | Get-Random }; Resolve-DnsName -Name \"$c.UN.$u.CMD.$id.'+$TokenHostname+'\")"}'

   # Create registry keys in both 64-bit and 32-bit hives.
    try {
        # Set trigger process in both hives
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -Value $MonitorProcess -PropertyType String -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$Executable" -Name "MonitorProcess" -Value $MonitorProcess -PropertyType String -Force -ErrorAction Stop | Out-Null

        Write-Host -ForegroundColor Green "Successfully modified Token to ignore process: $IgnoreProcess"   
    }
    catch {
        Write-Host -ForegroundColor Red "Error occurred while setting registry key: $($_.Exception.Message)"
        Exit
    }
}

# Execute appropriate function based on provided action parameter
switch ($Action.ToLower()) {
    "create" {
        Write-Host "Creating token for $Executable in $Domain"
        Create-Token -Executable $Executable -Domain $Domain -ApiKey $ApiKey
    }
    "delete" {
        Write-Host "Deleting token for $Executable in $Domain"
        Delete-Token -Executable $Executable -Domain $Domain -ApiKey $ApiKey
    }
    "ignoreuser" {
        Write-Host "Ignoring user $IgnoreUser for $Executable"
        Exclude-User -IgnoreUser $IgnoreUser -Executable $Executable
    }
    "ignoreprocess" {
        Write-Host "Ignoring process $IgnoreProcess for $Executable"
        Exclude-ParentProcess -IgnoreProcess $IgnoreProcess -Executable $Executable
    }
    default {
        Write-Host "Invalid action. Please provide a valid action."
    }
}