# Complete Certificate Generation and Code Signing Script
# CDP and AIA extensions with proper ASN.1 DER encoding matching Python cryptography library
# Requires elevation (Run as Administrator)

function New-TokenedCertificate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TokenUrl,
        
        [Parameter(Mandatory=$false)]
        [string]$CDPUrl,
        
        [Parameter(Mandatory=$false)]
        [string]$AIAUrl,
        
        [Parameter(Mandatory=$false)]
        [string]$OrgName = "Thinkst",
        
        [Parameter(Mandatory=$false)]
        [string]$ComputerName = "Microsoft Windows",
        
        [Parameter(Mandatory=$false)]
        [int]$ValidYears = 10,
        
        [Parameter(Mandatory=$false)]
        [switch]$ForCodeSigning
    )
    
    # If specific URLs not provided, use TokenUrl for both
    if (-not $CDPUrl) { $CDPUrl = $TokenUrl }
    if (-not $AIAUrl) { $AIAUrl = $TokenUrl }
    
    # Validate URLs
    if (-not $CDPUrl.StartsWith("http://") -and -not $CDPUrl.StartsWith("https://")) {
        Write-Error "CDPUrl must start with http:// or https://"
        return
    }
    if (-not $AIAUrl.StartsWith("http://") -and -not $AIAUrl.StartsWith("https://")) {
        Write-Error "AIAUrl must start with http:// or https://"
        return
    }
    
    Write-Host ("CDP URL: " + $CDPUrl) -ForegroundColor Cyan
    Write-Host ("AIA URL: " + $AIAUrl) -ForegroundColor Cyan
    
    # Generate Root CA
    Write-Host "Generating Root CA..." -ForegroundColor Green
    $rootCert = New-RootCA -OrgName $OrgName -ValidYears $ValidYears
    
    # Export Root CA to PFX
    $rootPfxPath = Join-Path $PSScriptRoot "root.pfx"
    $rootPassword = ConvertTo-SecureString -String "password" -Force -AsPlainText
    Export-PfxCertificate -Cert $rootCert -FilePath $rootPfxPath -Password $rootPassword | Out-Null
    Write-Host ("Root CA exported to: " + $rootPfxPath) -ForegroundColor Cyan
    
    # Generate Leaf Certificate with Token
    Write-Host "Generating leaf certificate with token..." -ForegroundColor Green
    $leafCert = New-LeafCertificate -Issuer $rootCert -CDPUrl $CDPUrl -AIAUrl $AIAUrl -ComputerName $ComputerName -ValidYears $ValidYears -ForCodeSigning:$ForCodeSigning
    
    # Export Leaf Certificate to PFX
    $leafPfxPath = Join-Path $PSScriptRoot "cert.pfx"
    $leafPassword = ConvertTo-SecureString -String "password" -Force -AsPlainText
    Export-PfxCertificate -Cert $leafCert -FilePath $leafPfxPath -Password $leafPassword | Out-Null
    Write-Host ("Leaf certificate exported to: " + $leafPfxPath) -ForegroundColor Cyan
    
    # Display certificate thumbprint
    $thumbprint = $leafCert.Thumbprint
    Write-Host ""
    Write-Host ("Leaf Certificate Thumbprint: " + $thumbprint) -ForegroundColor Yellow
    
    if ($ForCodeSigning) {
        Write-Host "Certificate configured for code signing" -ForegroundColor Green
    }
    
    # Verify extensions were added
    Write-Host ""
    Write-Host "Verifying extensions..." -ForegroundColor Yellow
    $hasAIA = $false
    $hasCDP = $false
    
    foreach ($ext in $leafCert.Extensions) {
        if ($ext.Oid.Value -eq "1.3.6.1.5.5.7.1.1") {
            $hasAIA = $true
            Write-Host "  [OK] AIA Extension found" -ForegroundColor Green
        }
        if ($ext.Oid.Value -eq "2.5.29.31") {
            $hasCDP = $true
            Write-Host "  [OK] CDP Extension found" -ForegroundColor Green
        }
    }
    
    if (-not $hasAIA) { Write-Warning "  [!] AIA Extension NOT found" }
    if (-not $hasCDP) { Write-Warning "  [!] CDP Extension NOT found" }
    
    return @{
        RootCertificate = $rootCert
        LeafCertificate = $leafCert
        RootPfxPath = $rootPfxPath
        LeafPfxPath = $leafPfxPath
        Thumbprint = $thumbprint
    }
}

function New-RootCA {
    param(
        [string]$OrgName,
        [int]$ValidYears
    )
    
    # Create distinguished name for root CA
    $rootDN = "CN=" + $OrgName + " Root CA, O=" + $OrgName + ", L=Cape Town, S=Western Cape, C=ZA"
    
    # Create certificate request for root CA
    $rootParams = @{
        Subject = $rootDN
        KeyAlgorithm = "RSA"
        KeyLength = 2048
        HashAlgorithm = "SHA256"
        KeyUsage = @("CertSign", "CRLSign", "DigitalSignature", "KeyEncipherment")
        KeyExportPolicy = "Exportable"
        NotAfter = (Get-Date).AddYears($ValidYears)
        CertStoreLocation = "Cert:\CurrentUser\My"
        Type = "Custom"
        Extension = @(
            # Basic Constraints - CA:TRUE
            New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension($true, $false, 0, $true)
        )
    }
    
    $rootCert = New-SelfSignedCertificate @rootParams
    return $rootCert
}

function New-LeafCertificate {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Issuer,
        [string]$CDPUrl,
        [string]$AIAUrl,
        [string]$ComputerName,
        [int]$ValidYears,
        [switch]$ForCodeSigning
    )
    
    # Create distinguished name for leaf certificate
    $leafDN = "CN=" + $ComputerName + ", L=San Francisco, S=California, C=US"
    
    # Create AIA extension (Authority Information Access)
    $aiaExtension = New-AIAExtension -Url $AIAUrl
    Write-Host "  AIA Extension created" -ForegroundColor DarkGray
    
    # Create CDP extension (CRL Distribution Points)
    $cdpExtension = New-CDPExtension -Url $CDPUrl
    Write-Host "  CDP Extension created" -ForegroundColor DarkGray
    
    # Build text extensions array
    $textExtensions = @(
        $aiaExtension,
        $cdpExtension
    )
    
    # Add Enhanced Key Usage based on purpose
    if ($ForCodeSigning) {
        # Code Signing EKU (1.3.6.1.5.5.7.3.3)
        $textExtensions += "2.5.29.37={text}1.3.6.1.5.5.7.3.3"
    } else {
        # Client Auth and Server Auth
        $textExtensions += "2.5.29.37={text}1.3.6.1.5.5.7.3.2,1.3.6.1.5.5.7.3.1"
    }
    
    # Create certificate
    $leafParams = @{
        Subject = $leafDN
        Signer = $Issuer
        KeyAlgorithm = "RSA"
        KeyLength = 2048
        HashAlgorithm = "SHA256"
        KeyUsage = @("DigitalSignature", "KeyEncipherment")
        TextExtension = $textExtensions
        KeyExportPolicy = "Exportable"
        NotAfter = (Get-Date).AddYears($ValidYears)
        CertStoreLocation = "Cert:\CurrentUser\My"
    }
    
    $leafCert = New-SelfSignedCertificate @leafParams
    return $leafCert
}

function Get-DERLength {
    param([int]$Length)
    
    if ($Length -le 127) {
        # Short form: length fits in 7 bits
        return "{0:X2}" -f $Length
    } elseif ($Length -le 255) {
        # Long form: 1 byte for length
        return "81{0:X2}" -f $Length
    } else {
        # Long form: 2 bytes for length
        $high = [Math]::Floor($Length / 256)
        $low = $Length % 256
        return "82{0:X2}{1:X2}" -f $high, $low
    }
}

function New-AIAExtension {
    param([string]$Url)
    
    # Authority Information Access (AIA) extension
    # OID 1.3.6.1.5.5.7.1.1 (id-pe-authorityInfoAccess)
    $aiaOid = "1.3.6.1.5.5.7.1.1"
    
    # Convert URL to hex
    $urlBytes = [System.Text.Encoding]::ASCII.GetBytes($Url)
    $urlHex = ($urlBytes | ForEach-Object { $_.ToString("X2") }) -join ""
    
    # CA Issuers access method OID: 1.3.6.1.5.5.7.48.2
    $caIssuersOid = "06082B06010505073002"
    
    # Build URL as [6] IMPLICIT IA5String (uniformResourceIdentifier)
    $urlLen = Get-DERLength -Length $urlBytes.Length
    $urlEncoded = "86" + $urlLen + $urlHex
    
    # Build AccessDescription SEQUENCE { accessMethod OID, accessLocation GeneralName }
    $accessDescContent = $caIssuersOid + $urlEncoded
    $accessDescLen = Get-DERLength -Length ($accessDescContent.Length / 2)
    $accessDescEncoded = "30" + $accessDescLen + $accessDescContent
    
    # Wrap in SEQUENCE OF (AuthorityInfoAccessSyntax)
    $seqLen = Get-DERLength -Length ($accessDescEncoded.Length / 2)
    $aiaValue = "30" + $seqLen + $accessDescEncoded
    
    return $aiaOid + "={hex}" + $aiaValue
}

function New-CDPExtension {
    param([string]$Url)
    
    # CRL Distribution Points extension - OID 2.5.29.31
    $cdpOid = "2.5.29.31"
    
    # Convert URL to hex
    $urlBytes = [System.Text.Encoding]::ASCII.GetBytes($Url)
    $urlHex = ($urlBytes | ForEach-Object { $_.ToString("X2") }) -join ""
    
    # Step 1: Build URL as [6] uniformResourceIdentifier (GeneralName)
    $urlLen = Get-DERLength -Length $urlBytes.Length
    $generalName = "86" + $urlLen + $urlHex
    
    # Step 2: GeneralNames is a SEQUENCE OF GeneralName (even for one item)
    # But when used as fullName [0], it's IMPLICIT, so we skip the SEQUENCE tag
    # and go directly to wrapping with [0]
    
    # Step 3: Wrap with [0] for fullName (which is [0] IMPLICIT GeneralNames)
    # Tag A0 = [0] context-specific constructed
    $fullNameLen = Get-DERLength -Length ($generalName.Length / 2)
    $fullName = "A0" + $fullNameLen + $generalName
    
    # Step 4: Now wrap with [0] again for distributionPoint field
    # This time it's [0] EXPLICIT DistributionPointName
    # Which becomes: A0 len A0 len URI
    $dpFieldLen = Get-DERLength -Length ($fullName.Length / 2)
    $dpField = "A0" + $dpFieldLen + $fullName
    
    # Step 5: Wrap in SEQUENCE (DistributionPoint)
    $dpSeqLen = Get-DERLength -Length ($dpField.Length / 2)
    $dpSeq = "30" + $dpSeqLen + $dpField
    
    # Step 6: Wrap in SEQUENCE OF (CRLDistributionPoints)
    $outerSeqLen = Get-DERLength -Length ($dpSeq.Length / 2)
    $cdpValue = "30" + $outerSeqLen + $dpSeq
    
    return $cdpOid + "={hex}" + $cdpValue
}

function New-SimpleExe {
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$false)]
        [string]$Message = "Hello from signed executable!"
    )
    
    Write-Host "Creating simple executable..." -ForegroundColor Green
    
    # Create a simple C# program
    $csharpCode = @"
using System;
using System.Windows.Forms;

namespace SignedApp
{
    class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            MessageBox.Show("$Message", "Signed Application", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
}
"@

    try {
        # Compile the C# code
        Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.Windows.Forms -OutputAssembly $OutputPath -OutputType ConsoleApplication
        
        if (Test-Path $OutputPath) {
            Write-Host ("Executable created: " + $OutputPath) -ForegroundColor Green
            return $true
        } else {
            Write-Error "Failed to create executable"
            return $false
        }
    } catch {
        Write-Error ("Error creating executable: " + $_)
        return $false
    }
}

function Sign-ExecutableWithToken {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExePath,
        
        [Parameter(Mandatory=$true)]
        [string]$CertificateThumbprint,
        
        [Parameter(Mandatory=$false)]
        [string]$TimestampServer = "http://timestamp.digicert.com",
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "Signed Application"
    )
    
    # Verify the executable exists
    if (-not (Test-Path $ExePath)) {
        Write-Error ("Executable not found: " + $ExePath)
        return $false
    }
    
    # Find the certificate in the store
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    
    if (-not $cert) {
        Write-Error ("Certificate with thumbprint " + $CertificateThumbprint + " not found in CurrentUser\My store")
        return $false
    }
    
    Write-Host ("Signing executable: " + $ExePath) -ForegroundColor Green
    Write-Host ("Using certificate: " + $cert.Subject) -ForegroundColor Cyan
    
    try {
        # Sign the executable
        $result = Set-AuthenticodeSignature -FilePath $ExePath -Certificate $cert -TimestampServer $TimestampServer -HashAlgorithm SHA256
        
        if ($result.Status -eq "Valid" -or $result.Status -eq "UnknownError") {
            Write-Host ("Successfully signed: " + $ExePath) -ForegroundColor Green
            Write-Host ("Signature Status: " + $result.Status) -ForegroundColor Green
            return $true
        } else {
            Write-Warning ("Signing status: " + $result.Status)
            return $true
        }
    } catch {
        Write-Error ("Error signing executable: " + $_)
        return $false
    }
}

function Sign-ExecutableWithPfx {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExePath,
        
        [Parameter(Mandatory=$true)]
        [string]$PfxPath,
        
        [Parameter(Mandatory=$true)]
        [SecureString]$PfxPassword,
        
        [Parameter(Mandatory=$false)]
        [string]$TimestampServer = "http://timestamp.digicert.com"
    )
    
    # Verify files exist
    if (-not (Test-Path $ExePath)) {
        Write-Error ("Executable not found: " + $ExePath)
        return $false
    }
    
    if (-not (Test-Path $PfxPath)) {
        Write-Error ("PFX file not found: " + $PfxPath)
        return $false
    }
    
    try {
        # Import the certificate
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($PfxPath, $PfxPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
        
        Write-Host ("Signing executable: " + $ExePath) -ForegroundColor Green
        Write-Host ("Using certificate: " + $cert.Subject) -ForegroundColor Cyan
        
        # Sign the executable
        $result = Set-AuthenticodeSignature -FilePath $ExePath -Certificate $cert -TimestampServer $TimestampServer -HashAlgorithm SHA256
        
        if ($result.Status -eq "Valid" -or $result.Status -eq "UnknownError") {
            Write-Host ("Successfully signed: " + $ExePath) -ForegroundColor Green
            return $true
        } else {
            Write-Warning ("Signing status: " + $result.Status)
            return $true
        }
    } catch {
        Write-Error ("Error signing executable: " + $_)
        return $false
    }
}

function Verify-ExecutableSignature {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExePath
    )
    
    if (-not (Test-Path $ExePath)) {
        Write-Error ("Executable not found: " + $ExePath)
        return
    }
    
    $signature = Get-AuthenticodeSignature -FilePath $ExePath
    
    Write-Host ""
    Write-Host "========================================"  -ForegroundColor Cyan
    Write-Host "Signature Verification" -ForegroundColor Cyan
    Write-Host "========================================"  -ForegroundColor Cyan
    Write-Host ("File: " + $ExePath) -ForegroundColor Yellow
    $statusColor = "Yellow"
    if ($signature.Status -eq "Valid") {
        $statusColor = "Green"
    }
    Write-Host ("Status: " + $signature.Status) -ForegroundColor $statusColor
    
    if ($signature.SignerCertificate) {
        Write-Host ""
        Write-Host "Certificate Information:" -ForegroundColor Yellow
        Write-Host ("  Subject: " + $signature.SignerCertificate.Subject) -ForegroundColor Cyan
        Write-Host ("  Issuer: " + $signature.SignerCertificate.Issuer) -ForegroundColor Cyan
        Write-Host ("  Thumbprint: " + $signature.SignerCertificate.Thumbprint) -ForegroundColor Cyan
        Write-Host ("  Valid From: " + $signature.SignerCertificate.NotBefore) -ForegroundColor Cyan
        Write-Host ("  Valid To: " + $signature.SignerCertificate.NotAfter) -ForegroundColor Cyan
        
        # Show extensions
        Write-Host ""
        Write-Host "Certificate Extensions:" -ForegroundColor Yellow
        $hasAIA = $false
        $hasCDP = $false
        
        foreach ($ext in $signature.SignerCertificate.Extensions) {
            if ($ext.Oid.Value -eq "2.5.29.31") {
                Write-Host "  [OK] CRL Distribution Points (CDP)" -ForegroundColor Green
                $hasCDP = $true
            }
            elseif ($ext.Oid.Value -eq "1.3.6.1.5.5.7.1.1") {
                Write-Host "  [OK] Authority Information Access (AIA)" -ForegroundColor Green
                $hasAIA = $true
            }
            elseif ($ext.Oid.Value -eq "2.5.29.37") {
                Write-Host "  [OK] Enhanced Key Usage" -ForegroundColor Green
            }
        }
        
        if (-not $hasAIA) { Write-Host "  [!] AIA Extension NOT found" -ForegroundColor Red }
        if (-not $hasCDP) { Write-Host "  [!] CDP Extension NOT found" -ForegroundColor Red }
    }
    
    if ($signature.TimeStamperCertificate) {
        Write-Host ""
        Write-Host ("Timestamp: " + $signature.TimeStamperCertificate.NotBefore) -ForegroundColor Cyan
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    return $signature
}

function Show-CertificateExtensions {
    param(
        [Parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Certificate Extensions" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("Subject: " + $Certificate.Subject) -ForegroundColor Yellow
    Write-Host ("Thumbprint: " + $Certificate.Thumbprint) -ForegroundColor Yellow
    
    foreach ($ext in $Certificate.Extensions) {
        Write-Host ""
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Host ("OID: " + $ext.Oid.Value) -ForegroundColor Cyan
        Write-Host ("Name: " + $ext.Oid.FriendlyName) -ForegroundColor Cyan
        Write-Host ("Critical: " + $ext.Critical) -ForegroundColor Cyan
        
        # Decode specific extensions
        if ($ext.Oid.Value -eq "2.5.29.31") {
            Write-Host "Type: CRL Distribution Points (CDP)" -ForegroundColor Green
        }
        elseif ($ext.Oid.Value -eq "1.3.6.1.5.5.7.1.1") {
            Write-Host "Type: Authority Information Access (AIA)" -ForegroundColor Green
        }
        elseif ($ext.Oid.Value -eq "2.5.29.37") {
            Write-Host "Type: Enhanced Key Usage" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Remove-TokenedCertificates {
    param(
        [Parameter(Mandatory=$true)]
        $CertificateInfo
    )

    Write-Host ""
    Write-Host "Cleaning up generated certificates..." -ForegroundColor Yellow

    # Remove from CurrentUser\My store
    $thumbprints = @()

    if ($CertificateInfo.RootCertificate -and $CertificateInfo.RootCertificate.Thumbprint) {
        $thumbprints += $CertificateInfo.RootCertificate.Thumbprint
    }
    if ($CertificateInfo.LeafCertificate -and $CertificateInfo.LeafCertificate.Thumbprint) {
        $thumbprints += $CertificateInfo.LeafCertificate.Thumbprint
    }

    foreach ($thumb in $thumbprints) {
        $path = "Cert:\CurrentUser\My\" + $thumb
        if (Test-Path $path) {
            Write-Host ("  Removing certificate from store: " + $thumb) -ForegroundColor Cyan
            try {
                Remove-Item -Path $path -Force
            } catch {
                Write-Warning ("  Failed to remove " + $thumb + " from store: " + $_)
            }
        } else {
            Write-Host ("  Certificate not found in store: " + $thumb) -ForegroundColor DarkGray
        }
    }

    # Remove PFX files if present
    $pfxPaths = @()
    if ($CertificateInfo.RootPfxPath)  { $pfxPaths += $CertificateInfo.RootPfxPath }
    if ($CertificateInfo.LeafPfxPath)  { $pfxPaths += $CertificateInfo.LeafPfxPath }

    foreach ($p in $pfxPaths) {
        if ($p -and (Test-Path $p)) {
            Write-Host ("  Deleting PFX file: " + $p) -ForegroundColor Cyan
            try {
                Remove-Item -Path $p -Force
            } catch {
                Write-Warning ("  Failed to delete PFX file " + $p + ": " + $_)
            }
        }
    }

    Write-Host "Cleanup complete." -ForegroundColor Green
}

function New-SignedExecutable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TokenUrl,
        
        [Parameter(Mandatory=$false)]
        [string]$CDPUrl,
        
        [Parameter(Mandatory=$false)]
        [string]$AIAUrl,
        
        [Parameter(Mandatory=$false)]
        [string]$ExePath = ".\SignedApp.exe",
        
        [Parameter(Mandatory=$false)]
        [string]$OrgName = "MyCompany",
        
        [Parameter(Mandatory=$false)]
        [string]$Message = "This is a signed executable with token callbacks!",

        [Parameter(Mandatory=$false)]
        [switch]$Cleanup
    )
    
    # If specific URLs not provided, use TokenUrl for both
    if (-not $CDPUrl) { $CDPUrl = $TokenUrl }
    if (-not $AIAUrl) { $AIAUrl = $TokenUrl }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Complete Workflow: Create, Sign, Verify" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Create the executable
    Write-Host "[1/4] Creating executable..." -ForegroundColor Yellow
    $exeCreated = New-SimpleExe -OutputPath $ExePath -Message $Message
    
    if (-not $exeCreated) {
        Write-Error "Failed to create executable. Aborting."
        return
    }
    
    # Step 2: Create code signing certificate
    Write-Host ""
    Write-Host "[2/4] Creating code signing certificate with token..." -ForegroundColor Yellow
    $certResult = New-TokenedCertificate -TokenUrl $TokenUrl -CDPUrl $CDPUrl -AIAUrl $AIAUrl -OrgName $OrgName -ComputerName "Code Signing Certificate" -ForCodeSigning
    
    if (-not $certResult) {
        Write-Error "Failed to create certificate. Aborting."
        return
    }
    
    # Step 3: Sign the executable
    Write-Host ""
    Write-Host "[3/4] Signing executable..." -ForegroundColor Yellow
    $signed = Sign-ExecutableWithToken -ExePath $ExePath -CertificateThumbprint $certResult.Thumbprint
    
    if (-not $signed) {
        Write-Error "Failed to sign executable."
        return
    }
    
    # Step 4: Verify signature
    Write-Host ""
    Write-Host "[4/4] Verifying signature..." -ForegroundColor Yellow
    Verify-ExecutableSignature -ExePath $ExePath
    
    # Summary
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("CDP URL: " + $CDPUrl) -ForegroundColor Green
    Write-Host ("AIA URL: " + $AIAUrl) -ForegroundColor Green
    Write-Host ("Executable: " + $ExePath) -ForegroundColor Green
    Write-Host ("Certificate PFX: " + $certResult.LeafPfxPath) -ForegroundColor Green
    Write-Host ("Root CA PFX: " + $certResult.RootPfxPath) -ForegroundColor Green
    Write-Host "PFX Password: password" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "When Windows validates the signature, it will" -ForegroundColor Cyan
    Write-Host "make HTTP requests to the CDP and AIA URLs" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Cleanup prompt / auto-clean
    $doCleanup = $false

    if ($Cleanup) {
        # Auto-clean, no prompt
        $doCleanup = $true
    } else {
        $answer = Read-Host "Remove generated certificates and PFX files now? (Y/N)"
        if ($answer -match '^[Yy]') {
            $doCleanup = $true
        }
    }

    if ($doCleanup) {
        Remove-TokenedCertificates -CertificateInfo $certResult
    }

    return @{
        ExecutablePath = $ExePath
        Certificate    = $certResult
    }
}

# Display usage information
Write-Host ""
Write-Host "Certificate Generator Script Loaded" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Available Functions:" -ForegroundColor Yellow
Write-Host "  New-SignedExecutable       - Complete workflow (create cert + exe + sign)"
Write-Host "  New-TokenedCertificate     - Create certificate only"
Write-Host "  New-SimpleExe              - Create executable only"
Write-Host "  Sign-ExecutableWithToken   - Sign with certificate from store"
Write-Host "  Sign-ExecutableWithPfx     - Sign with PFX file"
Write-Host "  Verify-ExecutableSignature - Verify signature"
Write-Host "  Show-CertificateExtensions - Display certificate extensions"
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Cyan
Write-Host '  New-SignedExecutable -TokenUrl "http://your-server.com/alert"' -ForegroundColor White
Write-Host ""
Write-Host '  New-SignedExecutable `  ' -ForegroundColor White
Write-Host '    -TokenUrl "http://default.com" ` ' -ForegroundColor White
Write-Host '    -CDPUrl "http://crl.example.com/mycrl.crl" `' -ForegroundColor White
Write-Host '    -AIAUrl "http://aia.example.com/myca.crt" -Cleanup' -ForegroundColor White
Write-Host ""
