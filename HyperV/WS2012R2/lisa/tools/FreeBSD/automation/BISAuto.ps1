
param([string] $cmdVerb,
      [string] $cmdNoun,
	  [string] $branch,
      [switch] $examples,
	  [switch] $noRebuild,
      [int]    $dbgLevel=0
     )

$dbgLevel = 5

#Relative path of BISAuto configure .xml for each VM
$relativePathOfEachVM = ".\tools\FreeBSD\automation\"

#It's created in the build & install kernel process and it would indicate whether the shell script works well in VM
$autoPrepareLog = "sync_build_install.log"

#This script will run on the VM to sync code, build and install kernel
$FreeBSDFileName = "sync_build_install.sh"
$testFile = $relativePathOfEachVM + $FreeBSDFileName



########################################################################
#
# Usage()
#
########################################################################
function Usage()
{
    <#
    .Synopsis
        Display a help message.
    .Description
        Display a help message.  Optionally, display examples
        of usage if the -Examples switch is also specified.
    .Example
        Usage
    #>

    write-host "Usage: lisa cmdVerb cmdNoun [options]`r`n"
    write-host "    cmdVerb  cmdNoun      options     Description"
    write-host "    -------  -----------  ----------  -------------------------------------"
    write-host "    help                              : Display this usage message"
    write-host "                          -examples   : Display usage examples"
    write-host "    run      xmlFilename              : Run tests on VMs defined in the xmlFilename"
	write-host "                          -noRebuild  : Skip ""syncing, building and installing kernel"" step"
	write-host "                          -branch branchName  : Provide a git branch name"
    write-host "`n"
    
    if ($examples)
    {
        Write-host "`r`nExamples"
        write-host "    Run tests on all VMs defined in the specified xml file"
        write-host "    .\tools\FreeBSD\automation\BISAuto.ps1 run .\tools\FreeBSD\automation\BISAuto.xml"
		write-host "    .\tools\FreeBSD\automation\BISAuto.ps1 run .\tools\FreeBSD\automation\BISAuto.xml -noRebuild"
		write-host "    .\tools\FreeBSD\automation\BISAuto.ps1 run .\tools\FreeBSD\automation\BISAuto.xml -branch dev`r`n"
    }
}



########################################################################
#
# LogMsg()
#
########################################################################
function LogMsg([int]$level, [string]$msg, [string]$colorFlag)
{
    <#
    .Synopsis
        Write a message to the log file and the console.
    .Description
        Add a time stamp and write the message to the test log.  In
        addition, write the message to the console.  Color code the
        text based on the level of the message.
    .Parameter level
        Debug level of the message
    .Parameter msg
        The message to be logged
    .Example
        LogMsg 3 "Info: This is a test"
    #>

    if ($level -le $dbgLevel)
    {
        $now = [Datetime]::Now.ToString("MM/dd/yyyy HH:mm:ss : ")
        ($now + $msg) | out-file -encoding ASCII -append -filePath $logfile
        
        $color = "White"
        if ( $msg.StartsWith("Error"))
        {
            $color = "Red"
        }
        elseif ($msg.StartsWith("Warn"))
        {
            $color = "Yellow"
        }
        else
        {
            $color = "Gray"
        }

		#Print info in specified color
		if( $colorFlag )
		{
			$color = $colorFlag
		}
        
        write-host -f $color "$msg"
    }
}



########################################################################
#
# SendFileToVMUntilTimeout()
# Default time-out: 600 seconds
########################################################################
function SendFileToVMUntilTimeout([System.Xml.XmlElement] $vm, [string] $localFile, [string] $remoteFile, [string] $Timeout="600")
{
    LogMsg 3 "Info: Send file from $($vm.hvServer) to $($vm.vmName) in $Timeout seconds"

    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} ${localFile} root@${hostname}:${remoteFile}" -PassThru -NoNewWindow  -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    while(!$process.hasExited)
    {
        sleep 3
        $Timeout -= 1
        if ($Timeout -le 0)
        {
            LogMsg 3 "Info: Killing process for sending files from $($vm.hvServer) to $($vm.vmName)"
            $process.Kill()
            LogMsg 0 "Error: Send files from $($vm.hvServer) to $($vm.vmName) failed for time-out"
			
			return 1
        }
    }

	sleep 3
    LogMsg 0 "Info: Send files from $($vm.hvServer) to $($vm.vmName) successfully"
	
    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return 0
}



########################################################################
#
# GetFileFromVMUntilTimeout()
# Default time-out: 600 seconds
########################################################################
function GetFileFromVMUntilTimeout([System.Xml.XmlElement] $vm, [string] $remoteFile, [string] $localFile, [string] $Timeout="600")
{
    LogMsg 3 "Info: Get files from $($vm.vmName) to $($vm.hvServer) in $Timeout seconds"
	
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey
   
    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} root@${hostname}:${remoteFile} ${localFile}" -PassThru -NoNewWindow  -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    while(!$process.hasExited)
    {
        sleep 3
        $Timeout -= 1
        if ($Timeout -le 0)
        {
            LogMsg 3 "Info: Killing process for getting files from $($vm.vmName) to $($vm.hvServer)"
            $process.Kill()
            LogMsg 0 "Error: Get files from $($vm.vmName) to $($vm.hvServer) failed for time-out"
			
			return 1
        }
    }

	sleep 3
    LogMsg 0 "Info: Get files from $($vm.vmName) to $($vm.hvServer) successfully"
    
    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return 0
}




#####################################################################
#
# SendCommandToVMUntilTimeout()
#
#####################################################################
function SendCommandToVMUntilTimeout([System.Xml.XmlElement] $vm, [string] $command, [string] $commandTimeout)
{
    <#
    .Synopsis
        Run a command on a remote system.
    .Description
        Use SSH to run a command on a remote system.
    .Parameter vm
        The XML object representing the VM to copy from.
    .Parameter command
        The command to be run on the remote system.
    .ReturnValue
        True if the file was successfully copied, false otherwise.
    #>

    $retVal = $False

    $vmName = $vm.vmName
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    $process = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${hostname} ${command}" -PassThru -NoNewWindow -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
	LogMsg 3 "Info: Set Command = '$command' can be finished within $commandTimeout seconds."
    while(!$process.hasExited)
    {
        LogMsg 8 "Waiting 1 second to check the process status for Command = '$command'."
        sleep 1
        $commandTimeout -= 1
        if ($commandTimeout -le 0)
        {
            LogMsg 3 "Killing process for Command = '$command'."
            $process.Kill()
            LogMsg 0 "Error: Send command to VM $vmName timed out for Command = '$command'"
        }
    }

    if ($commandTimeout -gt 0)
    {
        $retVal = $True
        LogMsg 3 "Info: $vmName successfully sent command to VM. Command = '$command'"
    }
    
    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return $retVal
}
 


########################################################################
#
# SyncBuildInstallKernel()
#Function: (1)Sync, build and install kernel
#          (2)Check whether syncing, building and installing kernel successful on VM
#
########################################################################
function SyncBuildInstallKernel([System.Xml.XmlElement] $vm)
{
	#Don't need to sync, build and install kernel when run this script with "-noRebuild" parameter
	if( $noRebuild )
	{
		LogMsg 3 "Info: Skip ""syncing, building and installing kernel"" step"  "Yellow"
		return 0
	}
	
	#Send csh script from local host to VM
	LogMsg 3 "Info: $($vm.vmName) starts to send $testFile to $($vm.vmName)"
	$sts = SendFileToVMUntilTimeout  $vm $testFile
	if( $sts -ne 0 )
	{
		LogMsg 0 "Error: $($vm.vmName) send $testFile to $($vm.vmName) failed"
		return 1
	}
	
	#Send command from local host to VM 
	#Make sure the format of script on VM is unix 
	$Freebsdcmd = "/root/" + $FreeBSDFileName
	LogMsg 3 "Info: To set the format of script $FreebsdCmd on $($vm.vmName) being unix"
	if (-not (SendCommandToVMUntilTimeout $vm "dos2unix  $FreebsdCmd" "120") )
	{
		LogMsg 0 "Error: Unable to set the format of script $FreebsdCmd on $($vm.vmName) being unix"
		return 1
	} 
		
	#To set x bit of the script on VM
	LogMsg 3 "Info: To set x bit of the script $FreebsdCmd on $($vm.vmName)"
	if (-not (SendCommandToVMUntilTimeout $vm "chmod 755 $FreebsdCmd" "120") )
	{
		LogMsg 0 "Error: $($vm.vmName) unable to set x bit on test $FreebsdCmd script"
		return 1
	} 
	
	#Get the git branch
	if( $branch -eq "" )
	{
		$branch = $xmlConfig.config.global.defaultBranch
	}
	LogMsg 3 "Info: The git branch is $branch"  "Green"
	$FreebsdCmdPara = "-branch $branch"
	
	#Send command to run script on VM 
	#Note: This script will reboot the VM !!!
	LogMsg 3 "Info: To run the script $FreebsdCmd on $($vm.vmName) for Syncing, building and installing kernel"
	LogMsg 3 "Info: Generally this step will take a very long time ..."
	
	if (-not (SendCommandToVMUntilTimeout $vm "$FreebsdCmd  $FreebsdCmdPara" "3600") )
	{
		LogMsg 0 "Error: $($vm.vmName) unable to run $FreebsdCmd script"
		return 1
	} 
	
	LogMsg 3 "Info: The former step will reboot the VM, so please wait VM boot completely"
	LogMsg 3 "Info: It will takes more than one minute, please wait with patience"
	#Wait VM boots completely until time out
	$sts = WaitVMBootFinish $vm 
	if( $sts -ne 0 )
	{
		return 1
	}
	
	#Get log file from VM to local host		
	LogMsg 3 "Info: Get log file $autoPrepareLog from VM to local host"
	$sts = GetFileFromVMUntilTimeout  $vm $autoPrepareLog  $SpecifiedVmLogDir   
	if( $sts -ne 0 )
	{
		LogMsg 0 "Error: $($vm.vmName) get $autoPrepareLog from $($vm.vmName) failed"
		return 1
	}
	
	LogMsg 3 "Info: Get $autoPrepareLog from $($vm.vmName) successfully"    
	
	#Check whether syncing, building and installing kernel successful on VM
	$sts = CheckSyncBuildInstallKernel  $vm
	
	return $sts
}

########################################################################
#
# CheckSyncBuildInstallKernel()
#Function: Check the status of syncing, building and installing kernel whether successful by parse log file
#
########################################################################
function CheckSyncBuildInstallKernel([System.Xml.XmlElement] $vm)
{
	$logFileName = $SpecifiedVmLogDir + "\" + $autoPrepareLog
	
	if (! (test-path $logFileName))
    {
        LogMsg 0 "Error: '$logFileName' does not exist."
        return 1
    }
	
    $checkError = Get-Content $logFileName | select-string -pattern "Error"
	if( $checkError -eq $null )
	{
	    LogMsg 3 "Info: Sync, build and install kernel on VM $($vm.vmName) successfully"    "Green" 
		return 0
	}

    LogMsg 0 "Error: Sync, build and install kernel on VM $($vm.vmName) failed" 
	return 1

}




########################################################################
#
# HypervPrepare()
#
########################################################################
function HypervPrepare([System.Xml.XmlElement] $vm)
{
	$HyperVDir = "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\"
    $sts = AddPassThroughDisks  $HyperVDir $vm.hvServer
	
	if( $sts -ne 0 )
	{
		LogMsg 0 "Error: $($vm.vmName) on $($vm.hvServer) add pass through disks failed"
		return 1
	} 

		
	# $sts = CopyDiffDisks
	# if( $sts -ne 0 )
	# {
		# LogMsg 0 "Error: copy differ disks failed"
		# return 1
	# } 

		
	# $sts = ConfigureExternalVMs $vm.hvServer
	# if( $sts -ne 0 )
	# {
		# LogMsg 0 "Error: configure external VMs failed"
		# return 1
	# } 

	# $sts = CreateNetworkSwitches $vm.hvServer
	# if( $sts -ne 0 )
	# {
		# LogMsg 0 "Error: create network switches failed"
		# return 1
	# } 
	
	return 0
}



########################################################################
#
# GetOSVersion()
#
########################################################################
function GetOSVersion( )
{
	$OSVersion = (Get-WmiObject  -class Win32_OperatingSystem).Caption
	write-host -f Green  "Info: The operation system version is $OSVersion"
	$sts = $OSVersion | select-string "2008" 
	if( $sts -ne $null )
	{
		return "2008"
	}
	else
	{
		return "other"
	}
}



##################################################################################
#
#CreateDirIfNotExist()
#Function:Check the specified directory whether exists, if not, then create it.
##################################################################################
function CreateDirIfNotExist( [string] $Dir )
{
	$status = Test-Path $Dir  
	if( $status -ne "False" )
	{
		write-host -f Yellow  "Warning: $Dir does not exist, to create it"
		New-Item $Dir  -type directory	| out-null
		if( $? -ne "True")
		{
		    write-host -f Red  "Error: $Dir creates failed"
			return 1
		}
		else
		{
			write-host -f White  "Info: $Dir creates successfully"
		}
	}
	
	return 0
}



##################################################################################
#
#PrepareCommEnviromentBeforeTest()
#
##################################################################################
function PrepareCommEnviromentBeforeTest([XML] $xmlConfig)
{
	#Check log directory whether exist, if not, then create it
	$logDir = $xmlConfig.config.global.logfileRootDir  
	$sts = CreateDirIfNotExist $logDir
	if( $sts -eq 1 )
	{
		return 1
	}
	
	#Check history directory whether exist, if not, then create it
	$dirName = "history"
	$historyDir = $logDir + $dirName
	$sts = CreateDirIfNotExist $historyDir
	if( $sts -eq 1 )
	{
		return 1
	}
	
	#Move historical test results to history directory
	$sourcePath = $logDir + "*" 
	Get-Item -Path $sourcePath -Exclude $dirName | Move-Item -Destination $historyDir | out-null
	if( $? -ne "True" )
	{
		 write-host -f Red  "Error: Move historical test results to $historyDir  failed"
		 return 1
	}
	write-host -f White  "Info: Move historical test results to $historyDir successfully"
	
	#Get the global variable which would be used in other script
	$global:ArpServerName = $xmlConfig.config.global.arpServer

	return 0
}


########################################################################
#
# RunICTests()
#
########################################################################
function RunICTests([XML] $xmlConfig)
{
    if (-not $xmlConfig -or $xmlConfig -isnot [XML])
    {
		write-host -f Red "Error: RunICTests received an bad xmlConfig parameter - terminating LISA"
        return
    }
	
	$sts = PrepareCommEnviromentBeforeTest  $xmlConfig
	if( $sts -ne 0 )
	{
		return 1
	}
	
	#
	# Source the other files we need
	#
	$os = GetOSVersion
	if( $os -eq "2008" )
	{
		write-host -f Green  "Info: Source BISAuto_Utils_2008R2.ps1 file"
		. .\tools\FreeBSD\automation\BISAuto_Utils_2008R2.ps1 | out-null	
	}
	else
	{
		write-host -f Green  "Info: Source BISAuto_Utils.ps1 file"
		. .\tools\FreeBSD\automation\BISAuto_Utils.ps1 | out-null	
	}
	
	. .\utilFunctions.ps1 | out-null

	foreach ($vm in $xmlConfig.config.VMs.vm)
	{
		if($vm) 
		{
		
			#get configure file by the provided VM name
			$xmlFilenameForEeachVM = $relativePathOfEachVM + $($vm.vmName) +".xml"
			
			$xmlConfigForEeachVM = [xml] (Get-Content -Path $xmlFilenameForEeachVM)  2>null
			if ($null -eq $xmlConfigForEeachVM)
			{
				write-host -f White   "Error: Unable to parse the $($vm.vmName).xml, please check it exists or its format is right"
				continue
			} else
			{
				write-host -f White  "Info: parse the $($vm.vmName).xml successfully"
			}
						
			$global:SpecifiedVm = $xmlConfigForEeachVM.config.VMs.vm
			$SpecifiedVmLogDir = $xmlConfig.config.global.logfileRootDir + $($global:SpecifiedVm.vmName) +"_Logs-" + $(get-date -f yyyyMMdd-HHmmss)
			New-Item $SpecifiedVmLogDir  -type directory
			if( $? -ne "True")
			{
				write-host -f Red  "Error: $SpecifiedVmLogDir creates failed"
				return 1
			}
			else
			{
				write-host -f White  "Info: $SpecifiedVmLogDir creates successfully"
			}
			
			$logFile = $SpecifiedVmLogDir + "\" + $($vm.vmName) + ".log"
			
			LogMsg 3 " "
			LogMsg 3 "Start to run BIS Automation test."
			LogMsg 3 "Hyper-V server: $($global:SpecifiedVm.hvServer)"  "Green" 
			LogMsg 3 "VM Name: $($global:SpecifiedVm.vmName)"    "Green" 
			LogMsg 3 "VM IPv4: $($global:SpecifiedVm.ipv4)"  "Green" 
			LogMsg 3 " "
			LogMsg 3 "Now begin to run the test on VM  $($global:SpecifiedVm.vmName)."
		    LogMsg 3 "*************************************************************************************** "
		
			# create array of functions info objects
			$list = @(
				(gi function:ApplySnapshot),                #Apply snapshot
				(gi function:StartVMAndWait),               #Start VM and wait VM boot completely 
				(gi function:SetIPAddress),                 #Set IP address by querying VM IP
				(gi function:SyncBuildInstallKernel),       #Sync, build and install kernel
				(gi function:HypervPrepare),                #Hyper-V preparation
				(gi function:DeleteSnapshot),               #All above preparation done successfully, then need to delete the old snapshot
				(gi function:CreateSnapshot)                #Create a new snapshot
			)

			$AllFunsPass = "True"
			$FunCount = $($list.count) - 1   
			
			$FunIndex = 0..$FunCount
			foreach($_ in $FunIndex)
			{
				LogMsg 3 "Info: Now, begin to run $($list[$_]) function"  "Green"
				$sts = & $list[$_]  $global:SpecifiedVm
				if( $sts -ne 0 )
				{
					$AllFunsPass = "False"
					LogMsg 0 "Error: Run $($list[$_]) function failed"
					break
				}
			}
			
			#Now, start the test cases...
			if( $AllFunsPass -eq "True")
			{
				$xmlFile = $relativePathOfEachVM + $($global:SpecifiedVm.vmName) + ".xml"
				
				LogMsg 3 "Info :  Now, run lisa test based on config $xmlFile"  "Green"
				$sts = .\lisa.ps1 run  $xmlFile
				
				LogMsg 3 "The test on VM  $($global:SpecifiedVm.vmName) has been completed."  "Green"
				LogMsg 3 "*************************************************************************************** "
				LogMsg 3 " "
			} 
			else
			{
				LogMsg 3 "The test on VM  $($global:SpecifiedVm.vmName) failed."
				LogMsg 3 "*************************************************************************************** "
				LogMsg 3 " "
			}
			
		}
	}

}

#####################################################################
#
# RunTests
#
#####################################################################
function RunTests ([String] $xmlFilename )
{
    <#
    .Synopsis
        Start a test run.
    .Description
        Start a test run on the VMs listed in the .xml file.
    .Parameter xmlFilename
        Name of the .xml file for the test run.
    .Example
        RunTests ".\tools\FreeBSD\automation\BISAuto.xml"
    #>

	#
    # Make sure we have a .xml filename to work with
    #
    if (! $xmlFilename)
    {
        write-host -f Red "Error: xml filename missing"
        return $false
    }

    #
    # Make sure the .xml file exists, then load it
    #
    if (! (test-path $xmlFilename))
    {
        write-host -f Red "Error: XML config file '$xmlFilename' does not exist."
        return $false
    }

    $xmlConfig = [xml] (Get-Content -Path $xmlFilename)
    if ($null -eq $xmlConfig)
    {
        write-host -f Red "Error: Unable to parse the .xml file"
        return $false
    } else
	{
		write-host -f White "Success: parse the .xml file successfully"
	}

	RunICTests $xmlConfig
	
}
	
	
$retVal = 0

switch ($cmdVerb)
{
"run" {
        $sts = RunTests $cmdNoun
        if (! $sts)
        {
            $retVal = 1
        }
    }
"help" {
        Usage
        $retVal = 0
    }
default    {
        if ($cmdVerb.Length -eq 0)
        {
            Usage
            $retVal = 0
        }
        else
        {
            LogMsg 0 "Unknown command verb: $cmdVerb"
            Usage
        }
    }
}

exit $retVal

