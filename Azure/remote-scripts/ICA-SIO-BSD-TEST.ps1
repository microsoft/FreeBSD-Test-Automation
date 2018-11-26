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
		
		#The disks are stored in the below storage account.
		$Date = Get-Date -format "yyyyMMddhhmmss"
		$storageAccountName = $Date + (Get-Random -InputObject (1..1000))
		$storageType = "Premium_LRS"
		$location = $xmlConfig.config.Azure.General.Location
		$location = $location.Replace('"',"")
		$vmInfo = Get-AzureRMVM –Name $vmName  –ResourceGroupName $rgNameOfVM
		$InstanceSize = $vmInfo.HardwareProfile.VmSize
		
		New-AzureRmStorageAccount -ResourceGroupName $rgNameOfVM -AccountName $storageAccountName -Location $location  -SkuName $storageType

		#Create a container
		$containerName = "vhds"
		$srcStorageKey = (Get-AzureRmStorageAccountKey  -StorageAccountName $storageAccountName -ResourceGroupName $rgNameOfVM).Value[0]
		$ctx = New-AzureStorageContext -StorageAccountName $storageAccountName  -StorageAccountKey  $srcStorageKey
		New-AzureStorageContainer -Name $containerName  -Context $ctx
		
		$rgNameOfBlob = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq $storageAccountName} | Select-Object -ExpandProperty ResourceGroupName
        $storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $rgNameOfBlob -Name $storageAccountName 

        #Pulls the VM info for later 
        $vmdiskadd=Get-AzurermVM -ResourceGroupName $rgNameOfVM -Name $vmName 

        #Sets the URL string for where to store your vhd files
        #Also adds the VM name to the beginning of the file name 
        $DataDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString() + $containerName + "/" + "DataDisk" 

		
		if ( $currentTestData.DiskSetup -eq "Single" )
		{
			$DiskSetup = "1 x 513G"
			$testFileName = "/dev/da2"
			$diskNums = 1
		}
		else
		{
			$DiskSetup = "12 x 513G RAID0"
			$testFileName = "/dev/stripe/st0"
			$diskNums = 12
		}
		
		LogMsg "The disk setup is: $DiskSetup"
		
		$diskSize = 513
		LogMsg "Add $diskNums disk(s) with $diskSize GB size."
		$lenth = [int]$diskNums - 1
		$testLUNs= 0..$lenth
		foreach ($newLUN in $testLUNs)
        {
            Add-AzureRmVMDataDisk -CreateOption empty -DiskSizeInGB $diskSize -Name $vmName-$newLUN -VhdUri $DataDiskUri-NO$newLUN.vhd -VM $vmdiskadd -Caching None -lun $newLUN 
			sleep 3
        }
 
 
        Update-AzureRmVM -ResourceGroupName $rgNameOfVM -VM $vmdiskadd
		LogMsg "Wait 60 seconds to update azure vm after adding new disks."
        sleep 60

		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
		
		$NumberOfDisksAttached = 1
		LogMsg "Executing : bash $($currentTestData.testScript) $NumberOfDisksAttached"
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash $($currentTestData.testScript) $NumberOfDisksAttached" -runAsSudo
		
		LogMsg "Executing : Install sio"
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tar -xvzf sio.tgz -C /root" -runAsSudo
		
		$testFileSize = $currentTestData.fileSize
		$sioRunTime = $currentTestData.runTimeSec
		
		#The /usr/sio directory is used for parsing the sio result
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mkdir /usr/sio" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cp summary.log /usr" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tar -xvzf report.tgz -C /usr" -runAsSudo
		
		#Actual Test Starts here..
		$totalLoopTimes = 0
		$totalFailTimes = 0
		$totalAbortTimes = 0
		$maxExecutionTime = 0
		$TestDate = (Get-Date -Format yyyy-MM-dd).trim()
        foreach ( $blockSize in $currentTestData.blockSizes.split(","))
        {
            foreach ( $numThread in $currentTestData.numThreads.split(","))
            {
				foreach ( $mode in $currentTestData.modes.split(","))
				{
					try 
					{
						$testMode = GetSIOMode $mode   
						if ($testMode -eq "-1 -1")
						{
						  Throw "The mode doesn't support. Check the mode and try again"
						}
						
						$blockSizeInKB=$blocksize.split("k")[0].trim()
						$fileSizeInGB=$testFileSize.split("g")[0].trim()
						
						$sioOutputFile = "${blockSizeInKB}-$fileSizeInGB-${numThread}-${mode}-${sioRunTime}-freebsd.sio.log"
						$command = "nohup /root/sio/sio_ntap_freebsd $testMode $blockSize $testFileSize $sioRunTime $numThread $testFileName -direct > $sioOutputFile "
						$runMaxAllowedTime = [int]$sioRunTime * 10
						
						$start = [DateTime]::Now
						$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command $command -runAsSudo -runMaxAllowedTime  $runMaxAllowedTime
						WaitFor -seconds 10
						$isSioStarted  = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $sioOutputFile" ) -imatch "Version")
						if ( $isSioStarted )
						{ 
							LogMsg "SIO Test Started successfully for mode : ${mode}, blockSize : $blockSize, numThread : $numThread, FileSize : $testFileSize and Runtime = $sioRunTime seconds.."
						}
						else
						{
							Throw "Failed to start sio tests."
						}
						$isSioFinished = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $sioOutputFile" ) -imatch "Threads")
						while (!($isSioFinished))
						{
							LogMsg "Sio Test is still running. Please wait.."
							$isSioFinished = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $sioOutputFile" ) -imatch "Threads")
							WaitFor -seconds 20
						}
						
						$end = [DateTime]::Now
						$diff = ($end - $start).TotalSeconds
						if( [int]$diff -gt [int]$maxExecutionTime )
						{
							$maxExecutionTime = $diff
						}
						LogMsg "Execute sio command time in seconds: $diff"
						
						if( $isSioFinished )
						{
							LogMsg "Great! SIO test is finished now."						
							RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cp $sioOutputFile  /usr/sio" -runAsSudo						
							RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python /usr/report/sioTestEntry.py" -runAsSudo							
							RemoteCopy -downloadFrom $hs1VIP -port $hs1vm1sshport -username $user -password $password -files "result.log" -downloadTo $LogDir -download
							RemoteCopy -downloadFrom $hs1VIP -port $hs1vm1sshport -username $user -password $password -files "$sioOutputFile" -downloadTo $LogDir -download
							
							LogMsg "Uploading the test results.."
							if( $xmlConfig.config.Azure.database.server )
							{
								$dataSource = $xmlConfig.config.Azure.database.server
								$databaseUser = $xmlConfig.config.Azure.database.user
								$databasePassword = $xmlConfig.config.Azure.database.password
								$database = $xmlConfig.config.Azure.database.dbname
								$dataTableName = $xmlConfig.config.Azure.database.dbtable
							}
							else
							{
								$dataSource = $env:databaseServer
								$databaseUser = $env:databaseUser
								$databasePassword = $env:databasePassword
								$database = $env:databaseDbname
								$dataTableName = $env:databaseDbtable
							}
							
							if( $dataTableName -eq $null )
							{
								$dataTableName = $currentTestData.dataTableName
							}
							
							if ($dataSource -And $databaseUser -And $databasePassword -And $database -And $dataTableName) 
							{
								$connectionString = "Server=$dataSource;uid=$databaseUser; pwd=$databasePassword;Database=$database;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
								$KernelVersion = ""
								$GuestDistro = ""
								$bandwidth_KBps = 0
								$BlockSize_KB = 0
								$IOs = 0
								$HostType = "MS Azure"
								$FileSize_GB = $testFileSize.split("g")[0].trim()
								$IOPS = 0
								$TestMode = ""
								$GuestOS = "FreeBSD"
								$NumThread = 0
								$RuntimeSec = 0
								$TestCaseName = "azure_sio_perf"
								$HostBy = $location
								
								$LogContents = Get-Content -Path "$LogDir\result.log"
								foreach ($line in $LogContents)
								{
									if ( $line -imatch "KernelVersion:" )
									{
										$KernelVersion = $line.Split(":")[1].trim()
										if( $KernelVersion.Length -gt 60 )
										{
										    $KernelVersion = $KernelVersion.Substring(0,59)
										}										
									}
									
									if ( $line -imatch "GuestDistro:" )
									{
										$GuestDistro = $line.Split(":")[1].trim()
									}
							
									
									if ( $line -imatch "bandwidth_KBps:" )
									{
										$bandwidth_KBps = [int]($line.Split(":")[1].trim())
									}	
									
									if ( $line -imatch "BlockSize_KB:" )
									{
										$BlockSize_KB = [int]($line.Split(":")[1].trim())
									}
									
									if ( $line -imatch "IOs:" )
									{
										$IOs = [int]($line.Split(":")[1].trim())
									}
									
									# if ( $line -imatch "FileSize_GB:" )
									# {
										# $FileSize_GB = [int]($line.Split(":")[1].trim())
									# }
									
									if ( $line -cmatch "IOPS:" )
									{
										"This line is: $line"
										$IOPS = [float]($line.Split(":")[1].trim())
									}
									
									if ( $line -imatch "TestMode:" )
									{
										$TestMode = $line.Split(":")[1].trim()
									}
									
									if ( $line -imatch "NumThread:" )
									{
										$NumThread = [int]($line.Split(":")[1].trim())
									}
									
									if ( $line -imatch "RuntimeSec:" )
									{
										$RuntimeSec = [int]($line.Split(":")[1].trim())
									}
								}

								
								$SQLQuery  = "INSERT INTO $dataTableName (TestCaseName,TestDate,HostType,HostBy,GuestDistro,InstanceSize,GuestOS,"
								$SQLQuery += "KernelVersion,DiskSetup,BlockSize_KB,FileSize_GB,NumThread,TestMode,"
								$SQLQuery += "iops,bandwidth_KBps,RuntimeSec,IOs) VALUES "
									
								$SQLQuery += "('$TestCaseName','$TestDate','$HostType','$HostBy','$GuestDistro','$InstanceSize','$GuestOS',"
								$SQLQuery += "'$KernelVersion','$DiskSetup','$BlockSize_KB','$FileSize_GB','$NumThread',"
								$SQLQuery += "'$TestMode','$iops','$bandwidth_KBps','$RuntimeSec','$IOs')"
			
								LogMsg "SQLQuery:"
								LogMsg  $SQLQuery
								LogMsg  "ItemName                      Value"
								LogMsg  "TestMode                      $TestMode"
								LogMsg  "RuntimeSec                    $RuntimeSec"
								LogMsg  "bandwidth_KBps                $bandwidth_KBps"
								LogMsg  "BlockSize_KB                  $BlockSize_KB"
								LogMsg  "FileSize_GB                   $FileSize_GB"
								LogMsg  "IOPS                          $IOPS"
								LogMsg  "NumThread                     $NumThread"
								LogMsg  "KernelVersion                 $KernelVersion"
								LogMsg  "InstanceSize                  $InstanceSize"
								LogMsg  "DiskSetup                     $DiskSetup"
								LogMsg  "TestDate                      $TestDate"
								LogMsg  "HostBy                        $HostBy"
								LogMsg  "GuestDistro                   $GuestDistro"
								
								$uploadResults = $true
								#Check the result valid before uploading. TODO 
								
								if ($uploadResults)
								{
									$connection = New-Object System.Data.SqlClient.SqlConnection
									$connection.ConnectionString = $connectionString
									$connection.Open()

									$command = $connection.CreateCommand()
									$command.CommandText = $SQLQuery
									$result = $command.executenonquery()
									$connection.Close()
									LogMsg "Uploading the test results done!!"
									
									
									
									$testResult = "PASS"
								}
								else 
								{
									LogErr "Uploading the test results cancelled due to zero/invalid output for some results!"
									$testResult = "FAIL"
								}								
								
							}
							else
							{
								LogErr "Uploading the test results cancelled due to wrong database configuration"
								$testResult = "FAIL"
							}								
						}
						else
						{
							$testResult = "FAIL"
						}
						
						#Delete the previous result
						$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "rm -rf /usr/sio/*.log" -runAsSudo
						$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "rm -f result.log" -runAsSudo
						
						
					}
					catch
					{
						$ErrorMessage =  $_.Exception.Message
						LogMsg "EXCEPTION : $ErrorMessage"   
						$testResult = "Aborted"
					}
					finally
					{
						if (!$testResult)
						{
							$testResult = "Aborted"
						}
						$resultArr += $testResult
						# $resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
						if( $testResult -eq "FAIL" )
						{
							$totalFailTimes += 1
						}
						
						if( $testResult -eq "Aborted" )
						{
							$totalAbortTimes += 1
						}
						
						$totalLoopTimes += 1
					}				
				}
            }
        }
		
		LogMsg "The total loop times: $totalLoopTimes"
		LogMsg "The failed times: $totalFailTimes"
		LogMsg "The aborted times: $totalAbortTimes"
		LogMsg "The max execution time in seconds: $maxExecutionTime"
		
		
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
