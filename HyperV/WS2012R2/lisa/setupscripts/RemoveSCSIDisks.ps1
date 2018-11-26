
############################################################################
#
# RemoveSCSIDisks.ps1
#
#
############################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams)


############################################################################
#
# Main entry point for script
#
############################################################################

$retVal = $false

#
# Check input arguments
#
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


#
# Make sure we have access to the Microsoft Hyper-V snapin
#
$hvModule = Get-Module Hyper-V
if ($hvModule -eq $NULL)
{
    import-module Hyper-V
    $hvModule = Get-Module Hyper-V
}


$controllerType = "SCSI"
$drivers =  Get-VMHardDiskDrive -VMName $vmName -ControllerType   $controllerType  -ComputerName $hvServer
if( $drivers -ne $null)
{
	foreach( $driver in $drivers)
	{
		"Deleting $driver ..."
		$sts = Remove-VMHardDiskDrive $driver
		"Delete $driver done"
	}
}


#
#Delete the vhd/vhdx file from the local disk for saving space
#
. .\utilFunctions.ps1 | out-null
$newVHDListsPath = ".\NewVhdxLists.log" #Note: this file path must be as same as the path in HotAddRandomMultiSCSIDisks.ps1
$status = Test-Path $newVHDListsPath  
if( $status -eq "True" )
{
	DeleteVHDInFile (Resolve-Path $newVHDListsPath).Path
}



return $true
