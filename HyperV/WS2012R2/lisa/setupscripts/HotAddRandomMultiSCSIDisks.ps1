#######################################################################       
#
#HotAddRandomMultiSCSIDisks.ps1
#
# Run this script:
#
# cd WS2012R2\lisa\setupscripts
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
    # Initially, we will limit this to 4 SCSI controllers...
    #
    if ($ControllerID -lt 0 -or $controllerID -gt 3)
    {
        write-output "    Error: bad SCSI controller ID: $controllerID"
        return $False
    }

    #
    # Check if the controller already exists.
    #
    $scsiCtrl = Get-VMScsiController -VMName $vmName -ComputerName $server
    if ($scsiCtrl.Length -1 -ge $controllerID)
    {
        "Info : SCI ontroller already exists"
    }
    else
    {
        $error.Clear()
        Add-VMScsiController -VMName $vmName -ComputerName $server
        if ($error.Count -gt 0)
        {
            "    Error: Add-VMScsiController failed to add 'SCSI Controller $ControllerID'"
            $error[0].Exception
            return $False
        }
        "Info : Controller successfully added"
    }
    return $True
}

############################################################################
#
# GetPhysicalDiskForPassThru
#
# Description
#     
#
############################################################################
function GetPhysicalDiskForPassThru([string] $server)
{
    #
    # Find all the Physical drives that are in use
    #
    $PhysDisksInUse = @()

    $VMs = Get-VM -ComputerName $server
    foreach ($vm in $VMs)
    {
        $drives = Get-VMHardDiskDrive -VMName $($vm.name) -ComputerName $server
        if ($drives)
        {
            foreach ($drive in $drives)
            {
                if ($drive.Path.StartsWith("Disk "))
                {
                    $PhysDisksInUse += $drive.DiskNumber
                }
            }
        }
    }

    # in case of disk is being used by cluster we need to add those disk as well as PhysDisksInUse , as an workaround i will add all the disk which are online to used disk array.

    $disks = Get-Disk
    foreach ($disk in $disks)
    {
        if ($disk.OperationalStatus -eq "online" )
            {
                $PhysDisksInUse += $disk.Number
            }
    }   


    $physDrive = $null

    $drives = GWMI Msvm_DiskDrive -namespace root\virtualization\v2 -computerName $server
    foreach ($drive in $drives)
    {
        if ($($drive.DriveNumber))
        {
            if ($PhysDisksInUse -notcontains $($drive.DriveNumber))
            {
                $physDrive = $drive
                break
            }
        }
    }

    return $physDrive
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
                          [int] $Lun, [string] $vhdType, [string] $sectorSizes)
{
    $retVal = $false

    "CreateHardDrive $vmName $server $scsi $controllerID $lun $vhdType"

    # For SCSI it must be 0, 1, 2, or 3
    if ($SCSI)
    {
        $controllerType = "SCSI"

        if ($ControllerID -lt 0 -or $ControllerID -gt 3)
        {
            "Error: CreateHardDrive was passed an bad SCSI Controller ID: $ControllerID"
            return $false
        }
        
        # Create the SCSI controller if needed
        $sts = CreateController $vmName $server $controllerID
        if (-not $sts[$sts.Length-1])
        {
            "Error: Unable to create SCSI controller $controllerID"
            return $false
        }
    }
    else # Make sure the controller ID is valid for IDE
    {
		return $False
    }
    
	$hostInfo = Get-VMHost -ComputerName $server
	if (-not $hostInfo)
	{
		"Error: Unable to collect Hyper-V settings for ${server}"
		return $False
	}

	$defaultVhdPath = $hostInfo.VirtualHardDiskPath
	if (-not $defaultVhdPath.EndsWith("\"))
	{
		$defaultVhdPath += "\"
	}

	$currentTime = Get-Date -Format 'yyyymdhms'
	$vhdName = $defaultVhdPath + $vmName + "-" + $controllerType + "-" + $controllerID + "-" + $lun + "-" + $vhdType + "-" + $currentTime + ".vhdx" 
	
	#Record the path of the new vhd
	$newVHDListsPath =  ".\NewVhdxLists.log"  #Note: this file path must be as same as the path in RemoveSCSIDisks.ps1
	$listContent = $vhdName + ","
	$listContent | Out-File $newVHDListsPath -NoClobber -Append
	
	$fileInfo = GetRemoteFileInfo -filename $vhdName -server $server
	if (-not $fileInfo)
	{
	
		$nv = New-Vhd -Path $vhdName -size 1GB -Dynamic:($vhdType -eq "Dynamic") -LogicalSectorSize ([int] $sectorSize)  -ComputerName $server
		if ($nv -eq $null)
		{
			"Error: New-VHD failed to create the new .vhd file: $($vhdName)"
			return $False
		}
	}

	$error.Clear()
	Add-VMHardDiskDrive -VMName $vmName -Path $vhdName -ControllerNumber $controllerID -ControllerLocation $Lun -ControllerType $controllerType -ComputerName $server
	if ($error.Count -gt 0)
	{
		"Error: Add-VMHardDiskDrive failed to add drive on ${controllerType} ${controllerID} ${Lun}s"
		$error[0].Exception
		return $retVal
	}

	"Success"
	$retVal = $True
    
    return $retVal
}



############################################################################
#
# Main entry point for script
#
############################################################################

$retVal = $true

#
# Check input arguments
#
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

$maxDisksLeft = 64 - $MinimumLun
if( $numDisks -gt $maxDisksLeft )
{
	$numDisks = $maxDisksLeft
}

#Remove the dvd drive of the vm
Get-VMDvdDrive -VMName $vmName -ControllerNumber 1  | Remove-VMDvdDrive

$SCSI = $true
$controllerID  = 0
$controllerType = "SCSI"

"CreateHardDrive $vmName $hvServer $scsi $controllerID $Lun $controllerType"

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
		$drive = Get-VMHardDiskDrive -VMName $vmName -ControllerNumber $controllerID -ControllerLocation $Lun -ControllerType $controllerType -ComputerName $hvServer
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
	$sectorSize = 512
	$sts = CreateHardDrive -vmName $vmName -server $hvServer -SCSI:$SCSI -ControllerID $controllerID -Lun $Lun -vhdType $controllerType -sectorSize $sectorSize
	if (-not $sts[$sts.Length-1])
	{
		write-output "Failed to create hard drive"
		$sts
		$retVal = $false
		break
	}
}

return $retVal
