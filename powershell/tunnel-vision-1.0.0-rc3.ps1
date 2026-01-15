#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tunnel-vision
.DESCRIPTION
    Discovers and analyses the DNS environment to ensure it's ripe for Canary communication.

    Canaries don't communicate directly with a Canary Console and instead make use of DNS Tunnelling.
    This means that they exclusively generate DNS lookups (UDP/53) in order to alert, update and get new settings.

    A typical communication path would originate from the Canary, sent to your internal DNS server
    which then recursively makes its way out to the internet.

    For more information:
    - DNS Communication Overview: https://resources.canary.tools/documents/canary-dns-communication.pdf
    - Communications and Cryptography Whitepaper: https://resources.canary.tools/documents/canary-whitepaper-communications-and-cryptography-v.1.9.pdf
.PARAMETER DnsServer
    Specific DNS server to target (optional). If not provided, uses system DNS servers.
    Ideally this should be set to the DNS server that your Canaries will be using.
.PARAMETER DomainHash
    Your Canary Console domain hash. (default: 6b42426d)
    This is the short hash found in the URL of your Canary Console (e.g. https://ABC123.canary.tools/)
.PARAMETER Verbose
    Enable detailed output to see the actual DNS queries and responses for each test
.EXAMPLE
    .\tunnel-vision.ps1
    Analyses all system DNS servers
.EXAMPLE
    .\tunnel-vision.ps1 -DnsServer 192.2.0.1
.EXAMPLE
    .\tunnel-vision.ps1 -DomainHash abc123
    Targets a specific domain hash.
.EXAMPLE
    .\tunnel-vision.ps1 -Verbose
    Run with detailed output to see actual DNS queries and responses
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DnsServer,

    [Parameter()]
    [string]$DomainHash = "6b42426d"
)

Write-Host @"                                                                                   
   _____________________________________________________
  |Tunnel Vision:                                      |
  |A tool to diagnose the DNS tunnel used by Canaries. |
  |This tool is best paired with a support query.      |
  |Feel free to reach out to support@canary.tools      |
  |_______________  ___________________________________|
     ....        / /
   /[0][0]\      //
  (   \/   )
   )      (
 (          )
(            )
 (          )
  [        ]
 --/\ --- /\-----
---------------
  /   /
 /___/                                                                                        
"@ -ForegroundColor Yellow

Write-Host "=== DNS Environment Discovery ===" -ForegroundColor Cyan
Write-Host "Analyzing your DNS configuration...`n"

# Show if running in verbose mode
if ($VerbosePreference -eq 'Continue') {
    Write-Host "Running in verbose mode (-Verbose enabled)`n" -ForegroundColor Magenta
}

# Helper function for verbose query output
function Write-VerboseQuery {
    param($Query, $Type, $Server = $null)
    if ($VerbosePreference -eq 'Continue') {
        $serverInfo = if ($Server) { " -Server $Server" } else { "" }
        Write-Host "    > Query: $Query (Type: $Type)$serverInfo" -ForegroundColor DarkGray
    }
}

function Write-VerboseResponse {
    param($Response)
    if ($VerbosePreference -eq 'Continue') {
        Write-Host "    < Response:" -ForegroundColor DarkGray
        if ($Response) {
            $Response | ForEach-Object {
                Write-Host "      $_" -ForegroundColor DarkGray
            }
        }
    }
}

# Discover DNS servers from system or use specified server
if ($DnsServer) {
    Write-Host "Using specified DNS server: $DnsServer`n" -ForegroundColor Green
    $dnsServers = @($DnsServer)
}
else {
    $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { $_.ServerAddresses.Count -gt 0 } |
        Select-Object -ExpandProperty ServerAddresses |
        Select-Object -Unique

    if (-not $dnsServers -or $dnsServers.Count -eq 0) {
        Write-Host "ERROR: No DNS servers found on this system" -ForegroundColor Red
        exit 1
    }

    Write-Host "Found $($dnsServers.Count) DNS server(s): $($dnsServers -join ', ')`n" -ForegroundColor Green
}

# Analyse each DNS server
foreach ($dnsIP in $dnsServers) {
    Write-Host "================================================" -ForegroundColor Magenta
    Write-Host "DNS Server: $dnsIP" -ForegroundColor Magenta
    Write-Host "================================================" -ForegroundColor Magenta

    # 1. Reverse DNS Lookup (Hostname)
    Write-Host "`n[1] Hostname:" -ForegroundColor Yellow -NoNewline
    try {
        Write-VerboseQuery -Query $dnsIP -Type "PTR"
        $ptr = Resolve-DnsName -Name $dnsIP -Type PTR -ErrorAction Stop
        $hostname = $ptr.NameHost
        Write-Host " $hostname" -ForegroundColor Cyan
        Write-VerboseResponse -Response $ptr
    }
    catch {
        Write-Host " Not resolvable" -ForegroundColor Gray
        $hostname = $null
    }

    # 2. Response Time
    Write-Host "[2] Response Time:" -ForegroundColor Yellow -NoNewline
    try {
        Write-VerboseQuery -Query "example.com" -Type "A" -Server $dnsIP
        $startTime = Get-Date
        $result = Resolve-DnsName -Name 'example.com' -Server $dnsIP -Type A -ErrorAction Stop
        $responseTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 2)
        Write-Host " ${responseTime}ms" -ForegroundColor Cyan
        Write-VerboseResponse -Response $result
    }
    catch {
        Write-Host " Failed to query" -ForegroundColor Red
        $responseTime = $null
    }

    # 3. Software Identification
    Write-Host "[3] DNS Software:" -ForegroundColor Yellow -NoNewline

    # Try BIND VERSION.BIND query
    $bindDetected = $false
    try {
        $bindVersion = nslookup -type=txt -class=chaos version.bind $dnsIP 2>&1 | Out-String
        if ($bindVersion -match '"([^"]+)"') {
            Write-Host " BIND Version Check: ($($matches[1]))" -ForegroundColor Cyan
            $bindDetected = $true
        }
    }
    catch {
        # Silent fail
    }

    # If not BIND, just show the IP
    if (-not $bindDetected) {
        Write-Host " $dnsIP" -ForegroundColor Gray
    }

    # 4. Name Server Identifier (NSID)
    Write-Host "[4] Name Server ID:" -ForegroundColor Yellow -NoNewline
    try {
        # Use nslookup to query id.server - helps identify which server in a cluster is responding
        $nsidOutput = nslookup -type=txt -class=chaos id.server $dnsIP 2>&1 | Out-String

        if ($nsidOutput -match '"([^"]+)"') {
            Write-Host " $($matches[1])" -ForegroundColor Cyan
        }
        else {
            Write-Host " Not available" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host " Not available" -ForegroundColor Gray
    }

    # 4b. Resolver's Self-Reported Hostname (via PTR query to itself)
    Write-Host "[4b] Resolver Self-Hostname:" -ForegroundColor Yellow -NoNewline
    try {
        # Ask the resolver to do a PTR lookup on its own IP address
        $selfPtr = Resolve-DnsName -Name $dnsIP -Type PTR -Server $dnsIP -ErrorAction Stop
        $selfHostname = $selfPtr.NameHost
        Write-Host " $selfHostname" -ForegroundColor Cyan
    }
    catch {
        Write-Host " Not available" -ForegroundColor Gray
    }

    # 5. Recursion Check
    Write-Host "[5] Recursion:" -ForegroundColor Yellow -NoNewline
    try {
        # Query for a domain that shouldn't be in cache
        $recursionTest = Resolve-DnsName -Name "test-recursion-$(Get-Random).example.com" -Server $dnsIP -Type A -ErrorAction Stop 2>&1
        Write-Host " Enabled" -ForegroundColor Cyan
    }
    catch {
        # Check if the error is due to recursion being disabled vs just NXDOMAIN
        if ($_.Exception.Message -match "refused" -or $_.Exception.Message -match "recursion") {
            Write-Host " Disabled" -ForegroundColor Yellow
        }
        else {
            # NXDOMAIN or other error means recursion worked (it tried to resolve)
            Write-Host " Enabled" -ForegroundColor Cyan
        }
    }

    # 6. Upstream DNS Server (Google)
    Write-Host "[6] Upstream DNS Check (Google):" -ForegroundColor Yellow -NoNewline
    try {
        # Query Google's special TXT record that returns the IP of the resolver
        $upstreamResult = Resolve-DnsName -Name "o-o.myaddr.l.google.com" -Server $dnsIP -Type TXT -ErrorAction Stop
        $upstreamIP = ($upstreamResult.Strings | Select-Object -First 1) -replace '"', ''
        if ($upstreamIP) {
            # Ask the upstream IP itself for its own hostname via PTR
            try {
                $upstreamPtr = Resolve-DnsName -Name $upstreamIP -Type PTR -Server $upstreamIP -ErrorAction Stop
                $upstreamHostname = $upstreamPtr.NameHost
                Write-Host " $upstreamIP ($upstreamHostname)" -ForegroundColor Cyan
            }
            catch {
                Write-Host " $upstreamIP" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host " Unable to detect" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host " Unable to detect" -ForegroundColor Gray
    }

    # 7. Upstream DNS Check (Akamai)
    Write-Host "[7] Upstream DNS Check (Akamai):" -ForegroundColor Yellow -NoNewline
    try {
        # Query Akamai's special record that returns the IP of the resolver
        $akamaiResult = Resolve-DnsName -Name "whoami.akamai.net" -Server $dnsIP -Type A -ErrorAction Stop
        $akamaiIP = $akamaiResult.IPAddress

        if ($akamaiIP) {
            # Ask the upstream IP itself for its own hostname via PTR
            try {
                $akamaiPtr = Resolve-DnsName -Name $akamaiIP -Type PTR -Server $akamaiIP -ErrorAction Stop
                $akamaiHostname = $akamaiPtr.NameHost
                Write-Host " $akamaiIP ($akamaiHostname)" -ForegroundColor Cyan
            }
            catch {
                Write-Host " $akamaiIP" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host " Unable to detect" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host " Unable to detect" -ForegroundColor Gray
    }

    # 8. Public IP Detection
    Write-Host "[8] Public IP:" -ForegroundColor Yellow -NoNewline
    try {
        $whoami = nslookup -type=txt -class=chaos whoami.cloudflare 1.1.1.1 2>&1 | Out-String
        if ($whoami -match '"([^"]+)"') {
            Write-Host " $($matches[1])" -ForegroundColor Cyan
        }
        else {
            Write-Host " Unable to detect" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host " Unable to detect" -ForegroundColor Gray
    }

    Write-Host "`n================================================" -ForegroundColor Magenta
    Write-Host "DNS Resolution & Performance Tests" -ForegroundColor Magenta
    Write-Host "================================================" -ForegroundColor Magenta

    # 9. Basic Resolution Test
    Write-Host "`n[9] Basic Resolution (example.com):" -ForegroundColor Yellow -NoNewline
    try {
        $basicTest = Resolve-DnsName -Name "example.com" -Server $dnsIP -Type A -ErrorAction Stop
        $resolvedIP = $basicTest.IPAddress
        Write-Host " $resolvedIP" -ForegroundColor Cyan
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
    }

    # 10. CNR.io Ping Test
    Write-Host "[10] CNR.io Ping Test:" -ForegroundColor Yellow -NoNewline
    try {
        Write-VerboseQuery -Query "ping.cnr.io" -Type "TXT" -Server $dnsIP
        $cnrPing = Resolve-DnsName -Name "ping.cnr.io" -Server $dnsIP -Type TXT -ErrorAction Stop
        $cnrResponse = ($cnrPing.Strings | Select-Object -First 1) -replace '"', ''
        Write-Host " $cnrResponse" -ForegroundColor Cyan
        Write-VerboseResponse -Response $cnrPing
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
    }

    # 11. Progressive TXT Query Length Test
    Write-Host "[11] Progressive TXT Length Test:" -ForegroundColor Yellow
    $testSizes = @(1, 2, 4, 8, 16, 32, 64, 128, 250)
    foreach ($size in $testSizes) {
        Write-Host "     $size chars:" -ForegroundColor Yellow -NoNewline
        try {
            $queryName = "test.$size.prb.$DomainHash.cnr.io"
            Write-VerboseQuery -Query $queryName -Type "TXT" -Server $dnsIP
            $startTime = Get-Date
            $txtTest = Resolve-DnsName -Name $queryName -Server $dnsIP -Type TXT -ErrorAction Stop
            $queryTime = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 2)
            $txtLength = ($txtTest.Strings | Measure-Object -Property Length -Sum).Sum
            Write-Host " ${queryTime}ms (${txtLength} chars returned)" -ForegroundColor Cyan
            Write-VerboseResponse -Response $txtTest
        }
        catch {
            Write-Host " Failed" -ForegroundColor Red
        }
    }

    # 12. Rate Limit Test
    Write-Host "[12] Rate Limit Test (20 queries @ 250 chars):" -ForegroundColor Yellow -NoNewline
    $successCount = 0
    $failCount = 0
    $totalTime = 0
    for ($i = 1; $i -le 20; $i++) {
        try {
            # Generate 250 characters split into valid DNS labels (max 63 chars per label)
            # Format: test.0.250.{label1}.{label2}.{label3}.{label4}.$DomainHash.cnr.io
            $label1 = -join ((65..90) + (97..122) | Get-Random -Count 63 | ForEach-Object {[char]$_})
            $label2 = -join ((65..90) + (97..122) | Get-Random -Count 63 | ForEach-Object {[char]$_})
            $label3 = -join ((65..90) + (97..122) | Get-Random -Count 63 | ForEach-Object {[char]$_})
            $label4 = -join ((65..90) + (97..122) | Get-Random -Count 61 | ForEach-Object {[char]$_})  # 250 total chars
            $startTime = Get-Date
            $null = Resolve-DnsName -Name "test.0.250.$label1.$label2.$label3.$label4.$DomainHash.cnr.io" -Server $dnsIP -Type TXT -ErrorAction Stop
            $queryTime = ((Get-Date) - $startTime).TotalMilliseconds
            $totalTime += $queryTime
            $successCount++
        }
        catch {
            $failCount++
        }
    }
    $avgTime = if ($successCount -gt 0) { [math]::Round($totalTime / $successCount, 2) } else { 0 }
    Write-Host " $successCount succeeded, $failCount failed (avg ${avgTime}ms)" -ForegroundColor Cyan

    # 13. HTTP Connectivity Test
    Write-Host "[13] HTTP Test ($DomainHash.cnr.io):" -ForegroundColor Yellow -NoNewline
    try {
        $httpResponse = Invoke-WebRequest -Uri "http://$DomainHash.cnr.io" -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        if ($httpResponse.Content -match '<title>([^<]+)</title>') {
            Write-Host " $($matches[1])" -ForegroundColor Cyan
        }
        else {
            Write-Host " Connected (no title found)" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
    }

    # 14. Public IP via HTTPS (Cloudflare)
    Write-Host "[14] Public IP (HTTPS - Cloudflare):" -ForegroundColor Yellow -NoNewline
    try {
        # Check PowerShell version and use appropriate method
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell 6+ (Core/7+) - use -SkipCertificateCheck parameter
            $traceResponse = Invoke-WebRequest -Uri "https://1.1.1.1/cdn-cgi/trace" -UseBasicParsing -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
        }
        else {
            # Windows PowerShell 5.1 - use ServerCertificateValidationCallback
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            
            $code = @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class ServerCertificateValidationCallback {
    public static void Ignore() {
        ServicePointManager.ServerCertificateValidationCallback = 
            delegate (
                object s,
                X509Certificate certificate,
                X509Chain chain,
                SslPolicyErrors sslPolicyErrors
            ) { return true; };
    }
    public static void Restore() {
        ServicePointManager.ServerCertificateValidationCallback = null;
    }
}
"@
            
            if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
                Add-Type -TypeDefinition $code
            }
            
            [ServerCertificateValidationCallback]::Ignore()
            $traceResponse = Invoke-WebRequest -Uri "https://1.1.1.1/cdn-cgi/trace" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            [ServerCertificateValidationCallback]::Restore()
        }

        # Parse the trace response for the IP address
        if ($traceResponse.Content -match 'ip=([^\r\n]+)') {
            $publicIP = $matches[1]
        }
        else {
            $publicIP = "Unable to parse"
        }

        Write-Host " $publicIP" -ForegroundColor Cyan

        # Get certificate info (Windows PowerShell 5.1 only)
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            try {
                $request = [System.Net.HttpWebRequest]::Create("https://1.1.1.1/cdn-cgi/trace")
                $request.Timeout = 10000
                $null = $request.GetResponse()
                $cert = $request.ServicePoint.Certificate

                if ($cert) {
                    $issuerCN = if ($cert.Issuer -match 'CN=([^,]+)') { $matches[1] } else { "Unknown" }
                    $issuerO = if ($cert.Issuer -match 'O=([^,]+)') { $matches[1] } else { "Unknown" }
                    $certInfo = "$issuerCN ($issuerO)"
                    Write-Host "       Cert Issuer: $certInfo" -ForegroundColor Gray
                }
            }
            catch {
                # Silently skip cert info if it fails
            }
        }
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
    }

    Write-Host ""
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Analysis Complete" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan