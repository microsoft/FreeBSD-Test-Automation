#######################################################################       
#
#HotAddRandomMultiSCSIDisks.ps1
#
# Run this script:
#
# cd WS2008R2\lisa\setupscripts
# .\HotAddRandomMultiSCSIDisks.ps1  -vmName  YourVMName  -hvServer "localhost"   -testParams "NO=3;MinimumLun=8"
# 
# NO -- Sum of the SCSI disks
# MinimumLun  -- minimum LUN 
#
#######################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams)


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

############################################################################
#
# CreateController
#
# Description
#     Create a SCSI controller if one with the ControllerID does not
#     already exist.
#
############################################################################
function CreateController([string] $vmName, [string] $server, [string] $controllerID)
{
    #
    # Hyper-V only allows 4 SCSI controllers - make sure the Controller ID is valid
    #
    if ($ControllerID -lt 0 -or $controllerID -gt 3)
    {
        write-output "    Error: Invalid SCSI controller ID: $controllerID"
        return $false
    }

    #
    # Check if the controller already exists
    # Note: If you specify a specific ControllerID, Get-VMDiskController always returns
    #       the last SCSI controller if there is one or more SCSI controllers on the VM.
    #       To determine if the controller needs to be created, count the number of 
    #       SCSI controllers.
    #
    $maxControllerID = 0
    $createController = $true
    $controllers = Get-VMDiskController -vm $vmName -ControllerID "*" -server $server -SCSI
    if ($controllers -ne $null)
    {
        if ($controllers -is [array])
        {
            $maxControllerID = $controllers.Length
        }
        else
        {
            $maxControllerID = 1
        }
        
        if ($controllerID -lt $maxControllerID)
        {
            "    Info : Controller exists - controller not created"
            $createController = $false
        }
    }
    
    # If needed, create the controller
    if ($createController)
    {
        $ctrl = Add-VMSCSIController -vm $vmName -name "SCSI Controller $ControllerID" -server $server -force
        if ($ctrl -eq $null -or $ctrl.__CLASS -ne 'Msvm_ResourceAllocationSettingData')
        {
            "    Error: Add-VMSCSIController failed to add 'SCSI Controller $ControllerID'"
            return $false
        }
        "    Controller successfully added"
    }
	
	return $true
}


############################################################################
#
# CreateHardDrive
#
# Description
#     If the -SCSI options is false, an IDE drive is created
#
############################################################################
function CreateHardDrive( [string] $vmName, [string] $server, [System.Boolean] $SCSI, [int] $ControllerID,
                          [int] $Lun, [string] $vhdType)
{
    $retVal = $false

    "Enter CreateHardDrive $vmName $server $scsi $controllerID $lun $vhdType"
    
    $controllerType = "IDE"
    
    # Make sure it's a valid IDE ControllerID.  For IDE, it must 0 or 1.
    # For SCSI it must be 0, 1, 2, or 3
    if ($SCSI)
    {
        if ($ControllerID -lt 0 -or $ControllerID -gt 3)
        {
            "Error: CreateHardDrive was passed an invalid SCSI Controller ID: $ControllerID"
            return $false
        }
        
        # Create the SCSI controller if needed
        $sts = CreateController $vmName $server $controllerID
        $controllerType = "SCSI"
    }
    else # Make sure the controller ID is valid for IDE
    {
        if ($ControllerID -lt 0 -or $ControllerID -gt 1)
        {
            "Error: CreateHardDrive was passed an invalid IDE Controller ID: $ControllerID"
            return $false
        }
    }
    
    # If the hard drive exists, complain. Otherwise, add it
    $drives = Get-VMDiskController -vm $vmName -ControllerID $ControllerID -server $server -SCSI:$SCSI -IDE:(-not $SCSI) | Get-VMDriveByController -Lun $Lun
    if ($drives)
    {
        write-output "Error: drive $controllerType $controllerID $Lun already exists"
        return $retVal
    }
    else
    {
        $newDrive = Add-VMDrive -vm $vmName -ControllerID $controllerID -Lun $Lun -scsi:$SCSI -server $server
        if ($newDrive -eq $null -or $newDrive.__CLASS -ne 'Msvm_ResourceAllocationSettingData')
        {
            write-output "Error: Add-VMDrive failed to add $controllerType drive on $controllerID $Lun"
            return $retVal
        }
    }
    
    # Create the .vhd file if it does not already exist
    $defaultVhdPath = Get-VhdDefaultPath -server $server
    if (-not $defaultVhdPath.EndsWith("\"))
    {
        $defaultVhdPath += "\"
    }
    
    $currentTime = Get-Date -Format 'yyyymdhms'
    $vhdName = $defaultVhdPath + $vmName + "-" + $controllerType + "-" + $controllerID + "-" + $Lun + "-" + $vhdType + "-" + $currentTime + ".vhd"
    
    #Record the path of the new vhd
    $newVHDListsPath =  ".\NewVhdLists.log"  #Note: this file path must be as same as the path in RemoveHardDisk.ps1
    $listContent = $vhdName + ","
    $listContent | Out-File $newVHDListsPath -NoClobber -Append
    
    $fileInfo = GetRemoteFileInfo -filename $vhdName -server $hvServer

    if (-not $fileInfo)
    {
        $newVhd = $null
        switch ($vhdType)
        {
            "Dynamic"
                {
                    $newVhd = New-Vhd -vhdPaths $vhdName -size 1GB -server $server -force -wait
                }
            "Fixed"
                {
                    $newVhd = New-Vhd -vhdPaths $vhdName -size 1GB -server $server -fixed -force -wait
                }
            "Diff"
                {
                    $parentVhdName = $defaultVhdPath + "icaDiffParent.vhd"
                    $parentInfo = GetRemoteFileInfo -filename $parentVhdName -server $hvServer
                    if (-not $parentInfo)
                    {
                        Write-Output "Error: parent VHD does not exist: ${parentVhdName}"
                        return $retVal
                    }
                    $newVhd = New-Vhd -vhdPaths $vhdName -parentVHD $parentVhdName -server $server -Force -Wait
                }
            default
                {
                    Write-Output "Error: unknown vhd type of ${vhdType}"
                    return $retVal
                }
        }
       
        if ($newVhd -eq $null)
        {
            write-output "Error: New-VHD failed to create the new .vhd file: $($vhdName)"
            return $retVal
        }
    }
    
    # Attach the .vhd file to the new drive
    $disk = Add-VMDisk -vm $vmName -ControllerID $controllerID -Lun $Lun -Path $vhdName -SCSI:$SCSI -server $server
    if ($disk -eq $null -or $disk.__CLASS -ne 'Msvm_ResourceAllocationSettingData')
    {
        write-output "Error: AddVMDisk failed to add $($vhdName) to $controllerType $controllerID $Lun $vhdType"
        return $retVal
    }
    else
    {
        write-output "Success"
        $retVal = $true
    }
    
    return $retVal
}




############################################################################
#
# Main entry point for script
#
############################################################################

# Load the HyperVLib version 2 modules
$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2SP1\Hyperv.psd1
}

$retVal = $true

# Check input arguments
if ($vmName -eq $null -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $False
}

if ($hvServer -eq $null -or $hvServer.Length -eq 0)
{
    "Error: hvServer is null"
    return $False
}


#Default parameters
$numDisks = 3
$MinimumLun = 0

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    
    if ($fields[0].Trim() -eq "NO")
    {
        $numDisks = $fields[1].Trim()
    }
	
	 if ($fields[0].Trim() -eq "MinimumLun")
    {
        $MinimumLun = $fields[1].Trim()
    }
}

#LUN starts with 0 and ends with 63
if( [int]$MinimumLun -lt 0 )
{
	$MinimumLun = 0
}

if( [int]$MinimumLun -gt 63 )
{
	$MinimumLun = 63
}

$maxDisksLeft = 64 - [int]$MinimumLun
if( [int]$numDisks -gt [int]$maxDisksLeft )
{
	$numDisks = $maxDisksLeft
}

$SCSI = $true
$controllerID  = 0
$controllerType = "SCSI"

"To create $numDisks SCSI disks on $vmName"
do 
{
	$random = Get-Random
	$Lun = $random % 64
} while( $Lun -lt $MinimumLun )


for( $i = 0; $i -lt $numDisks; $i++ )
{
	# Get a random LUN 
	do 
	{
		$drive = Get-VMDiskController -vm $vmName -ControllerID $ControllerID -server $hvServer -SCSI:$SCSI -IDE:(-not $SCSI) | Get-VMDriveByController -Lun $Lun
   		if ($drive)
		{
			do 
			{
				$random = Get-Random
				$Lun = $random % 64
			} while( $Lun -lt $MinimumLun )
		}
		else
		{
			break
		}

	} while(1)
	
	"Info: The LUN is $Lun"
	
	#Create hard drive
	$sts = CreateHardDrive -vmName $vmName -server $hvServer -SCSI:$SCSI -ControllerID $controllerID -Lun $Lun -vhdType "Dynamic"
	if (-not $sts[$sts.Length-1])
	{
		write-output "Failed to create hard drive"
		$sts
		$retVal = $false
		break
	}
	
	sleep 10
}

return $retVal
