############################################################################
#
# CheckHeartBeat.ps1
#
# Description:
#     This is a setup script that will run when VM is on and it will  #check for heartbeat.
#     
#	Created by : v-vyadav@microsoft.com
############################################################################


# Get Intrinsic KVPs (Included Guest machine name, IC Version, OS Version, etc) 

param( 
    [string]$vmName = $(throw "Must specify virtual machine name") 
) 

filter Import-CimXml 
{ 
    $CimXml = [Xml]$_ 
    $CimObj = New-Object -TypeName System.Object 
    foreach ($CimProperty in $CimXml.SelectNodes("/INSTANCE/PROPERTY")) 
    { 
        $CimObj | Add-Member -MemberType NoteProperty -Name $CimProperty.NAME -Value $CimProperty.VALUE 
    } 
    $CimObj 
} 

$Vm = Get-WmiObject -Namespace root\virtualization -Query "Select * From Msvm_ComputerSystem Where ElementName='$vmName'" 
$Kvp = Get-WmiObject -Namespace root\virtualization -Query "Associators of {$Vm} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent" 


$Kvp.GuestIntrinsicExchangeItems | Import-CimXml
 
