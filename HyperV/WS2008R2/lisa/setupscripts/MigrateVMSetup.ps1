#
#
#
param ( [String] $vmName )

"MigrateVMSetup.ps1 -vmName $vmName"

#
# Load the cluster commandlet module
#
$sts = get-module | select-string -pattern FailoverClusters -quiet
if (! $sts)
{
    Import-module FailoverClusters
}

# Get the VMs current node
#
#$vmResource =  Get-ClusterResource | where-object {$_.OwnerGroup.name -eq "$vmName" -and $_.ResourceType.Name -eq "Virtual Machine"}
$vmResource =  Get-ClusterResource "Virtual Machine ${vmName}"

if (-not $vmResource)
{
    "Error: $vmName - Unable to find cluster resource for current node"
    return $False
}

$currentNode = $vmResource.OwnerNode.Name
if (-not $currentNode)
{
    "Error: $vmName - Unable to set currentNode"
    return $False
}

$potentialOwners = ($vmResource | Get-ClusterOwnerNode)
$preferredOwner = $potentialOwners.OwnerNodes[0].Name

if ($currentNode -ne $preferredOwner)
{
    $error.Clear()
    $sts = Move-ClusterGroup $vmName -node $preferredOwner
    if ($error.Length -gt 0)
    {
        "Error: Move-ClusterGroup failed"
        $error[0].ErrorDetails
        return $false
    }
}

#
# If we made it here, everything worked
#
return $True
