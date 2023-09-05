[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$domain,

    [Parameter(Mandatory=$true)]
    [string]$auth_token,

    [Parameter(Mandatory=$true)]
    [Bool]$clear_incidents,

    [Parameter(Mandatory=$false)]
    [string]$flock,

    [Parameter(Mandatory=$false)]
    [string]$kind,

    [Parameter(Mandatory=$false)]
    [string]$search_string
)

$i = 0

# Create a hash table to hold the parameters
$params = @{}

# Add apikey to the params hash table.
$params.Add("auth_token", $auth_token)

# Add limit to the params hash table.
$params.Add("limit", "3000")

# Add flock to the params hash table, if provided
if ($flock) {
    $params.Add("flock_id", $flock)
}

# Add kind to the params hash table, if provided
if ($kind) {
    $params.Add("kind", $kind)
}

# Add search to the params hash table, if provided
if ($search) {
    $params.Add("search_string", $search_string)
}

# Set up the HTTP request with the API endpoint URL and method
$request = @{
    Uri = "https://"+$domain+".canary.tools/api/v1/canarytokens/search"
    Method = "Get"
    Body = $params
}

# Send the request and get the response

if ((Test-Path -Path .\token_search_results.csv)) {
    Write-Host "`n [*] Previous search results already exist, skipping to delete function..."
}

else {
    Write-Host "`n [*] Searching for Canary Tokens containing :" $search_string

    Invoke-RestMethod @request | Select-Object -ExpandProperty canarytokens | Select-Object canarytoken, flock_id, kind, memo | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File token_search_results.csv
    
    $RESULTCOUNT = (Get-Content token_search_results.csv).Count

    Write-Host "`n [*] Number of Tokens found :" $RESULTCOUNT
    Write-Host "`n [*] Results written to token_search_results.csv"
    Write-Host "`n [*] Please take a moment to review the output in token_search_results.csv before proceeding."
    exit
}

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes, continue to delete Tokens. (Permanent)"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","No, Stop running the script here."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

$title = "`n [!] IMPORTANT"
$message = "`n [!] Proceed to delete all Tokens from token_search_results.csv? (Permanent)"

$result = $host.ui.PromptForChoice($title, $message, $options, 1)
Write-Host "`n"

switch ($result) {
    0{
      Write-Host "`n [*] Starting Token Deletion"
      Write-Host "`n [*] Grabbing Tokens from token_search_results.csv"
  
      Get-Content -Path .\token_search_results.csv | Foreach-Object { ($_ -split ",")[0].Trim('"') } | Set-Content -Path .\tokens_to_delete.txt
  
      Get-Content -Path .\tokens_to_delete.txt | Foreach-Object {
  
          $line = $_
          $status_code = (Invoke-WebRequest -Method POST -Uri "https://$domain.canary.tools/api/v1/canarytoken/delete" -Body @{auth_token=$auth_token; canarytoken=$line; clear_incidents=$clear_incidents}).StatusCode

          if ($status_code -ne 200) {
              Write-Host "`n [!] Failed to delete Token" $line
              Write-Host "`n [!] Status:" $status_code
          }
          else {
              $i++
              Write-Host "`n [*]" $i "Deleted Token :" $line
          }
  
      }

      Write-Host "`n [*] Token Deletion Complete!"
      Write-Host "`n [*] Total number of Tokens deleted:" $i

      Remove-Item .\tokens_to_delete.txt
      Remove-Item .\token_search_results.csv
    }1{
      Write-Host "`n [*] Token removal cancelled.`n"
    }
}