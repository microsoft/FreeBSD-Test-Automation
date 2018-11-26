#######################################################################
#
# RemoveIsoFromDvd.ps1
#
# Description:
#    This script will remove SCSIController
#
#######################################################################

param ([String] $vmName, [String] $hvServer, [String] $testParams)


#######################################################################
#
# GetRemoteFileInfo()
#
# Description:
#     Use WMI to retrieve file information for a file residing on the
#     Hyper-V server.
#
# Return:
#     A FileInfo structure if the file exists, null otherwise.
#
#######################################################################
function GetRemoteFileInfo([String] $filename, [String] $server )
{
    $fileInfo = $null
    
    if (-not $filename)
    {
        return $null
    }
    
    if (-not $server)
    {
        return $null
    }
    
    $remoteFilename = $filename.Replace("\", "\\")
    $fileInfo = Get-WmiObject -query "SELECT * FROM CIM_DataFile WHERE Name='${remoteFilename}'" -computer $server
    
    return $fileInfo
}


"removeSCSIController.ps1"
"  vmName = ${vmName}"
"  hvServer = ${hvServer}"
"  testParams = ${testParams}"

$retVal = $False

$isoFilename = $null

#
# Check arguments
#
if (-not $vmName)
{
    "Error: Missing vmName argument"
    return $False
}

if (-not $hvServer)
{
    "Error: Missing hvServer argument"
    return $False
}

#
# This script does not use any testParams
#

$error.Clear()

#
# Load the HyperVLib version 2 modules
#
$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2SP1\Hyperv.psd1
    if ($error.count -gt 0)
    {
        "Error: Unable to load the Hyperv Library"
        $error[0].Exception
        return $False
    }
}

#
# Make sure the SCSI drive exists on the VM
#
$scsi0 = Get-VMDiskController $vmName -server $hvServer -SCSI 0
if (-not $scsi0)
{
    "Error: Cannot find SCSI controller 0 on VM ${vmName}"
    $error[0].Exception
    return $True
    break;
}


#
# Remove the SCSI 0 controller
#
$newDisk = Remove-VMSCSIController -vm $vmName -ControllerID 0 -server $hvServer -Force
if (-not $newDisk)
{
    "Error: Unable to remove drive"
    $error[0].Exception
    return $False
}
else
{
    $retVal = $True
}

return $retVal
