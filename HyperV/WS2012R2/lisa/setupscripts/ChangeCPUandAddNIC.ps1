############################################################################
#
# ChangeCPUandAddNIC.ps1
#
############################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $false

#
# Check input arguments
#
if (-not $vmName)
{
    "Error: VM name is null. "
    return $retVal
}

if (-not $hvServer)
{
    "Error: hvServer is null"
    return $retVal
}

#
# Note: length 22 is the shortest sting possible
#
if (-not $testParams -or $testParams.Length -lt 22)
{
    "Error: No testParams provided"
    "       The script $MyInvocation.InvocationName requires the Network test parameter"
    return $retVal
}


#
# Parse the testParams string, then process each parameter
#
"Info : testParams = '${testParams}'"
$numCPUs = 0
$params = $testParams.Split(';')
foreach ($p in $params)
{
    $temp = $p.Trim().Split('=')
    
    if ($temp.Length -ne 2)
    {
        # Ignore this parameter and move on to the next
        continue
    }
    
	if ($temp[0].Trim() -eq "VCPU")
    {
        $numCPUs = $temp[1].Trim()
    }
	
    #
    # Is this a NIC=* parameter
    #
    if ($temp[0].Trim() -eq "NIC")
    {
        $nicArgs = $temp[1].Split(',')
        
        if ($nicArgs.Length -ne 3)
        {
            "Error: Invalid arguments for NIC test parameter: $p"
            return $false
        }
        
        $nicType = $nicArgs[0].Trim()
        $networkType = $nicArgs[1].Trim()
        $networkName = $nicArgs[2].Trim()
        $legacy = $false
        
        #
        # Validate the network adapter type
        #
        if (@("NetworkAdapter", "LegacyNetworkAdapter") -notcontains $nicType)
        {
            "Error: Invalid NIC type: $nicType"
            "       Must be either 'NetworkAdapter' or 'LegacyNetworkAdapter'"
            return $false
        }
        
        if ($nicType -eq "LegacyNetworkAdapter")
        {
            $legacy = $true
        }

        #
        # Validate the Network type
        #
        if (@("External", "Internal", "Private") -notcontains $networkType)
        {
            "Error: Invalid netowrk type: $networkType"
            "       Network type must be either: External, Internal, Private"
            return $false
        }

        # Make sure the network exists
        $vmSwitch = Get-VMSwitch -Name $networkName -ComputerName $hvServer
        if (-not $vmSwitch)
        {
            "Error: Invalid network Name: $networkName"
            "       The network does not exist"
            return $false
        }

        Add-VMNetworkAdapter -VMName $vmName -SwitchName $networkName -IsLegacy:$legacy -ComputerName $hvServer
        if($? -ne "True")
        {
            Write-Output "Adding NIC failed"
            reurn $false
        }
        else
        {
            $retVal = $true
        }
    }
}


#
# Update the CPU count on the VM
#
$retVal2 = $false
$cpu = Set-VM -Name $vmName -ComputerName $hvServer -ProcessorCount $numCPUs
if ($? -eq "True")
{
    write-host "CPU count updated to $numCPUs"
    $retVal2 = $true
}
else
{
    write-host "Error: Unable to update CPU count"
}



return ( $retVal -and $retVal2 )


