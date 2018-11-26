$ComputerName = "WIPRO-FREEBSD2"
$VM = "FreeBSD-9.1_x64"

filter Import-CimXml
{
    $CimXml = [Xml]$_
    $CimObj = New-Object -TypeName System.Object
    #write-output "'$Cimobj'"
    foreach ($CimProperty in $CimXml.SelectNodes("/INSTANCE/PROPERTY"))
    {
	$CimObj | Add-Member -MemberType NoteProperty -Name $CimProperty.NAME -Value $CimProperty.VALUE
    }
    $CimObj
}

$Vm = Get-WmiObject -Namespace root\virtualization -Query "Select * From Msvm_ComputerSystem Where ElementName=`'$VM`'"
$Kvp = Get-WmiObject -Namespace root\virtualization -Query "Associators of {$Vm} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent"
#write-output "'$Kvp.GuestExchangeItems'"
#write-output "'$vm'"
#$Kvp.GuestExchangeItems | Import-CimXml
$Kvp.GuestIntrinsicExchangeItems | Import-CimXml

