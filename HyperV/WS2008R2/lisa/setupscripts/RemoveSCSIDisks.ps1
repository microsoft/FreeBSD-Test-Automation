
############################################################################
#
# RemoveSCSIDisks.ps1
#
############################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams)


############################################################################
#
# Main entry point for script
#
############################################################################

$retVal = $false

# Check input arguments
if ($vmName -eq $null -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $retVal
}

if ($hvServer -eq $null -or $hvServer.Length -eq 0)
{
    "Error: hvServer is null"
    return $retVal
}

# Load the HyperVLib version 2 modules
$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2SP1\Hyperv.psd1
}

$controllerType = "SCSI"
$ControllerID = 0
$SCSI = $true

for( $Lun = 0; $Lun -lt 64; $Lun++ )
{
	$drive = Get-VMDiskController -vm $vmName -ControllerID $ControllerID -server $hvServer -SCSI:$SCSI -IDE:(-not $SCSI) | Get-VMDriveByController -Lun $Lun
	if ($drive)
	{
		write-output "Info : Removing $controllerType $controllerID $Lun"
        $sts = Remove-VMDrive $vmName $controllerID $Lun -SCSI:$scsi -server $hvServer
	}
}

#Delete the vhd/vhdx file from the local disk for saving space
. .\utilFunctions.ps1 | out-null
$newVHDListsPath = ".\NewVhdLists.log" #Note: this file path must be as same as the path in HotAddRandomMultiSCSIDisks.ps1
$status = Test-Path $newVHDListsPath  
if( $status -eq "True" )
{
	DeleteVHDInFile (Resolve-Path $newVHDListsPath).Path
}

return $true
