[CmdletBinding(DefaultParameterSetName = 'search')]
param (
    # Action is required and must be one of the defined values.
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'search')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'delete')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'listflocks')]
    [ValidateSet("search", "delete", "listflocks")]
    [string]$Action,

    # Domain and auth_token are required in all modes.
    [Parameter(Mandatory = $true, ParameterSetName = 'search')]
    [Parameter(Mandatory = $true, ParameterSetName = 'delete')]
    [Parameter(Mandatory = $true, ParameterSetName = 'listflocks')]
    [string]$Domain,

    [Parameter(Mandatory = $true, ParameterSetName = 'search')]
    [Parameter(Mandatory = $true, ParameterSetName = 'delete')]
    [Parameter(Mandatory = $true, ParameterSetName = 'listflocks')]
    [string]$auth_token,

    [Parameter(Mandatory = $true, ParameterSetName = 'delete')]
    [bool]$clear_incidents,

    [Parameter(Mandatory = $true, ParameterSetName = 'search')]
    [Parameter(Mandatory = $true, ParameterSetName = 'delete')]
    [Parameter(Mandatory = $false, ParameterSetName = 'listflocks')]
    [string]$csvfile,

    # The following parameters are only relevant when searching.
    [Parameter(Mandatory = $false, ParameterSetName = 'search')]
    [string]$flock,

    [Parameter(Mandatory = $false, ParameterSetName = 'search')]
    [string]$kind,

    [Parameter(Mandatory = $false, ParameterSetName = 'search')]
    [string]$search_string,

    [Parameter(Mandatory = $false, ParameterSetName = 'search')]
    [string]$delimiter = ","
)

function Invoke-Search {
    Write-Host "`n[*] Performing search for Canary Tokens"

    $params = @{
        auth_token    = $auth_token
        limit         = "300"
    }
    if ($flock)       { $params.Add("flock_id", $flock) }
    if ($kind)        { $params.Add("kind", $kind) }
    if ($search_string) { $params.Add("search_string", $search_string) }

    $baseUri = "https://$Domain.canary.tools/api/v1/canarytokens/search"
    $totalTokens = @()
    $currentUri = $baseUri
    $isFirstCall = $true

    do {
        if ($isFirstCall) {
            # For the first call, include the body parameters.
            $request = @{
                Uri    = $currentUri
                Method = "Get"
                Body   = $params
            }
            $isFirstCall = $false
        }
        else {
            # For subsequent pages, use the next_link URL which already contains the query parameters.
            $request = @{
                Uri    = $currentUri
                Method = "Get"
            }
        }

        try {
            $response = Invoke-RestMethod @request -ErrorAction Stop

            $totalTokens += $response.canarytokens

            if ($response.cursor -and $response.cursor.PSObject.Properties["next_link"] -and -not [string]::IsNullOrEmpty($response.cursor.next_link)) {
                $currentUri = $response.cursor.next_link
            }
            else {
                break
            }
        }
        catch {
            Write-Host "`n[!] Error during search: $_"
            exit 1
        }
    } while ($true)

    $RESULTCOUNT = $totalTokens.Count
    Write-Host "`n[*] Total Tokens found: $RESULTCOUNT"

    if ($RESULTCOUNT -gt 0) {
        $csvData = $totalTokens |
               Select-Object canarytoken, flock_id, kind, memo |
               ConvertTo-Csv -NoTypeInformation -Delimiter $delimiter
        $csvData | Out-File $csvfile -Force
        Write-Host "[*] Results written to $csvfile. Please review before proceeding."
    }
    
}


function Invoke-Delete {
    if (-Not (Test-Path $csvfile)) {
        Write-Host "`n[!] CSV file $csvfile not found. Please specify -csvfile or run 'search' to create one"
        exit 1
    }
    Write-Host "`n[*] Proceeding with deletion of tokens from $csvfile"
    $i = 0
    $tokens = Import-Csv -Path $csvfile -Delimiter $delimiter | Select-Object -ExpandProperty canarytoken

    $tokenCount = $tokens.Count
    Write-Host "`n[*] Tokens to be deleted: $tokenCount"

    # Prompt for confirmation before deletion.
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Yes, delete tokens permanently."
    $no  = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel deletion."
    $choice = $host.ui.PromptForChoice("Confirm Deletion", "Delete all tokens from $csvfile ?", @($yes, $no), 1)
    if ($choice -ne 0) {
        Write-Host "`n[*] Token deletion cancelled."
        exit
    }

    foreach ($token in $tokens) {
        try {
            $deleteResponse = Invoke-WebRequest -Method POST `
                                -Uri "https://$Domain.canary.tools/api/v1/canarytoken/delete" `
                                -Body @{auth_token=$auth_token;canarytoken=$token;clear_incidents=$clear_incidents} `
                                -ErrorAction Stop
            if ($deleteResponse.StatusCode -eq 200) {
                $i++
                Write-Host "`n[*] Deleted Token: $token ($i)"
            }
            else {
                Write-Host "`n[!] Failed to delete Token: $token. Status: $($deleteResponse.StatusCode)"
            }
        }
        catch {
            Write-Host "`n[!] Exception deleting token $token : $_"
        }
    }
    Write-Host "`n[*] Token deletion complete. Total tokens deleted: $i"
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $directory = Split-Path $csvfile -Parent
    $fileName = Split-Path $csvfile -Leaf
    $deletedFile = Join-Path -Path $directory -ChildPath ("deleted_" +$timestamp + "_" + $fileName)
    
    Rename-Item -Path $csvfile -NewName $deletedFile -Force
    Write-Host "`n[*] CSV file renamed to: $deletedFile"
}

function Invoke-Listflocks {
    Write-Host "`n[*] Retrieving flock summary from API"

    $uri = "https://$Domain.canary.tools/api/v1/flocks/summary?auth_token=$auth_token"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop

        $flockSummary = $response.flocks_summary

        if ($flockSummary) {
            Write-Host "`n[*] Flock Summary:"
            foreach ($prop in $flockSummary.PSObject.Properties) {
                $flockKey = $prop.Name
                $flockInfo = $prop.Value

                Write-Host "`nFlock ID: $flockKey"
                Write-Host "  Name: $($flockInfo.name)"
                Write-Host "  Total Tokens: $($flockInfo.total_tokens)"
                Write-Host "  Enabled Tokens: $($flockInfo.enabled_tokens)"
                Write-Host "  Disabled Tokens: $($flockInfo.disabled_tokens)"
            }
        }
        else {
            Write-Host "`n[!] No flock summary data returned by the API."
        }
    }
    catch {
        Write-Host "`n[!] Error retrieving flock summary: $_"
    }

}

# Main processing: call the appropriate function based on the action.
switch ($Action) {
    "search" {
        Invoke-Search
    }
    "delete" {
        Invoke-Delete
    }
    "listflocks" {
        Invoke-Listflocks
    }
    default {
        Write-Host "Unknown action. Valid actions are: search, delete, listflocks."
    }
}
