# This script is designed to run as a startup script

Set-StrictMode -Version 2.0

# Source directory containing generated host-specific tokens. Tokens should be named HOSTNAME-MSWORD.docx.
$TokenSourcePath = '\\fileserver.local.domain\Path\TokensByHost'

# Path where you want the token to be deployed.
$TargetPath = 'C:\Users\Administrator'
$TargetPathSubdir = 'Desktop'
$ACLFlag = "$TargetPath\ACLfixed"

# Desired file name of deployed token.
$TokenFilename = 'new azure password.docx'

# Create target directory if it does not exists
If (!(Test-Path $TargetPath)) {
    New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
}
If (!(Test-Path $TargetPath\$TargetPathSubdir)) {
    New-Item -ItemType Directory -Force -Path "$TargetPath\$TargetPathSubdir" | Out-Null
}

# Set required permissions
If (!(Test-Path $ACLFlag)) {
    $SystemUser = New-Object System.Security.Principal.NTAccount('NT AUTHORITY', 'SYSTEM')
    $HomedirACL = Get-Acl -Path "$TargetPath"
    # Set owner
    $HomedirACL.SetOwner($SystemUser)
    # Disable inheritance without copying current perissions
    $HomedirACL.SetAccessRuleProtection($true, $false)
    # Set permissions (see: https://stackoverflow.com/questions/3282656/setting-inheritance-and-propagation-flags-with-set-acl-and-powershell)
    $HomedirACL.SetAccessRule($(New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\SYSTEM',    'FullControl',    'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    $HomedirACL.SetAccessRule($(New-Object System.Security.AccessControl.FileSystemAccessRule('BUILTIN\Administrators', 'FullControl',    'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    $HomedirACL.SetAccessRule($(New-Object System.Security.AccessControl.FileSystemAccessRule('ASITIS\Administrator',   'FullControl',    'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    $HomedirACL.SetAccessRule($(New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\Everyone',  'ReadAndExecute', 'ContainerInherit',               'None', 'Allow')))
    Set-Acl -Path "$TargetPath" -AclObject $HomedirACL
    $SubdirACL = Get-Acl -Path "$TargetPath\$TargetPathSubdir"
    $SubdirACL.AddAccessRule($(New-Object System.Security.AccessControl.FileSystemAccessRule('NT AUTHORITY\Everyone',  'ReadAndExecute', 'ObjectInherit',                   'None', 'Allow')))
    Set-Acl -Path "$TargetPath\$TargetPathSubdir" -AclObject $SubdirACL
    New-Item -ItemType File -Force -Path $ACLFlag | Out-Null
}

# Deploy token
$ThisHostname = "$($env:COMPUTERNAME)"
If (Test-Path "$TokenSourcePath\$ThisHostname-MSWORD.docx") {
    Copy-Item -Path "$TokenSourcePath\$ThisHostname-MSWORD.docx" -Destination "$TargetPath\$TargetPathSubdir\$TokenFilename" -Exclude (Get-ChildItem "$TargetPath\$TargetPathSubdir")
}