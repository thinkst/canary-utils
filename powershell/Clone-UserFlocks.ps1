<#
.SYNOPSIS
    Clones Flocks from one user to another using an admin global API key.

.PARAMETER domain
    Specify your full Canary Console domain i.e. ABC123.canary.tools

.PARAMETER apiKey
    Specify your Admin key required for authentication.

.PARAMETER sourceUser
    The source user whose flocks will be cloned.

.PARAMETER targetUser
    The target user who will be assigned the cloned flocks.

.EXAMPLE
    .\Clone-Flocks.ps1 -domain abc123.canary.tool -apiKey your_admin_key -sourceUser source@example.com -targetUser target@example.com

    This example clones flocks from 'source@example.com' to 'target@example.com.

.NOTES
    Author: Gareth Wood
    Date: 16 Feb 2024
    Version: 1.0
    Requires: PowerShell 5.0 or later
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$domain,

    [Parameter(Mandatory = $true)]
    [string]$apiKey,

    [Parameter(Mandatory = $true)]
    [string]$sourceUser,

    [Parameter(Mandatory = $true)]
    [string]$targetUser
)

# Validate domain format
if (-not $domain -or $domain -notmatch '^[a-zA-Z0-9.-]+$') {
    Write-Error "Invalid domain format. Please provide a valid domain name."
    Exit 1
}

# Set the headers for the API request
$headers = @{
    "X-Canary-Auth-Token" = $apiKey
}

try {
    # Retrieve flocks associated with the source user
    $response = Invoke-RestMethod -Method Get -Uri "https://$domain/api/v1/user/auth?email=$sourceUser" -Headers $headers

    # Display information about source user's flocks
    Write-Host "`nCloning flocks from user: $sourceUser to $targetUser`n"
    Write-Host "$sourceUser has $($response.managed_flocks.Count) managed Flocks and $($response.watched_flocks.Count) Watched Flocks`n"

    # Define body data for cloning managed flocks
    $cloneManagedFlocksBody = @{
        email = $targetUser
        flock_id_list = $response.managed_flocks -join ","
        flock_access_level = "manager"
    }

    # Define body data for cloning watcher flocks
    $cloneWatcherFlocksBody = @{
        email = $targetUser
        flock_id_list = $response.watched_flocks -join ","
        flock_access_level = "watcher"
    }

    Write-Host "`nCloning...`n"

    # Clone managed flocks
    $cloneManagedFlocksResponse = Invoke-RestMethod -Method Post -Uri "https://$domain/api/v1/user/flock/assign" -Headers $headers -Body $cloneManagedFlocksBody

    # Clone watcher flocks
    $cloneWatcherFlocksResponse = Invoke-RestMethod -Method Post -Uri "https://$domain/api/v1/user/flock/assign" -Headers $headers -Body $cloneWatcherFlocksBody

    Write-Host "`nDone!`n" 
}
catch {
    Write-Error "An error occurred: $_"
}
