 <#
.SYNOPSIS
    Deploys a WireGuard Canarytoken via Canary Factory API.

.DESCRIPTION
    This script uses Canary's Factory API to create and download a WireGuard
    configuration Canarytoken. Suitable for deployment via automated tools like SCCM or Intune (MEM). 

.PARAMETER Domain
    The unique domain of your Canary Console (e.g. 1234abc.canary.tools).

.PARAMETER FactoryAuth
    Your Canary Factory authorization string.

.PARAMETER TokenFilename
    Desired file name for the downloaded token (default: 'wg0.conf').

.PARAMETER TargetDirectory
    Local folder where the token will be saved (default: 'C:\Scripts\WireGuard\Configs').

.EXAMPLE
    .\Deploy-CanaryToken.ps1 -Domain 'XYZ123.canary.tools' -FactoryAuth 'ABC123'

    Creates and downloads a wireguard token named 'wg0.conf' into the default directory.

.EXAMPLE
    .\Deploy-CanaryToken.ps1 -Domain 'XYZ123.canary.tools' -FactoryAuth 'ABC123' -TokenFilename 'eu-hq-<HOSTNAME>-wg.conf'

    Substitutes <HOSTNAME> with the actual computer name and saves the token file in the default directory.

.NOTES
    For more details, see:
    https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    https://docs.canary.tools/canarytokens/factory.html#list-canarytokens-available-via-canarytoken-factory
#>

[CmdletBinding()]
Param (
    [string]$Domain = 'XYZ123.canary.tools',
    [string]$FactoryAuth = 'ABC123',
    [string]$TokenFilename = 'vpn-gw3-<HOSTNAME>-wg.conf',
    [string]$TargetDirectory = "C:\Scripts\WireGuard\Configs"
)

# Enforce TLS1.2 for the web requests, the Thinkst Canary Console API does not support lower
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# If you must keep StrictMode v2 for legacy reasons; otherwise you could use v3 or v4
Set-StrictMode -Version 4

function Deploy-WG {
    [CmdletBinding()]
    param (
        [string]$Domain,
        [string]$FactoryAuth,
        [string]$TokenFilename,
        [string]$TargetDirectory
    )
    process {
        Write-Verbose "Starting token deployment."

        $HostName      = $env:COMPUTERNAME # Only used if hostname is substituted in filename
        $HostNameFQDN  = [System.Net.Dns]::GetHostName() # Used in token Reminder field

        # Replace literal '<HOSTNAME>' in TokenFilename
        if ($TokenFilename -match '<HOSTNAME>') {
            Write-Verbose "Replacing <HOSTNAME> in the token filename."
            $TokenFilename = $TokenFilename -replace '<HOSTNAME>', $HostName
        }

        # Ensure target directory does not end with a backslash
        if ($TargetDirectory -match '\\$') {
            $TargetDirectory = $TargetDirectory.TrimEnd('\')
        }

        $OutputFileName = Join-Path -Path $TargetDirectory -ChildPath $TokenFilename
        Write-Verbose "Final output file path: $OutputFileName"

        # If the token already exists, skip
        if (Test-Path $OutputFileName) {
            Write-Warning "Token '$OutputFileName' already exists. Skipping..."
            return
        }

        # Create directory if it doesn't exist
        if (!(Test-Path $TargetDirectory)) {
            Write-Verbose "Creating directory: $TargetDirectory"
            try {
                New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null
            }
            catch {
                Write-Error "Failed to create directory: $TargetDirectory. `n$($_.Exception.Message)"
                return
            }
        }

        # Build the post data
        $PostData = @{
            factory_auth = $FactoryAuth
            kind         = 'wireguard'
            memo         = "$HostNameFQDN|$OutputFileName" # Using delimiter '|'
        }

        Write-Verbose "Creating token via Factory API..."

        # Make API request in a try/catch for better error handling
        try {
            $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
        }
        catch {
            Write-Error "Failed to invoke REST method for token creation: $($_.Exception.Message)"
            return
        }

        # Validate the result
        if ($CreateResult.result -ne 'success') {
            Write-Error "Creation of $OutputFileName failed on $HostNameFQDN. (Result: $($CreateResult.result))"
            return
        }
        
        $TokenID = $CreateResult.canarytoken.canarytoken
        Write-Verbose "Token creation successful. Token ID: $TokenID"

        # Download the token
        Write-Verbose "Downloading token..."
        $DownloadUri = "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID"

        try {
            Invoke-RestMethod -Method Get -Uri $DownloadUri -OutFile $OutputFileName
        }
        catch {
            Write-Error "Failed to download token: $($_.Exception.Message)"
            return
        }

        Write-Output "[*] Canarytoken saved to: '$OutputFileName' on $HostNameFQDN"
    }
}

# Main script execution
Write-Verbose "Script parameters: Domain=$Domain, FactoryAuth=$FactoryAuth, TokenFilename=$TokenFilename, TargetDirectory=$TargetDirectory"
Deploy-WG -Domain $Domain -FactoryAuth $FactoryAuth -TokenFilename $TokenFilename -TargetDirectory $TargetDirectory -Verbose
