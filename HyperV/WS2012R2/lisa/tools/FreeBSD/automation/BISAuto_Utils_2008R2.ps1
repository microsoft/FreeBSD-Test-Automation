
write-host -f Green  "Info: Source BISAuto_CommonUtils.ps1 file"
. .\tools\FreeBSD\automation\BISAuto_CommonUtils.ps1 | out-null	

$sts = Get-Module -Name HyperV
if( $sts -eq $null )
{
	write-host -f Green  "Info: To import-module  HyperV"
	Import-module .\HyperVLibV2Sp1\Hyperv.psd1
}
else
{
	write-host -f Green  "Info: HyperV module already been imported"  
}


#Create a snapshot(checkpoint) with name $snapshotName
function CreateSnapshot([System.Xml.XmlElement] $vm)
{
	#To create a snapshot
	LogMsg 3 "Info: Start to create snapshot on $($vm.vmName) VM"
	New-VMSnapshot -VM $vm.vmName  -Server $vm.hvServer  -Confirm:$False -Wait | out-null
	if ($? -eq "True")
    {
		LogMsg 3 "Info: create snapshot on $($vm.vmName) VM successfully"
    }
    else
    {
		LogMsg 0 "Error: create snapshot on $($vm.vmName) VM failed"
        return 1
    }
	
	#To rename the snapshot with $snapshotName
	$sts = RenameSnapshot $vm
	
	return $sts
}


function RenameSnapshot([System.Xml.XmlElement] $vm)
{
	#To rename the snapshot with $snapshotName
	LogMsg 3 "Info: Start to rename snapshot with $snapshotName on $($vm.vmName) VM"
	Get-VMSnapshot -VM $vm.vmName -Server $vm.hvServer  -Current | Rename-VMSnapshot -newname $snapshotName  -Force  | out-null
	if ($? -eq "True")
    {
		LogMsg 3 "Info: rename snapshot with  $snapshotName on $($vm.vmName) VM successfully"
    }
    else
    {
		LogMsg 0 "Error: rename snapshot with  $snapshotName on $($vm.vmName) VM failed"
        return 1
    }
	
	return 0
}



#Add 3 disks in "Computer Management" for "Pass Through Drive" feature test 
Function AddPassThroughDisks([String] $vhdDir, [String] $hvServer)
{
    #first check whether there are at least 3 virtual disks in host
    $measure = "list vdisk" | DISKPART | select-string "Attached" | Measure-Object -Line
    if ($measure.Lines -ge 3)
    {
		LogMsg 0 "Info: there are already $($measure.Lines) virtual disks in Host"
        return 0
    }
	
    $vhdSize = 1GB
    for($i = 1; $i -le 3; $i++)
    {
		$status = "False"
        $vhdPath = $vhdDir + "PassThroughDisk" + $i + ".vhd"
		$status = Test-Path $vhdPath
		if( $status -eq "True" )
		{
			LogMsg 3 "Info: vhd disk: $vhdPath already exists on $hvServer" 
		}
		else
		{
			LogMsg 3 "Info: creating vhd disk: $vhdPath on $hvServer" 
			$newVhd = New-VHD -VHDPaths $vhdPath -size $vhdSize -Server $hvServer -Fixed
			if ($? -eq $false)
			{
				LogMsg 0 "Error: creating vhd disk: $vhdPath on $hvServer failed" 
				return 1
			}		
		}
		
        # echo "attaching vhd disk: $vhdPath"
		LogMsg 3 "Info: attaching vhd disk: $vhdPath"
        @("select vdisk file=""$vhdPath""", "attach vdisk", "convert GPT", "offline disk") | DISKPART |Out-Null
    }
	
	return 0
}

#Copy diff disks
Function CopyDiffDisks()
{
    $vhdNames = @("icaDiffParent.vhd", "icaDiffVhdx4k.vhdx", "icaDiffVhdx512.vhdx")
    foreach($vhd in $vhdNames)
    {
        $vhdPath = $RemotePath + $vhd
		
		$localFilePathe = $HyperVDir+$vhd
		$status = Test-Path $localFilePathe
		if( $status -eq "True" )
		{
			LogMsg 0 "Warning: $localFilePathe already exists, ignore coping"
			continue
		}
		
		LogMsg 3 "Info: copying vhd disk: $vhdPath"
        Copy-Item  -LiteralPath $vhdPath -Destination $HyperVDir -Force  | out-null
    }
	
	return 0
}

Function CreateNetworkSwitch([String] $swithName, [String] $swithType)
{
    $switches = Get-VMSwitch -Name $swithName -SwitchType $swithType
    if ($switches.Count -ge 1)
    {
		LogMsg 0 "Warning:There is already one $($swithName) switch"
        return 0
    }

    New-VMSwitch -Name $swithName -SwitchType $swithType
    if ($? -eq "True")
    {
		LogMsg 0 "Info:Create $($swithName) switch successfully"
    }
    else
    {
        LogMsg 0 "Error:Create $($swithName) switch failed"
		return 1
    }
	
	return 0
}

#Create 3 network switches: InternalNet, PrivateNet, ExternalNet
Function CreateNetworkSwitches( [String]$hvServer)
{
	LogMsg 3 "Info:Creating network switches, need a few minutes..."
    CreateNetworkSwitch "Internal" "Internal"
    CreateNetworkSwitch "Private" "Private"

    $swithName = "External"
    $switches = Get-VMSwitch -Name $swithName -Server $hvServer
    if ($switches.Count -ge 1)
    {
		LogMsg 0 "Warning:There is already one $($swithName) switch"
        return 0
    }

	LogMsg 3 "Info:To get network adapter"
    $adapter = Get-NetAdapter -Physical
    if ($? -eq "True")
    {
        $adapterName = ""
        if ($adapter.Count -gt 1)
        {
			LogMsg 0 "Warning: There are more than one network adapters, please set external switches manually"
            $adapterName = $adapter[0].Name
        }
        else
        {
            $adapterName = $adapter.Name
        }
    
        New-VMSwitch "External" -NetAdapterName $adapterName -Server $hvServer
        if ($? -eq "True")
        {
			LogMsg 0 "Info:Create ExternalNet switch successfully"
        }
        else
        {
			LogMsg 0 "Error:Create ExternalNet switch failed"
			return 1
        }
    }
    else
    {
		LogMsg 0 "Error: Could not find physical adapter, Create ExternalNet switch failed"
		return 1
    }
	
	LogMsg 3 "Info:Create network switches successfully"
	return 0
}

Function ConfigureExternalVM([String] $vhdName, [String] $switchName, [String] $hvServer)
{
	LogMsg 3 "Info: RemotePath: $RemotePath  vhdName: $vhdName switchName: $switchName "
    $vhdPath = $RemotePath + $vhdName + ".vhd"

	$localFilePath = $HyperVDir+$vhdName + ".vhd"
	$status = Test-Path $localFilePath
	if( $status -eq "True" )
	{
		LogMsg 0 "Warning: $localFilePath already exists, ignore coping"
	}
	else
	{
		LogMsg 3 "Info: copying vhd disk: $vhdPath"
		Copy-Item  -LiteralPath $vhdPath -Destination $HyperVDir -Force  | out-null
	}
	
	LogMsg 3 "Info: Check state before  creating VM $vhdName"
	$status = Get-VM  $vhdName  -Server $hvServer  2>null
	if( $status -ne $null )
	{
		LogMsg 0 "Warning: $vhdName already exists, ignore create $vhdName"	
		return 0
	}
	
	LogMsg 3 "Info: To create VM $vhdName"
    $vhdPath = $HyperVDir + $vhdName + ".vhd"
    New-VM –Name $vhdName –MemoryStartupBytes 512MB –VHDPath $vhdPath -SwitchName $switchName -Server $hvServer | out-null
	if ($? -eq "True")
	{
		LogMsg 3 "Info: Create VM $vhdName successfully"
	}
	else
	{
		LogMsg 0 "Error: Create VM $vhdName failed"
		return 1
	}
	
	LogMsg 3 "Info: To start VM $vhdName"
    Start-VM -Name $vhdName -Server $hvServer | out-null
    if ($? -eq "True")
    {
		LogMsg 3 "Info: Start VM $vhdName successfully"
    }
    else
    {
        LogMsg 0 "Error: Start VM $vhdName failed"
		return 1
    }
	
	return 0
	
}

#Create 2 VMs which connect to InternalNet and PrivateNet respectively
Function ConfigureExternalVMs( [String] $hvServer )
{
	LogMsg 3 "Info: hvServer is $hvServer in ConfigureExternalVMs "
    $sts = ConfigureExternalVM "Oracle7_StaticIP_InternalNet" "InternalNet"   $hvServer
	if( $sts -ne 0 )
	{
		LogMsg 0 "Error: ConfigureExternalVMs $sts"
		return 1
	}
	
    $sts = ConfigureExternalVM "Oracle7_StaticIP_PrivateNet" "PrivateNet"   $hvServer
	if( $sts -ne 0 )
	{
		LogMsg 0 "Error: ConfigureExternalVMs $sts"
		return 1
	}
	
	return 0
}



function StartVMAndWait([System.Xml.XmlElement] $vm){
	LogMsg 3 "Info: VM $($vm.vmName) is starting and wait it boot completely"
	LogMsg 3 "Info: It will takes more than one minute, please wait with patience"

	start-vm $vm.vmName  -Server $vm.hvServer | out-null
	
	#detect heart beat of VM
	$hb = Test-VmHeartbeat -vm $vm.vmName -Server $vm.hvServer -HeartBeatTimeOut 65
	if ($hb -ne $null)
	{
		if ($hb.status -eq "OK")
		{
			#Booting VM needs more time after adding ping arp server command in /etc/rc.conf
			sleep 65
			LogMsg 3 "Info: VM $($vm.vmName)  starts and boots completely" 
			
			return 0
		}
	}
	
	sleep 30
	LogMsg 3 "Warning: Can't get heart beat of VM $($vm.vmName) "
	LogMsg 3 "Info: VM $($vm.vmName) starts and boots completely"
	
	return 0
}



function ApplySnapshot([System.Xml.XmlElement] $vm)
{
	LogMsg 3 "Info : $($vm.vmName) ready to apply snapshot"  
	# Find the snapshot we need and apply the snapshot
		
    $snapshotFound = $false
	$snap = Get-VMSnapshot $vm.vmName  -Server  $vm.hvServer  -name $snapshotName 
	if( $snap -ne $null )
	{
		LogMsg 0 "snap is $snap" "Green"
		Get-VMSnapshot $vm.vmName  -Server  $vm.hvServer  -name $snapshotName | Restore-VMSnapshot -Force
		if( $? -eq $false )
		{
			 LogMsg 0 "Error: Apply snapshot of $($vm.vmName) on HyperV server $($vm.hvServer) failed"
			 return 1
		}
		
		$snapshotFound = $true
	
	}

    # Make sure the snapshot left the VM in a stopped state.
    if ($snapshotFound )
    {
        # If a VM is in the Suspended (Saved) state after applying the snapshot,
        # the following will handle this case

		LogMsg 3 "Info :To search the snapshot named $snapshotName, then check the state of the VM"
        $v = Get-VM $vm.vmName -Server $vm.hvServer
        if ( $($v.enabledstate) -eq 32768 )   #32768 means "paused"
        {
            LogMsg 3 "Info : $($vm.vmName) - resetting to a stopped state after restoring a snapshot"
            Stop-VM $vm.vmName -Server $vm.hvServer -Force | out-null
        }
    }
    else
    {
        LogMsg 0 "Warning : $($vm.vmName) does not have a snapshot named $snapshotName."
        LogMsg 3 "Info : $($vm.vmName) to create a snapshot named $snapshotName now."

		#To create a snapshot named ICABase
		$sts = CreateSnapshot $vm
		if( $sts -ne  0 )
		{
			LogMsg 0 "Error: create snapshot on VM $($vm.vmName) VM failed"
			return 1
		}
		
		#Apply Snapshot
		LogMsg 3 "Info : $($vm.vmName) starts to apply $snapshotName snapshot"
		Get-VMSnapshot $vm.vmName  -Server  $vm.hvServer  -name $snapshotName | Restore-VMSnapshot -Force
		if( $? -eq $false )
		{
			 LogMsg 0 "Error: Apply snapshot of $($vm.vmName) on HyperV server $($vm.hvServer) failed"
			 return 1
		}
		
		$v = Get-VM $vm.vmName -Server $vm.hvServer
        if ( $($v.enabledstate) -eq 32768 )   #32768 means "paused"
        {
            LogMsg 3 "Info : $($vm.vmName) - resetting to a stopped state after restoring a snapshot"
            Stop-VM $vm.vmName -Server $vm.hvServer -Force | out-null
        }
		

    }
	
	LogMsg 3 "Info : $($vm.vmName) apply snapshot successfully"
    return 0
}

function DeleteSnapshot([System.Xml.XmlElement] $vm)
{
	#delete snapshot
	LogMsg 3 "Info : $($vm.vmName) to delete snapshot $snapshotName"
	Get-VMSnapshot $vm.vmName  -Server $vm.hvServer  -name $snapshotName | Remove-VMSnapshot -Force | out-null
	if( $? -eq $false )
	{
	     LogMsg 0 "Error: delete snapshot of $($vm.vmName) on HyperV server $($vm.hvServer) failed"
		 return 1
	}
	
	#Make sure delete snapshot successfully
	LogMsg 3 "Info : Make sure delete snapshot successfully on $($vm.vmName)"
	$timeout = 30
	do
	{
	    sleep 1
	    $snap = Get-VMSnapshot $vm.vmName -Server $vm.hvServer  -name $snapshotName
		$timeout -= 1
	}while( $snap.ElementName -and ( $timeout -gt 0 ) )
	
	if( $timeout -le 0 )
	{
	     LogMsg 0 "Error: delete snapshot of $($vm.vmName) on HyperV server $($vm.hvServer) failed"
		 return 1
	}
	else
	{
		 LogMsg 3 "Info: delete snapshot of $($vm.vmName) on HyperV server $($vm.hvServer) successfully"
	}
	
	
    return 0
}



#Get IP via arp server and return an useful IP address 
function GetIPViaArpServer([System.Xml.XmlElement] $vm)
{
    $networkAdapters = Get-VMNic $vm.vmName -Server $vm.hvServer
    if ( $? -ne "True")
    {
		LogMsg 0 "Error: Get network adapters failed"
        return $null
    }

	LogMsg 3 "Info: Get arp -a information lists from $ArpServerName"
	$arpInfoLists = Invoke-Command –ComputerName $ArpServerName  {arp -a}
	if ( $? -ne "True")
    {
		LogMsg 0 "Error: Get arp -a information lists from $ArpServerName failed"
        return $null
    }

	# Get the MAC address of the VMs NIC and query the IP matching with MAC
    foreach($adapter in $networkAdapters)
    {
        $macAddr = $adapter.Address
        if($macAddr)
        {
			#Change mac address format: From "aabbccddeeff" to "aa-bb-cc-dd-ee-ff"
			$macAddr = $macAddr -replace "(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})", '$1-$2-$3-$4-$5-$6'
			LogMsg 3 "Info: MAC address of VM $($vm.vmName) is $macAddr"  
			
			#Get IP address via MAC address
            $ipv4 = QueryIPViaMacAddr $vm.sshKey  $macAddr $arpInfoLists  
            if($ipv4)
            {	
				LogMsg 3 "Info: Get ipv4 is $ipv4"  
                return $ipv4
            }
        }
    }
	
	return $null
	
}



#currently, we would use arp server to get IP.
#In the future, we will add more methods of getting IP address.
function GetIPAdress([System.Xml.XmlElement] $vm)
{
	$times = 1
	do{
		LogMsg 3 "Info: It is $times time(s) for trying to get IP via arp server"
		$ip = GetIPViaArpServer $vm
		if( ( $ip -ne $null ) -and ( $ip -ne 1 ) )
		{
			return $ip
		}
		
		#Try it again after 30 seconds, and the total trial times are 3
		$times += 1
		sleep 30
	}while( $times -lt 4 )
	
	return $ip
}



