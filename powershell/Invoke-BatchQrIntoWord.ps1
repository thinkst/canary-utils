Param (
    [string]$Domain = 'abc123.canary.tools', # Enter your Console domain between the . e.g. 1234abc.canary.tools
    [string]$FactoryAuth = 'abc123' # Enter your Factory auth key. e.g a1bc3e769fg832hij3 Docs available here. https://docs.canary.tools/canarytokens/factory.html#create-canarytoken-factory-auth-string
    )

####################################################################################################################################################################################################################################

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-StrictMode -Version 2.0

[string]$TokenType = 'qr-code'
[string]$WordTemplate = "C:\Users\admin\Desktop\Blank Document - QR Scan.docx" # Template File
[string]$TokensPath = "C:\Users\admin\Desktop\Tokens\"  # Saves the Tokens to this path, please append a slash at the end.

If (!(Test-Path $TokensPath)) {
    New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TokensPath" > $null
}

If (!(Test-Path $env:TEMP\operations\)) {
    New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$env:TEMP\operations\" > $null
}

$ListItems = @(
"Contoso",
"Acme",
"Apple"
)

foreach ($Item in $ListItems) {

    $PostData = @{
    factory_auth = "$FactoryAuth"
    kind       = "$TokenType"
    memo       = "$Item - Network Closet"
    }

    $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain/api/v1/canarytoken/factory/create" -Body $PostData
    $Result = $CreateResult.result
    
    If ($Result -ne 'success') {
        Write-Host -ForegroundColor Red "[X] Creation of $OutputFileName failed."
        Exit
    }
    
    Else {
        $TokenID = $($CreateResult).canarytoken.canarytoken
    }

    Invoke-RestMethod -Method Get -Uri "https://$Domain/api/v1/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$env:TEMP\operations\$Item-qr.png"

    # Create a new Word application
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false  # If you want to make Word visible for debugging purposes

    $document = $word.Documents.Open("$WordTemplate")  # Open an existing document

    # Insert the image and center it
    $range = $document.Content
    $range.Collapse([Microsoft.Office.Interop.Word.WdCollapseDirection]::wdCollapseEnd)
    $shape = $range.InlineShapes.AddPicture("$env:TEMP\operations\$Item-qr.png")
    $shape.Range.ParagraphFormat.Alignment = 1  # 1 corresponds to Center alignment

    # Save the document to a new location
    $newDocumentPath = "$TokensPath\$Item.docx"
    $document.SaveAs([ref]$newDocumentPath)

    # Close Word and release the COM objects
    $document.Close()
    $word.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shape) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($range) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($document) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
    Remove-Variable word

} 
