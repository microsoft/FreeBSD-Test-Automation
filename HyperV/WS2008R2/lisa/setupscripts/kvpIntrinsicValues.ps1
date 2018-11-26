############################################################################
#
#
# Description:
#       
#      Getting the intrinsic values of VM    
#   
#     
#
############################################################################

param([string] $vmName) 

$retVal = $false

#
# Check input arguments
# 
if (-not $vmName -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $retVal
}

#
# Get Intrinsic KVPs (Included Guest machine name, IC Version, OS Version, etc) 
#
filter Import-CimXml 
{
    $kvpMsg = "KVP Object`n"
    $CimXml = [Xml]$_ 
    $CimObj = New-Object -TypeName System.Object 
    foreach ($CimProperty in $CimXml.SelectNodes("/INSTANCE/PROPERTY")) 
    {
        #
        # One of the Data properties ends with a 0x0a.  Strip it off
        #
        $value = $CimProperty.VALUE
        if ($value -and $value.Length -gt 0 -and $value[$value.Length-1] -eq 0x0a)
        {
            $value = $value.SubString(0, $Value.Length-1)
        }

        $kvpMsg += "  {0,-11} : {1}`n" -f $CimProperty.NAME, $value #$CimProperty.VALUE
    } 
    $kvpMsg # Display the string.  It will be returned as uncaptured output
} 

$Vm = Get-WmiObject -Namespace root\virtualization -Query "Select * From Msvm_ComputerSystem Where ElementName='$vmName'" 
$Kvp = Get-WmiObject -Namespace root\virtualization -Query "Associators of {$Vm} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent" 

$a = $Kvp.GuestIntrinsicExchangeItems

if ($a.Length -eq "0")
{
	write-host "Error: KVP value is null"
}
else 
{
	$Kvp.GuestIntrinsicExchangeItems | Import-CimXml
	$retVal = $true
}

return $retVal



