#We find hyper-V to be a little sensitive to conflicts in object names so we've appended the date and time to a couple files during the import. 
#There are a couple steps we recommend to prepare your environment.
#Edit the Virtual Machines\ABC123.XML file to specify your desired network adapter.
#This can be found on line 135
#<AltSwitchName type="string">LAN</AltSwitchName> 
#
#To :
#
#<AltSwitchName type="string">My Preferred Network Adapter</AltSwitchName>
#
#Edit lines 6-9 of the powershell script to specify your environment.
#BirdBackupPath - This is the location of the .xml file edited above.
#BirdVhdPath - Your preferred disk location of the imported Bird.
#BirdMachinePath - Your preferred save location of the imported Birds configuration.
#Birdname - Your preferred VM name.
#(Line 17 Optional) Start-VM can be uncommented to start the VM automatically after import.
#
#You're done! The script can be used on the Hyper-V host to create multiple Birds.

$repeat = Read-Host -Prompt 'How many Birds would you like deployed?'

for ($i = 1; $i -le $repeat; $i++) {

[string]$Timestamp = (Get-Date).tostring("dd-MM-yyyy-hh-mm-ss") #Appending the time to Hyper-V configs avoids conflicts.
[string]$BirdBackupPath = 'C:\Users\admin\Desktop\Hyper-VCanary-3.5.0-711e9fe\Virtual Machines\A5B76132-C98D-4CD2-9F98-6F0FA28FA6FB.xml' #Set this variable to the path of your extracted Canary folder.
[string]$BirdVhdPath = 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\BirdCage-'+$Timestamp #Set this variable to the storage location of the new Canary disks.
[string]$BirdMachinePath = 'C:\Users\Public\Documents\Hyper-V\Virtual Machines\BirdCage'+$Timestamp #Set this variable to the storage location of the new Canary VM configuration.
[string]$BirdName = 'BirdCage-'+$Timestamp #Set this variable to the desired VM name, appending the time avoids conflicts.

Import-VM -Path $BirdBackupPath -Copy -GenerateNewId -VhdDestinationPath $BirdVhdPath -VirtualMachinePath $BirdMachinePath

Rename-VM 'Hyper-VCanary-3.5.0-711e9fe' -NewName $BirdName

Write-Host "New Canary - $Birdname has been created."

#Start-VM -Name $BirdName; Write-Host "New Canary - $Birdname has been started." #uncomment this to start the VM after creation.

}