$console_domain = "CONSOLE_DOMAIN_HERE.canary.tools"  # Enter your Console domain, for example, 1234abc.canary.tools
$auth_factory = "FACTORY_AUTH_STRING_HERE"  # Enter your Factory auth key. e.g., a1bc3e769fg832hij3 Docs available here: https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string

$config_region = "us-west-2"
$config_outputformat = "json"

$users_base_dir = "C:\Users"  # Windows base directory for user profiles

# Get the list of user home directories excluding Public directory
$user_dirs = Get-ChildItem -Directory $users_base_dir | Where-Object { $_.Name -ne "Public" }

# Loop through each user directory
foreach ($user_dir in $user_dirs) {
    $current_username = $user_dir.Name
    Write-Output ""
    Write-Output "Processing user: $current_username"

    # Define the AWS credentials file path for the user
    $aws_dir = "$($user_dir.FullName)\.aws"
    $credentials_file = "$aws_dir\credentials"
    $config_file = "$aws_dir\config"
    $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Ensure the .aws directory exists
    if (-not (Test-Path -Path $aws_dir)) {
        New-Item -ItemType Directory -Path $aws_dir -Force
    }

    # Create the token reminder
    # AWS Profile name will be an md5 hash, if a specific named profile is preferred specify it below
    $new_profile = [guid]::NewGuid().ToString("N")
    $tokenreminder = "hostname: $($env:COMPUTERNAME)|username: $current_username|path: $credentials_file|profile: $new_profile|created: $currentDateTime" 

    $awscreds = Invoke-RestMethod -Uri "https://$console_domain/api/v1/canarytoken/factory/create" `
    -Method POST `
    -Body @{
        factory_auth = $auth_factory
        memo = $tokenreminder
        kind = "aws-id"
    }

    # Extract the credentials from the response
    $aws_access_key_id = $awscreds.canarytoken.access_key_id
    $aws_secret_access_key = $awscreds.canarytoken.secret_access_key

    # Check if the credentials file already exists, we do not want to clobber it
    if (-not (Test-Path -Path $credentials_file)) {
        Add-Content -Path $credentials_file -Value "[$new_profile]"
        Add-Content -Path $credentials_file -Value "aws_access_key_id = $aws_access_key_id"
        Add-Content -Path $credentials_file -Value "aws_secret_access_key = $aws_secret_access_key"
        Write-Output "Credentials file created at $credentials_file for [$new_profile] profile"

    } else {
        Add-Content -Path $credentials_file -Value "`n[$new_profile]"
        Add-Content -Path $credentials_file -Value "aws_access_key_id = $aws_access_key_id"
        Add-Content -Path $credentials_file -Value "aws_secret_access_key = $aws_secret_access_key"
        Write-Output "Token appended to $credentials_file for [$new_profile] profile"
    }

    # Check if the config file already exists, we do not want to clobber it
    if (-not (Test-Path -Path $config_file)) {
        Add-Content -Path $config_file -Value "[$new_profile]"
        Add-Content -Path $config_file -Value "region=$config_region"
        Add-Content -Path $config_file -Value "output=$config_outputformat"
        Write-Output "Config file created at $config_file for [$new_profile] profile"

    } else {
        Add-Content -Path $config_file -Value "`n[$new_profile]"
        Add-Content -Path $config_file -Value "region=$config_region"
        Add-Content -Path $config_file -Value "output=$config_outputformat"
        Write-Output "Config file appended to $config_file for [$new_profile] profile"
    }
} 
