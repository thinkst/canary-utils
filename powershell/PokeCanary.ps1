<#
.SYNOPSIS
    Triggers various actions to generate Canary alerts,
    It will read the list of canaries to be poked from a text file (canaries.txt by default),
    Each line in that text file should be a canary IP or hostname

.NOTES
    Last Edit: 28-07-2023
    Version 1.0 - initial release
    Version 1.1 - Add support for SharePoint Skin
    Version 1.2 - Github Release
#>

param (
    [string]$CanariesFile = "canaries.txt"
)

# Invoke-PokeCanary function
function Invoke-PokeCanary {
    param (
        [string]$Canary
    )
    Write-Host -ForegroundColor Green "[+] Poking $Canary ..."

    Invoke-PortScanAlert -Canary $Canary
    Invoke-SMBShareAlert -Canary $Canary
    Invoke-HTTPLoginAlert -Canary $Canary
    Invoke-LDAPAlert -Canary $Canary
    Invoke-FTPAlert -Canary $Canary
}

function Invoke-PortScanAlert 
{
    param (
        [string]$Canary
    )
    # port scanning...
    Write-Host -ForegroundColor Yellow "[!] Poke: Port scanning $Canary."
    $ports = @(80, 8080, 22, 21, 1433)
    $ports | ForEach-Object {
        (New-Object Net.Sockets.TcpClient).Connect($Canary, $_)
    }
}

function Invoke-FTPAlert ()
{

 param (
        [string]$Canary
    )

$SavedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

    Try
    {
        # Config
        $Username = "FTPUSER"
        $Password = "P@assw0rd"
        #$LocalFile = "C:\Temp\file.zip"
        $RemoteFile = "ftp://" + $Canary + "/downloads/files/file.zip"
 
        # Create a FTPWebRequest
        $FTPRequest = [System.Net.FtpWebRequest]::Create($RemoteFile)
        $FTPRequest.Credentials = New-Object System.Net.NetworkCredential($Username,$Password)
        $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $FTPRequest.UseBinary = $true
        $FTPRequest.KeepAlive = $false
        # Send the ftp request
        $FTPRequest.kee
        $FTPResponse = $FTPRequest.GetResponse()
    }
    catch
    {
        Write-Warning "ftp err0r"
    }

$ErrorActionPreference = $SavedErrorActionPreference 
  
}

function Invoke-LDAPAlert ()
{

 param (
        [string]$Canary
    )

    $SavedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop" 

    Try
    {
        # Needs reference to .NET assembly used in the script.
        Add-Type -AssemblyName System.DirectoryServices.Protocols
        $username = 'cn=ldapUser'
        $pwd = 'S3cur3P@$$W0rd'
        $server = $Canary
        $port = "389"
        $password = $pwd | ConvertTo-SecureString -asPlainText -Force
        # Top Level OU under which users are located
        $ldapSearchBase = "cn=users,dc=customer,dc=com,dc=au" 
        # Filter to find the user we are connecting with
        $ldapSearchFilter = "(&(objectClass=Person)($($username)))"
        # Username and Password
        $ldapCredentials = New-Object System.Net.NetworkCredential($username,$password)
        # Create a Connection
        $ldapConnection = New-Object System.DirectoryServices.Protocols.LDAPConnection("$($server):$($port)",$ldapCredentials,"Basic")
        # Connect and Search
        $ldapTimeOut = new-timespan -Seconds 30
        $ldapRequest = New-Object System.DirectoryServices.Protocols.SearchRequest($ldapSearchBase, $ldapSearchFilter, "OneLevel", $null)
        $ldapResponse = $ldapConnection.SendRequest($ldapRequest, $ldapTimeOut)
        $ldapResponse.Entries[0].Attributes
    }
    catch
    {
    Write-Warning "ldap err0r"
    }

    $ErrorActionPreference = $SavedErrorActionPreference 
}

function Invoke-SMBShareAlert 
{
    param (
        [string]$Canary
    )
    # Opening a share
    # by default, Canary will trigger an alert only if a file is accessed,
    # not merely opening the share.
    # so we'll have to list shares, list files, then copy one of them.
    Write-Host -ForegroundColor Yellow "[!] Poke: Openning a share $Canary."
    $shares = &net.exe view \\$Canary /all | Select-Object -Skip 7 | Where-Object { $_ -match 'disk*' } | ForEach-Object { $_ -match '^(.+?)\s+Disk*' | out-null; $matches[1] } | Where-Object { $_ -notmatch '.+\$' }
    # now the $shares variable should have the shares enabled on that canary,
    # simple sanity check
    if (!$shares) {
        Write-Error "[x] The canary doesn't seem to have shares enabled `'$Canary`'!" 
        return
    }
    foreach ($share in $shares) {
        # get folders under each share
        $doc_files = $(&cmd.exe /c dir /s /b "\\$Canary\$share\*.docx") -split '`n'
        
        # check...
        if (!$doc_files) {
            # no .docx in this share
            continue
        }

        # pick first .docx entry
        $doc_file = $doc_files[0]

        Write-Host -ForegroundColor Green "[+] Reading file off a share '$doc_file'"

        # trigger the alert...
        Get-Content $doc_file > $null

        # one is enough, let's break here.
        break
    }
}

function Invoke-HTTPLoginAlert 
{
    param (
        [string]$Canary
    )

    $user = 'PokeCanary'
    $pass = 'PokeCanary'

    $pair = "$($user):$($pass)"

    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

    $basicAuthValue = "Basic $encodedCreds"

    $Headers = @{
        Authorization = $basicAuthValue
    }

    # Get (cisco)
    Write-Host -ForegroundColor Yellow "[!] Poke: HTTP Login (GET Request) $Canary."
    Invoke-WebRequest -Uri "http://$Canary" -Headers $Headers

    # Post (synoligy)
    $postParams = @{username = $user; password = $pass }
    Write-Host -ForegroundColor Yellow "[!] Poke: HTTP Login (POST Request - Synoligy) $Canary."
    Invoke-WebRequest -Uri "http://$Canary/index.html" -Method POST -Body $postParams

    # Post (SharePoint)
    $postParams = @{"ctl00`$PlaceHolderMain`$signInControl`$UserName" = $user; "ctl00`$PlaceHolderMain`$signInControl`$password" = $pass }
    Write-Host -ForegroundColor Yellow "[!] Poke: HTTP Login (POST Request - SharePoint) $Canary."
    Invoke-WebRequest -Uri "http://$Canary/_forms/default.aspx?ReturnUrl=%2f_layouts%2fAuthenticate.aspx%3fSource%3d%252F&Source=%2F" -Headers $Headers

}


# Check if mandatory param has been provided.
if (-not $CanariesFile) { Write-Error -ErrorAction Stop "[x] You must provide a value for -CanariesFile" }

# Does the file exist?
if (-not (Test-Path $CanariesFile)) {
    Write-Error -ErrorAction Stop "[x] The file `'$CanariesFile`' does not exist" 
}

# Getting content of the Canaries TXT file
# this should have a list of Canary device IPs or host name, each on its own line.
Write-Host -ForegroundColor Green "[+] Reading Canaries' IPs/Hostnames from '$CanariesFile'"
$CanariesText = Get-Content $CanariesFile -ErrorAction Stop

# convert the file content to an array, skipping empty lines
$Canaries = $($CanariesText -split "`n").Where( { $_.Trim() -ne "" })

# id the file empty?
if (!$Canaries) {
    Write-Error -ErrorAction Stop "[x] The file `'$CanariesFile`' is empty!" 
}

# iterate over canaries, poking them one by one
foreach ($Canary in $Canaries) {
    Invoke-PokeCanary -Canary $Canary
}