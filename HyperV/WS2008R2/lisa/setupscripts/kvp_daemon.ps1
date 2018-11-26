############################################################################
#
# kvp_daemon.ps1
#
# Description:
#     This is a test case script that will check the KVB behavior of
#     the LIS components.
#     
#
############################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams) 

$retVal = $false

"kvp_daemon.ps1"
"    vmName = ${vmName}"
"    hvServer = ${hvServer}"
"    testParams = ${testParams}"

#
# Check input arguments
# 
if (-not $vmName -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $False
}

if (-not $hvServer -or $hvServer.Length -eq 0)
{
    "Error: HyperV server name is null"
    return $False
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

$Vm = Get-WmiObject -Namespace root\virtualization -Query "Select * From Msvm_ComputerSystem Where ElementName='$vmName'" -ComputerName $hvServer
if (-not $vm)
{
    "Error: Unable to retrieve Msvm_ComputerSystem for VM ${vmName}"
    return $False
}

$Kvp = Get-WmiObject -Namespace root\virtualization -Query "Associators of {$Vm} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent" -ComputerName $hvServer
if (-not $Kvp)
{
    "Error: Unable to retrieve Msvm_SystemDevice for VM ${vmName}"
    return $False
}

#
# Get the KVP values
# 
$a = $Kvp.GuestIntrinsicExchangeItems
if (-not $a -or $a.Length -eq "0")
{
	"Error: KVP value is null"
    return $False
}
else 
{
	$Kvp.GuestIntrinsicExchangeItems | Import-CimXml
	$retVal = $true
}

return $retVal



