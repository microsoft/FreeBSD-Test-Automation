#######################################################################
#
# InsertIsoInDvd.ps1
#
# Description:
#    This script will "mount" a .iso file into the VMs default DVD
#    drive (IDE 1 0).
#
#    The .iso file is identified via a testParam of
#        IsoFilename=my.iso
#
#    If just the filename is specified (name is not an absolute path),
#    then the HyperV DefaultVhdPath will be prepended to the filename.
#
#    Check are made to make sure the file exists on the HyperV server
#    and that the VM does have a IDE 1 0 DVD drive.
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


"insertIsoInDvd.ps1"
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

if (-not $testParams)
{
    "Error: Missing testParams argument"
    return $False
}

#
# Extract the testParams we are concerned with
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
	    # Just ignore it
        continue
    }
    
    $lValue = $tokens[0].Trim()
    $rValue = $tokens[1].Trim()
    
    if ($lValue -eq "IsoFilename")
    {
        $isoFilename = $rValue
    }
}

#
# Make sure we found the parameters we need to do our job
#
if (-not $isoFilename)
{
    "Error: Test parameters is missing the IsoFilename parameter"
    return $False
}

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
# Make sure the DVD drive exists on the VM
#
$ide1 = Get-VMDiskController $vmName -server $hvServer -IDE 1
if (-not $ide1)
{
    "Error: Cannot find IDE controller 1 on VM ${vmName}"
    $error[0].Exception
    return $False
}

$dvd = Get-VMDriveByController -Controller $ide1 -lun 0
if (-not $dvd)
{
    "Error: Cannot find DVD drive (IDE 1 0) on VM ${vmName}"
    $error[0].Exception
    return $False
}

#
# Make sure the .iso file exists on the HyperV server
#
if (-not ([System.IO.Path]::IsPathRooted($isoFilename)))
{
    $defaultVhdPath = Get-VhdDefaultPath -server $hvServer
   
	if (-not $defaultVhdPath)
    {
        "Error: Unable to determine VhdDefaultPath on HyperV server ${hvServer}"
        $error[0].Exception
        return $False
    }
   
    if (-not $defaultVhdPath.EndsWith("\"))
    {
        $defaultVhdPath += "\"
    }
  
    $isoFilename = $defaultVhdPath + $isoFilename
    
}   

$isoFileInfo = GetRemoteFileInfo $isoFilename $hvServer
if (-not $isoFileInfo)
{
    "Error: The .iso file $isoFilename does not exist on HyperV server ${hvServer}"
    return $False
}

#
# Insert the .iso file into the VMs DVD drive
#
$newDisk = Add-VMDisk -vm $vmName -ControllerID 1 -Lun 0 -Path $isoFilename -DVD -server $hvServer -Force
if (-not $newDisk)
{
    "Error: Unable to mount"
    $error[0].Exception
    return $False
}
else
{
    $retVal = $True
}

return $retVal
