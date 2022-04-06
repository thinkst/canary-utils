$Scriptblock ={
    param($Server)
    $CanaryHost = 'https://xxxxxxxx.canary.tools'
    $CanaryApiKey = ''
    $FlockId='flock:default'

    $ApiPing = "$CanaryHost/api/v1/ping?auth_token=$CanaryApiKey"
    $ApiCreateToken = "$CanaryHost/api/v1/canarytoken/create?auth_token=$CanaryApiKey"
    $ApiDownloadToken = "$CanaryHost/api/v1/canarytoken/download?auth_token=$CanaryApiKey"

    $Memo =([String]'Password file stored on '+$Server.name)
    $OutputFile = ([String]'C:\Users\Administrator\Passwords_'+$Server.name+'.docx')

    # Process script parameters
    if ($Memo -eq $null -or $OutputFile -eq $null) {
        Write-Host -ForegroundColor Red "Please supply a Memo and an OutputFile path"
        return
    }

    # Setup error handling by clearing all previous errors
    $error.Clear()
    $ErrorActionPreference = 'SilentlyContinue'

    # Check that the API is reachable (both host and API key are valid)
    Invoke-WebRequest -Uri "$ApiPing" | out-null
    if ($error.count -ne 0) {
        Write-Host -ForegroundColor Red "Could not connect to the Canary Console at $CanaryHost."
        Write-Host -ForegroundColor White -BackgroundColor Black "The error was:"
        Write-Host $error[0]
        Write-Host -ForegroundColor White -BackgroundColor Black "Please ensure the Canary Console hostname and API key are present in the script."
        return
    }

    # Create the Canarytoken on the Canary Console
    $postParams = @{kind='doc-msword';memo="$Memo";flock_id=$FlockId}
    $tokenString = Invoke-WebRequest -Uri "$ApiCreateToken" -Method POST -Body $postParams
    if ($error.count -ne 0) {
        Write-Host -ForegroundColor Red "Could not create Canarytoken."
        Write-Host -ForegroundColor White -BackgroundColor Black "The error was:"
        Write-Host $error[0]
        return
    }
    # Extract the Canarytoken value from the response
    $tokenData = ConvertFrom-Json -InputObject $tokenString
    $canarytoken = $tokenData.canarytoken.canarytoken

    # Download the MS Word file associated with the newly created Canarytoken
    # and output to the file <canarytoken>.docx
    try {
        Invoke-WebRequest -Uri "$ApiDownloadToken&canarytoken=$canarytoken" -OutFile "$OutputFile"
        Unblock-File -Path "$OutputFile"
    } catch {
        if(($_.Exception.GetType() -match "HttpResponseException") -and
            ($_.Exception -match "302")) {
            $downloadFileUrl = $_.Exception.Response.Headers.Location.AbsoluteUri
            $error.Clear()
            Invoke-Webrequest -Uri $downloadFileUrl -OutFile "$OutputFile"
            Unblock-File -Path "$OutputFile"
        } else {
            throw $_
        }
    }

    if ($error.count -ne 0) {
        Write-Host -ForegroundColor Red "Could not download the tokened document."
        Write-Host -ForegroundColor White -BackgroundColor Black "If you contact support@canary.tools, please include this output:"
        Get-Host | Select-Object Name,Version
        Write-Host "Error:"
        Write-Host $error[0]
    }
    $b = New-PSSession -ComputerName $Server.dnshostname
    Copy-Item -ToSession $b $OutputFile -Destination C:\Users\Administrator\Desktop\password.docx
    $b | Remove-PSSession
    Write-Host 'Canary Token (password.docx) written to'$srv_name
}

$RunspacePool = [runspacefactory]::CreateRunspacePool(1,10)
$RunspacePool.Open()
$Jobs = @()

Get-ADComputer -Filter * -Properties * | Select name, dnshostname | Foreach-Object {
    $PowerShell = [Powershell]::Create()
    $Powershell.RunspacePool = $RunspacePool
    $Powershell.AddScript($Scriptblock).AddArgument($_)
    $Jobs += $PowerShell.BeginInvoke()
}
while ($Jobs.IsCompleted -contains $False) {Start-Sleep -Milliseconds 100}
