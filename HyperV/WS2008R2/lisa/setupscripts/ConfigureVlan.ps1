#############################################################
#
# ConfigureVlan.ps1
#
# Description:
#    This will script will Add a VMBus NIC to a VM also it will adds the Vlan tag to the VMBus adapter.
#
# Test Params:
#    Switch Name
#
#############################################################
param ([String] $vmName, [String] $hvServer, [String] $testParams)


#############################################################
#
# Main script body
#
#############################################################

$retVal = $False

#
# Check the required input args are present
#
if (-not $vmName)
{o
    "Error: null vmName argument"
    return $False
}

if (-not $hvServer)
{
    "Error: null hvServer argument"
    return $False
}

if (-not $testParams)
{
    "Error: null testParams argument"
    return $False
}

#
# Display some info for debugging purposes
#
"VM name     : ${vmName}"
"Server      : ${hvServer}"
"Test params : ${testParams}"

#
# Parse the test params
#

$params = $testParams.Split(';')
foreach ($p in $params)
{
    if ($p.Trim().Length -eq 0)
    {
        continue
    }

    $tokens = $p.Trim().Split('=')
    
    if ($tokens.Length -ne 2)
    {
	    "Warn : test parameter '$p' appears malformed, ignoring"
         continue
    }

    if ($tokens[0].Trim() -eq "switchName")
    {
        $switchName = $tokens[1].Trim().ToLower()
    }
}


if (-not $switchName)
{
    "Error: switchName test parameter is missing"
    return $False
}

#
# Load the HyperVLib version 2 modules
#
$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2SP1\Hyperv.psd1
}




#
# Add the VMBus NIC
#
$newNic = Add-VmNic -vm $vmName -VirtualSwitch $switchName  -Server $hvServer -Force
if ($newNic)
{
    $retVal = $True
}
else
{
    "Error: Unable to add VMBus NIC"
    return $False

}

#
# Add the Vlan ID to the VMBUS adapter
#

Set-VMNetworkAdapterVlan -VMName $vmName  -VMNetworkAdapterName $newNic.ElementName -Trunk -NativeVlanId 1 -AllowedVlanIdList “2,3,4”
if ($? -ne $True)
{
    "Error: Unable to set the Vlan ID to the VMBUS adapter"
    $retVal = $False
}

return $retVal
