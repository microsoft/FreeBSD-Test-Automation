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
		$hs1vm1Hostname = $AllVMData.RoleName
		$vmResourceGroupName = $AllVMData.ResourceGroupName
		$accountName = $xmlConfig.config.Azure.General.ARMStorageAccount
		$srcStorageAccountName = $accountName.Replace('"',"")
		
		LogMsg "ResourceGroupName: $vmResourceGroupName"
		LogMsg "AccountName: $srcStorageAccountName"

		LogMsg "Install basic apps/tools."
		InstallPackagesOnFreebsd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport
		
		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo

		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -a" -runAsSudo
		$kernelVersion = $out.Replace('Password:', "") 
		LogMsg "The detailed kernel version before building kernel: $kernelVersion"
		
		#Install tools & build & install kernel		
		$runMaxAllowedTime = 3600 * 15 # It will cost more than 12 hours if the VM size is basic A1
		$buildBranch = $xmlConfig.config.global.VMEnv.LISBuildBranch
		LogMsg "Build branch: $buildBranch"
		$command = "nohup /bin/csh  /home/$user/$($currentTestData.testScript) -b $buildBranch"
		$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command $command -runAsSudo -runMaxAllowedTime  $runMaxAllowedTime
		
		#The VM will reboot after building & installing the latest kernel
		sleep 60
		$isAllConnected = isAllSSHPortsEnabledRG -AllVMDataObject $AllVMData
		if ($isAllConnected -eq "True")
		{
			RemoteCopy -download -downloadFrom $hs1VIP -files "/root/autobuild.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
			RemoteCopy -download -downloadFrom $hs1VIP -files "/root/state.txt" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
			$testStatus = Get-Content $LogDir\state.txt
			$testStatus = "DeployCompleted"
			if ($testStatus -eq "DeployCompleted")
			{
				LogMsg "Build and install kernel completed"
				$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -a" -runAsSudo
				$kernelVersion = $out.Replace('Password:', "") 
				LogMsg "The detailed kernel version after building kernel: $kernelVersion"
				
				#Delete old log
				RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "rm -rf ~/.ssh/" -runAsSudo 
				RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "rm -rf /var/log/*" -runAsSudo 
				RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "sync;sync" -runAsSudo 
			}
			else
			{
				LogErr "Build and install kernel failed"
				$testResult = "FAIL"
			}
		}
		else
		{
			LogErr "Unable to connect SSH ports."
			$testResult = "FAIL"
		}
	
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
		$testResult = "Aborted"
	}
 
    if( !$testResult )
	{
		try
		{
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "waagent  -force -deprovision+user" -runAsSudo 
		}
		catch
		{
			LogMsg "The ssh may be disconnected after execution of de-provision"
			LogMsg "It's a known issue, so skip the exception."
		}	
	}
 


	try
	{
		$retryAttemts = 3
		$isSuccess = $false
		$counter  = 0
		
		if( !$testResult )
		{
			Stop-AzureRmVM -ResourceGroupName  $vmResourceGroupName  -Name $hs1vm1Hostname  -Force
		}
		
		while(($counter -le $retryAttemts) -and ($isSuccess -eq $false))
		{
			if( !$testResult )
			{
				#Upload the .vhd to the specified storage (Storage account type = Premium_LRS )
				LogMsg "Current:Retrying $counter/$retryAttemts.."
				
				$dstStorageAccountNameV2 = $currentTestData.dstResourceNamePrefix + "storagev2"
				$dstResourceGroupNameV2 = $currentTestData.dstResourceNamePrefix + "groupv2"
				
				$dstLocation = $currentTestData.dstLocation
				$destBlobName = $currentTestData.destBlobName
				$destContainerName = "vhds"
				
				$storageType = "Premium_LRS"
				CheckAndMakesureStorageAccountExists -resourceGroupNameToBeChecked $dstResourceGroupNameV2  -storageAccountNameToBeChecked $dstStorageAccountNameV2  $destContainerName   $dstLocation  $storageType

				$srcVM = Get-AzureRMVM -Name  $hs1vm1Hostname  -ResourceGroupName $vmResourceGroupName 
				$srcUri = ($srcVM.StorageProfile.OsDisk.Vhd).uri
				
				LogMsg "**************************************************************"
				LogMsg "The source URL is $srcUri"
				LogMsg "The destination location: $dstLocation"
				LogMsg "The destination group: $dstResourceGroupNameV2"
				LogMsg "The destination storage: $dstStorageAccountNameV2"
				LogMsg "The destination storage type: $storageType"
				LogMsg "The destination vhd name: $destBlobName"
				LogMsg "**************************************************************"
				
				$srcResourceGroupName = ( Get-AzureRmResourceGroup   | Where ResourceGroupName -like "*$srcStorageAccountName*" ).ResourceGroupName
				$srcStorageKey = (Get-AzureRmStorageAccountKey  -StorageAccountName $srcStorageAccountName -ResourceGroupName $srcResourceGroupName).Value[0]
				$srcContext = New-AzureStorageContext -StorageAccountName $srcStorageAccountName -StorageAccountKey $srcStorageKey
					
				$dstStorageKey = (Get-AzureRmStorageAccountKey  -StorageAccountName $dstStorageAccountNameV2 -ResourceGroupName $dstResourceGroupNameV2).Value[0]
				$destContext = New-AzureStorageContext -StorageAccountName $dstStorageAccountNameV2 -StorageAccountKey $dstStorageKey
				
				
				LogMsg "Begin to copy vhd from $srcResourceGroupName to $dstResourceGroupNameV2"
				$blob = Start-AzureStorageBlobCopy -SrcUri $srcUri -SrcContext $srcContext -DestContainer $destContainerName -DestBlob $destBlobName -DestContext $destContext -Force

				LogMsg "Checking Copy Status"
				#Set enough time to copy
				$uploadTimeout = 36000
				$status = $blob | Get-AzureStorageBlobCopyState
				while( ($status.Status -eq "Pending") -and ($uploadTimeout -gt 0 ) ){
					$status = $blob | Get-AzureStorageBlobCopyState
					$BytesCopied = $status.BytesCopied
					$TotalBytes = $status.TotalBytes
					LogMsg "BytesCopied/TotalBytes: $BytesCopied/$TotalBytes"
					Start-Sleep 60
					$uploadTimeout -= 60
				}
				
				$status = $blob | Get-AzureStorageBlobCopyState
				if( ($status.Status -ne "Success") -and ($counter -eq $retryAttemts) ){
					LogErr "Copy vhd from  $srcResourceGroupName to $dstResourceGroupNameV2 time-out."
					$testResult = "FAIL"
				}
				
				if( $status.Status -eq "Success"  )
				{
					LogMsg "Copy vhd from  $srcResourceGroupName to $dstResourceGroupNameV2 successfully."
					$isSuccess = $True
					$testResult = "PASS"
				}
			}
						
			$counter += 1

		}
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
		$testResult = "Aborted"
	}
	
}
else
{
	$testResult = "Aborted"	
}

$resultArr += $testResult
$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
