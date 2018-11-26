<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if ($isDeployed)
{
	try
	{
		$hs1VIP = $AllVMData.PublicIP
		$hs1vm1sshport = $AllVMData.SSHPort
		$hs1ServiceUrl = $AllVMData.URL
		$hs1vm1Dip = $AllVMData.InternalIP
        
        $vmName = $AllVMData.RoleName
        $rgNameOfVM = $AllVMData.ResourceGroupName
        $storageAccountName =  $xmlConfig.config.Azure.General.ARMStorageAccount
        
        $rgNameOfBlob = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq $storageAccountName} | Select-Object -ExpandProperty ResourceGroupName
        $storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $rgNameOfBlob -Name $storageAccountName 

        #Pulls the VM info for later 
        $vmdiskadd=Get-AzurermVM -ResourceGroupName $rgNameOfVM -Name $vmName 

        #Sets the URL string for where to store your vhd files
        #Also adds the VM name to the beginning of the file name 
        $DataDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName 

		$diskNumsBeforAddVHD = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "camcontrol devlist | wc -l" -runAsSudo
		sleep 1
		# $diskNumsBeforAddVHD = $diskNumsBeforAddVHD -replace '\D+(\d+)\D+','$1'
		$diskNumsBeforAddVHD = $diskNumsBeforAddVHD -replace "[^0-9]" , ''
		LogMsg "There are $diskNumsBeforAddVHD disks before adding new disks"
		
        #Max data disks are 16 for A4
		$maxDisks = 16
		if( $currentTestData.TestType -eq "random" )
		{
			LogMsg "Add SCSI disks with random LUNs"
			$length = [int]$maxDisks
			$testLUNs = @()
			for( $i = 0; $i -lt $length; $i++ )
			{
				do 
				{
					$random = Get-Random
					$lun = $random % $length
				} while ( $lun -in $testLUNs )
				$testLUNs += $lun
			}
		}
		elseif( $currentTestData.TestType -eq "randomBeginWithLun1" )
		{
			LogMsg "Add SCSI disks with random LUNs except LUN 0"
			$length = [int]$maxDisks
			$testLUNs = @()
			$testLUNs += 0
			for( $i = 0; $i -lt $length-1; $i++ )
			{
				do 
				{
					$random = Get-Random
					$lun = $random % $length
				} while ( $lun -in $testLUNs )
				$testLUNs += $lun
			}
		}
		else
		{
			LogMsg "Add SCSI disks with sequential LUNs"
			$lenth = [int]$maxDisks - 1
			$testLUNs= 0..$lenth
			$length = $testLUNs.Length
		}

        foreach ($newLUN in $testLUNs)
        {
            $diskSize = (($newLUN + 1)*10)
            LogMsg "Adding disk ---- LUN: $newLUN   DiskSize: $diskSize"
            Add-AzureRmVMDataDisk -CreateOption empty -DiskSizeInGB $diskSize -Name $vmName-$newLUN -VhdUri $DataDiskUri-Data$newLUN.vhd -VM $vmdiskadd -Caching ReadWrite -lun $newLUN 
			sleep 1
        }
        
        #Updates the VM with the disk config - does not require a reboot 
        Update-AzureRmVM -ResourceGroupName $rgNameOfVM -VM $vmdiskadd
		LogMsg "Wait 60 seconds to update azure vm after adding new disks."
        sleep 60
        $diskNumsBeforRemoveVHD = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "camcontrol devlist | wc -l" -runAsSudo
		sleep 1
		$diskNumsBeforRemoveVHD = $diskNumsBeforRemoveVHD -replace "[^0-9]" , ''
		LogMsg "There are $diskNumsBeforRemoveVHD disks after adding new disks"
		
		$statusOfAddDisksBeforeRestartVM = "PASS"
		$diff = [int]($diskNumsBeforRemoveVHD - [int]$diskNumsBeforAddVHD )
		if( $diff -ne [int]$maxDisks )
		{
			$statusOfAddDisksBeforeRestartVM = "FAIL"
			$testResult = "FAIL"
			$total = [int]$diskNumsBeforAddVHD + [int]$maxDisks
			LogMsg "Add new disk failed. It should be $total, but it's $diskNumsBeforRemoveVHD."
		}
		
		$isRestarted = $false
        if( $statusOfAddDisksBeforeRestartVM -eq "PASS")
		{			
			LogMsg "Trying to restart $($AllVMData.RoleName)..."
			if ( $UseAzureResourceManager )
			{
				# The status of restarting VM is related with PowerShell version
				$restartVM = Restart-AzureRmVM -ResourceGroupName $AllVMData.ResourceGroupName -Name $AllVMData.RoleName -Verbose
				if ( $restartVM.Status -eq "Succeeded"  -or  $restartVM.StatusCode -eq "OK" -or (-not $restartVM.Status) -or (-not $restartVM.StatusCode) )
				{
					$isSSHOpened = isAllSSHPortsEnabledRG -AllVMDataObject $AllVMData
					if ( $isSSHOpened -eq "True" )
					{
						$isRestarted = $true
					}
					else
					{
						LogErr "VM is not available after restart"
					}
				}
				else
				{
					LogErr "Restart Failed. Operation ID : $($restartVM.OperationId)"
				}
			}
			else
			{
				$out = RestartAllDeployments -DeployedServices $isDeployed
				$isRestarted = $?
			}
			
			if ($isRestarted)
			{
				LogMsg "Virtual machine restart successful."			
			}
			else
			{
				LogErr "Virtual machine restart failed."
				$testResult = "FAIL"
				
			}
		}
		
		
		if($isRestarted)
		{
			$diskNumsAfterRestarVM = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "camcontrol devlist | wc -l" -runAsSudo
			sleep 1
			$diskNumsAfterRestarVM = $diskNumsAfterRestarVM -replace "[^0-9]" , ''
			LogMsg "There are $diskNumsAfterRestarVM disks after restarting the VM"
			if( $diskNumsAfterRestarVM -ne $diskNumsBeforRemoveVHD )
			{
				$testResultOfAddDisks = "FAIL"
				$testResult = "FAIL"
				LogMsg "Add new disk failed. It should be $diskNumsBeforRemoveVHD, but it's $diskNumsAfterRestarVM after restarting the VM."
			}
			else
			{
				$testResultOfAddDisks = "PASS"
			}
		}
		else
		{
			$testResultOfAddDisks = "FAIL"
			$testResult = "FAIL"
		}
		
		
		
		if( $testResultOfAddDisks -eq "PASS" )
		{
		    if( $currentTestData.writeDisk -eq "yes" )
			{		
				RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
				RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
				LogMsg "Executing : bash $($currentTestData.testScript) $length"
				RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash $($currentTestData.testScript) $length" -runAsSudo

				RemoteCopy -download -downloadFrom $hs1VIP -files "/root/state.txt, /root/summary.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
				$testStatus = Get-Content $LogDir\state.txt
				if ($testStatus -eq "TestCompleted")
				{
					LogMsg "Write disks successfully"
					$testResultOfAddDisks = "PASS"
				}
				else
				{
					LogMsg "Write disks failed"
					$testResultOfAddDisks = "FAIL"
					$testResult = "FAIL"
				}			
			}
		}
			
		
				
		if( $testResultOfAddDisks -eq "PASS" )
		{
			#To delete the VHDs 
			$testResultOfRemoveDisks = "PASS"
			foreach ($newLUN in $testLUNs)
			{
				Remove-AzureRmVMDataDisk -VM $vmdiskadd -Name  $vmName-$newLUN
				sleep 10
				Update-AzureRmVM -ResourceGroupName $rgNameOfVM  -VM $vmdiskadd
				
				$currentDiskNums = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "camcontrol devlist | wc -l" -runAsSudo
				$currentDiskNums = $currentDiskNums -replace "[^0-9]" , ''
				$diffNum =  [int]$diskNumsBeforRemoveVHD - [int]$currentDiskNums
				if( $diffNum -ne 1 )
				{
					$testResultOfRemoveDisks = "FAIL"
					LogMsg "Remove the VHDs failed @LUN is $newLUN"
					LogMsg "diskNumsBeforRemoveVHD: $diskNumsBeforRemoveVHD   "
					LogMsg "currentDiskNums: $currentDiskNums   "
				}
				$diskNumsBeforRemoveVHD = [int]$diskNumsBeforRemoveVHD - 1

			}

			$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "camcontrol devlist | wc -l" -runAsSudo
			$out = $out -replace "[^0-9]" , ''
			if( $out -eq $diskNumsBeforAddVHD  -and  $testResultOfRemoveDisks -eq "PASS" )
			{
				$testResult = "PASS"
			}
			else
			{
				LogMsg "Delete the VHDs failed"
				$testResult = "FAIL"
			} 		
		}       		
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = ""
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
#$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
	}   
}

else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
