$ConfigFile = '.\Fetch-Canary-Syslog-Config.xml'
$ConfigParams = [xml](get-content $ConfigFile)

# Initialize configuration variables from config xml file
$WorkerURL = $ConfigParams.configuration.cloudflare.URL.value
$WorkerAuth = $ConfigParams.configuration.cloudflare.auth.value
$SyslogTarget = $ConfigParams.configuration.syslog.fqdn.value
$SyslogPort = $ConfigParams.configuration.syslog.port.value
$OutputFile = $ConfigParams.configuration.file.canarylogs.value

# Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Request the queued Canary events (-UseBasicParsing ensures we don't use the deprecated IE HTML renderer)
$Response = Invoke-WebRequest -Uri $WorkerURL -Headers @{ 'auth' = $WorkerAuth} -UseBasicParsing

if($Response.Statuscode -eq 204){exit 0} # Nothing to process - resultset is empty

# Prepare the Syslog UDP socket
if ($SyslogTarget -ne "syslog.hostname.here") {
   $UdpClient = New-Object System.Net.Sockets.UdpClient $SyslogTarget, $SyslogPort
   }

$Content = $Response.Content
$SyslogArray = $Content.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

ForEach ($SyslogEntry in $SyslogArray){
   # Convert message to array of ASCII bytes.
   $bytearray = $([System.Text.Encoding]::ASCII).getbytes($SyslogEntry)
   # Send the Syslog message...
   if ($SyslogTarget -ne "syslog.hostname.here") {
       $UdpClient.Send($bytearray, $bytearray.length) | out-null
   }
   else {
       # No syslog server was specified in the configuration file, so output to a local file
       Add-Content $OutputFile $SyslogEntry
   }
}
