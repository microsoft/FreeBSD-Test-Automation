#
#Common utils functions regardless of hyperv version
#

$snapshotName = "ICABase"

#Hyper-V Preparation
$RemotePath = "\\wssgfsc\SHOSTC\public\xiazhang\BISAuto\"

#Make sure the following hyper-v path exists
$HyperVDir = "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\"	


#Save the xml file after change its content
function SaveXMLFile([xml] $xmlConfigContent, [string] $xmlFile )
{
	#Check whether the file exists
	$status = Test-Path $xmlFile
	if( $status -ne "True" )
	{
		LogMsg 0 "Error: $xmlFile doesn't exist" 
		return 1
	}
	
	#Change relative path to absolute path
	$file = Resolve-Path $xmlFile
	
	#save file
	$xmlConfigContent.Save($file.path)
	LogMsg 3 "Info: Save $file successfully" 
	
	return 0
}



# The first time we SSH into a VM, SSH will prompt to accept the server key.
# Send a "ll" command to the VM and assume this is the first SSH connection,
# so pipe a 'y' response into plink
function SSHLoginPrepare( [string] $sshKey, [string] $hostname )
{
	echo y | bin\plink -i ssh\${sshKey} root@${hostname} "ll"  2> $null  | out-null
	if( $? -ne "True" )
	{
		return 1
	}
	
	return 0
}



#Get IP address via MAC address
function QueryIPViaMacAddr( [string] $sshKey, [string] $mac, $arpInfo )
{
	#Get ip address by matching MAC address
	$ips = $arpInfo | select-string $mac | % { $_.ToString().Trim().Split(" ")[0] }
	
	foreach($ipAddress in $ips)
    {
		LogMsg 3 "Info: Try to check IP $ipAddress whether useful" 
		sleep 2
		#Here, SSHLoginPrepare function achieve two goals:
        #(1)Check the IP address whether useful	
		#(2)Store the server's host key in cache if the IP address can be used
		$sts = SSHLoginPrepare   $sshKey  $ipAddress
		if( $sts -eq 0 )
		{
			LogMsg 3 "Info: This IP address $ipAddress is useful" 
			return $ipAddress
		}
		
    }

	return $null
}


#Update the global variable
function UpdateGlobalVariable([System.Xml.XmlElement] $vm)
{
	$xmlFilenameForEeachVM = $relativePathOfEachVM + $($vm.vmName) +".xml"
	
	$xmlFilePathOfVM = [xml] (Get-Content -Path $xmlFilenameForEeachVM)  2>null
	if ($null -eq $xmlFilePathOfVM)
	{
		LogMsg 0 "Error: Unable to parse the $($vm.vmName).xml, please check it exists or its format is right"
		return 1
	} 
	
	$global:SpecifiedVm = $xmlFilePathOfVM.config.VMs.vm
	
	return 0
}


#Wait SSH log into VM at the first time until time out
function WaitSSHLoginPrepare( [string] $sshKey, [string] $hostname )
{
	LogMsg 3 "Info: Wait SSH log into VM at the first time until time out"
	$times = 0
	do
	{
		$sts = SSHLoginPrepare  $sshKey  $hostname
		if( $sts -eq 0 )
		{
			return 0
		}
		
		#Try it again after 5 seconds, and the total trial times are 20
		$times += 1
		sleep 5
		LogMsg 3 "Warning: Connect to $hostname time out, now retry ..."
	}while( $times -lt 20 )

	return 1
}

#We would reset and save the IP address in configure file if it changes.
#Also we need to update the global variable so that the later process can use the new IP address.
function SetIPAddress([System.Xml.XmlElement] $vm)
{
	#Get the IP address in configure file
	$oldIP = $($vm.ipv4)
	
	#Get dynamic IP address from running VM
	LogMsg 3 "Info: Try to get IP address from VM $($vm.vmName) "
    $newIP = GetIPAdress $vm
	if( $newIP -eq 1 )
	{
		return 1
	}
	
    if( $newIP -eq $null )
    {
        LogMsg 3 "Warning: Can't get IP address, so use the IP $($vm.ipv4) in $($vm.vmName).xml"
		LogMsg 3 "Info: Store the server's host key in cache"
		
		$sts = WaitSSHLoginPrepare   $vm.sshKey  $oldIP
		if( $sts -ne 0 )
		{
			LogMsg 3 "Error: Store the server's host key in cache failed"
			return 1
		}
		
	    return 0
    }
	
    LogMsg 3 "Info: Get IP($newIP) from VM $($vm.vmName) successfully"  "Green"	
	
	#Make sure that we store the server's host key in cache
	LogMsg 3 "Info: Store the server's host key in cache"
	$sts = WaitSSHLoginPrepare  $vm.sshKey  $newIP
	if( $sts -ne 0 )
	{
		LogMsg 3 "Error: Store the server's host key in cache failed"
		return 1
	}
   
    #Compare IP addresses
    if(  $oldIP -eq $newIP )
    {
	    LogMsg 3 "Info: IP address doesn't change." 
		return 0
    }
   
	#The IP address already changes, so need to modify and save it in configure file
	$xmlFilename = $relativePathOfEachVM + $($vm.vmName) +".xml"
	
	$xmlConfig = [xml] (Get-Content -Path $xmlFilename)  2>null
	if ($null -eq $xmlConfig)
	{
		LogMsg 0 "Error: Unable to parse the $($vm.vmName).xml, please check it exists or its format is right"
		return 1
	}
	
	LogMsg 3 "Warning: Change $oldIP to $newIP in $xmlFilename"
	$xmlConfig.config.VMS.vm.ipv4 =  [string]$newIP
	
	LogMsg 3 "Info: Ready to save $xmlFilename"
	$sts = SaveXMLFile  $xmlConfig $xmlFilename  
	if( $sts -ne 0 )
	{
		LogMsg 0 "Error: Save $xmlFilename failed"
		return 1
	}
	LogMsg 3 "Info: Save $xmlFilename successfully"
	
	#After changing the IP address, we need update the global variable
	$sts = UpdateGlobalVariable $vm
	
	return $sts	
}



#Wait VM boot completely until time out
function WaitVMBootFinish([System.Xml.XmlElement] $vm)
{
	LogMsg 3 "Info: Wait VM $($vm.vmName) booting ..." 

	$TotalTime = 36
	do
	{
		$sts = TestPort $vm.ipv4 -port 22 -timeout 5
		if ($sts)
		{
			LogMsg 3 "Info: VM $($vm.vmName) boots successfully" 
			break
		}
		sleep 5
		$TotalTime -= 1		
	} while( $TotalTime -gt 0 )
	
	if( $TotalTime -lt 0 )
	{
		LogMsg 3 "Error: VM $($vm.vmName) boots failed for time-out"
		return 1
	}
	
	return 0
}






