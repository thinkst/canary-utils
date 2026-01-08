 <#
.SYNOPSIS
    Deploys a WireGuard Canarytoken via Console API.

.DESCRIPTION
    Creates and saves a WireGuard Canarytoken config using the Canary Console API.
    Suitable for SCCM/Intune deployment.

.PARAMETER Domain
    The unique domain of your Canary Console (e.g. 1234abc.canary.tools).

.PARAMETER CDK
    Canarytoken Deploy API Key.

.PARAMETER TokenFilename
    File name for the downloaded token (default: 'vpn-gw3-<HOSTNAME>-wg.conf').

.PARAMETER TargetDirectory
    Folder where the token will be saved. (default: 'C:\Scripts\WireGuard\Configs').

.PARAMETER Force
    Overwrite an existing token file.

.EXAMPLE
    .\Deploy-CanaryToken.ps1 -Domain 'XYZ123.canary.tools' -CDK 'ABC123'

    Creates and downloads a wireguard token named 'wg0.conf' into the default directory.

.EXAMPLE
    .\Deploy-CanaryToken.ps1 -Domain 'XYZ123.canary.tools' -CDK 'ABC123' -TokenFilename 'eu-hq-<HOSTNAME>-wg.conf'

    Substitutes <HOSTNAME> with the actual computer name and saves the token file in the default directory.

.NOTES
    For more details, see: Flock API Keys - https://help.canary.tools/hc/en-gb/articles/7111549805213-Flock-API-Keys
#>

[CmdletBinding()]
Param (
    [string]$Domain = 'xyz123.canary.tools',
    [string]$CDK = 'abc123abc', # Canarytoken Deploy Key
    [string]$TokenFilename = 'vpn-gw3-<HOSTNAME>-wg.conf',
    [string]$TargetDirectory = "C:\Scripts\WireGuard\Configs",
    [bool]$Force = $false
)

# Enforce TLS1.2 for the web requests, the Thinkst Canary Console API does not support lower
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Set-StrictMode -Version 4

function Deploy-WG {
    [CmdletBinding()]
    param (
        [string]$Domain,
        [string]$CDK,
        [string]$TokenFilename,
        [string]$TargetDirectory,
        [bool]$Force
    )
    process {
        Write-Verbose "Starting token deployment."

        $HostName = $env:COMPUTERNAME # Only used if hostname is substituted in filename

        if ($TokenFilename -match '<HOSTNAME>') {
            Write-Verbose "Replacing <HOSTNAME> in the token filename."
            $TokenFilename = $TokenFilename -replace '<HOSTNAME>', $HostName
        }

        $TargetDirectory = $TargetDirectory.TrimEnd('\')
        $OutputFileName = Join-Path -Path $TargetDirectory -ChildPath $TokenFilename

        Write-Verbose "Final output file path: $OutputFileName"

        # If the token already exists, skip
        if ((Test-Path $OutputFileName) -and -not $Force) {
            Write-Warning "Token '$OutputFileName' already exists. Skipping (use -Force:$true to overwrite)."
            return
        }

        # Create directory if it doesn't exist
        if (!(Test-Path $TargetDirectory)) {
            Write-Verbose "Creating directory: $TargetDirectory"
            New-Item -ItemType Directory -Force -Path $TargetDirectory -ErrorAction Stop | Out-Null
        }

        $PostData = @{
            kind         = 'wireguard'
            memo         = "$HostName|$OutputFileName" # Using delimiter '|'
        }
        
         # Prepare base parameters
        $invokeParams = @{
            Method         = 'Post'
            Uri            = "https://$Domain/api/v1/canarytoken/create"
            Body           = $PostData
            Headers = @{'X-Canary-Auth-Token' = $CDK}
            ErrorAction = 'Stop'
        }

        # Basic retry
        $CreateResult = $null
        for ($i = 1; $i -le 3; $i++) {
            try {
                $CreateResult = Invoke-RestMethod @invokeParams
                break
            } catch {
                Write-Warning "Attempt $i/3 failed: $($_.Exception.Message)"
                if ($i -eq 3) { throw }
                Start-Sleep -Seconds (2 * $i)
            }
        }

        if ($CreateResult.result -ne 'success') {
            throw "Token creation failed. Result: $($CreateResult.result)"
        }

        $TokenID   = $CreateResult.canarytoken.canarytoken
        $WG_Config = $CreateResult.canarytoken.renders.wg_conf

        if ([string]::IsNullOrWhiteSpace($WG_Config)) {
            throw "Token created (ID: $TokenID) but wg_conf was empty or missing."
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($OutputFileName, $WG_Config, $utf8NoBom)
        
        Write-Verbose "Token creation successful. Token ID: $TokenID"
        Write-Output "[*] Canarytoken saved to: '$OutputFileName' on $HostName"
    }
}

Write-Verbose "Script parameters: Domain=$Domain, CDK=$CDK, TokenFilename=$TokenFilename, TargetDirectory=$TargetDirectory"
Deploy-WG -Domain $Domain -CDK $CDK -TokenFilename $TokenFilename -TargetDirectory $TargetDirectory -Force:$Force -Verbose
