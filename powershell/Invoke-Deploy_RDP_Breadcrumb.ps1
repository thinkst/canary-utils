 # Breadcrumb dropper
$ConsoleDomain = 'CONSOLE.canary.tools' 
$AuthToken = 'APIKEY' # ReadOnly API Key, the Breadcrumb API endpoint does not currently support FactoryAuth

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

# <nodeID> for each Canary you would like to include in RDP Breadcrumb deployment
function Deploy-Breadcrumb{
    param (
        [string]$FileExtension = 'rdp',
        [string[]]$CanaryNodes = @("<nodeID>", "<nodeID>"),
        [string]$BreadcrumbPath = 'C:\'
    )

    # Select a random <nodeID> to reference for BreadCrumb
    $randomNode = $CanaryNodes | Get-Random
   
    # Get the Canary name, used as part of the filename for the breadcrumb
    $params = @{
        Uri = "https://$ConsoleDomain/api/v1/device/info"
        Method = 'GET'
        Body = @{
            auth_token = $AuthToken
            node_id = $randomNode
        }
    }

    $CanaryResult = Invoke-RestMethod @params 
    $CanaryName = $CanaryResult.device.name
    $OutputFileName = "$BreadcrumbPath$CanaryName.$FileExtension"

    $params = @{
        Uri = "https://$ConsoleDomain/api/v1/breadcrumb/download"
        Method = 'GET'
        Body = @{
            auth_token = $AuthToken
            node_id = $randomNode
            kind = 'rdp-profile'
        }
    }

    $BreadcrumbResult = Invoke-RestMethod @params -OutFile $OutputFileName
}

Deploy-Breadcrumb

Exit 0 
