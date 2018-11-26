#######################################################################
#
# RemoveIsoFromDvd.ps1
#
# Description:
#    This script will "unmount" a .iso file in the DVD drive (IDE 1 0)
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


"removeIsoFromDvd.ps1"
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
<#$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2SP1\Hyperv.psd1
    if ($error.count -gt 0)
    {
        "Error: Unable to load the Hyperv Library"
        $error[0].Exception
        return $False
    }
}#>

#
# Make sure the DVD drive exists on the VM
#
#$ide1 = Get-VMDiskController $vmName -server $hvServer -IDE 1
$dvd = Get-VMDvdDrive $vmName -ComputerName $hvServer -ControllerLocation 0 -ControllerNumber 1
if ($dvd)
{
    Remove-VMDvdDrive $dvd -Confirm:$False
    if($? -ne "True")
    {
        "Error: Cannot remove DVD drive from ${vmName}"
        $error[0].Exception
        return $False
    }
    else
    {
        "DVD drive removed"
        $retVal = $True
    }
}
else
{
    "Error: DVD drive not found on ${vmName}"
    return $False
}

return $retVal
