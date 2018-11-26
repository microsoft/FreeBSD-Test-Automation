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
			
		LogMsg "Executing : bash $($currentTestData.testScript)"
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash $($currentTestData.testScript)" -runAsSudo
		
        $fileSize = $currentTestData.fileSize        
        $runTime = $currentTestData.runTimeSec
		
		if ($currentTestData.ioengine)
		{
			$ioengine = $currentTestData.ioengine
		}
		else
		{
			$ioengine = "posixaio"
		}
        
		#The /usr/fio directory is used for parsing the fio result
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mkdir /usr/fio" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cp summary.log /usr" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tar -xvzf report.tgz -C /usr" -runAsSudo
		
        #Actual Test Starts here..
		$totalLoopTimes = 0
		$totalFailTimes = 0
		$totalAbortTimes = 0
		$maxExecutionTime = 0
		$maxExecutionTimeCmd = ""
		$TestDate = (Get-Date -Format yyyy-MM-dd).trim()
        foreach ( $blockSize in $currentTestData.blockSizes.split(","))
        {
			foreach ( $iodepth in $currentTestData.iodepths.split(","))
			{
				foreach ( $testMode in $currentTestData.modes.split(","))
				{
					try 
					{
						$blockSizeInKB=$blocksize.split("k")[0].trim()
						$fileSizeInGB=$fileSize.split("g")[0].trim()
						
						if( [int]$iodepth -gt 8 )
						{
							$numThread = 8
						}
						else
						{
							$numThread = 1
						}
						
						$fioOutputFile = "$blockSizeInKB-$iodepth-${ioengine}-$fileSizeInGB-$numThread-$testMode-${runTime}-freebsd.fio.log"
						$fioCommonOptions="--size=${fileSize} --direct=1 --ioengine=${ioengine} --filename=${testFileName} --overwrite=1 --iodepth=$iodepth --runtime=${runTime}"
						$command="nohup fio ${fioCommonOptions} --readwrite=$testmode --bs=$blockSize --numjobs=$numThread --name=fiotest --output=$fioOutputFile"
						$runMaxAllowedTime = [int]$runTime * 20
						
						$start = [DateTime]::Now
						$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command $command -runAsSudo -runMaxAllowedTime  $runMaxAllowedTime
						WaitFor -seconds 10
						$isFioStarted  = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $fioOutputFile" ) -imatch "Starting")
						if ( $isFioStarted )
						{ 
							LogMsg "FIO Test Started successfully for mode : ${testMode}, blockSize : $blockSize, numThread : $numThread, FileSize : $fileSize and Runtime = $runTime seconds.."
						}
						else
						{
							Throw "Failed to start FIO tests."
						}
						$isFioFinished = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $fioOutputFile" ) -imatch "Run status group")
						while (!($isFioFinished))
						{
							LogMsg "FIO Test is still running. Please wait.."
							$isFioFinished = (( RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cat $fioOutputFile" ) -imatch "Run status group")
							WaitFor -seconds 20
						}
						
						$end = [DateTime]::Now
						$diff = ($end - $start).TotalSeconds
						if( [int]$diff -gt [int]$maxExecutionTime )
						{
							$maxExecutionTime = $diff
							$maxExecutionTimeCmd = $command
						}
						LogMsg "Execute fio command time in seconds: $diff"
						
						if( $isFioFinished )
						{
							RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "cp $fioOutputFile  /usr/fio" -runAsSudo				
							RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python /usr/report/fioTestEntry.py" -runAsSudo								
							RemoteCopy -downloadFrom $hs1VIP -port $hs1vm1sshport -username $user -password $password -files "result.log" -downloadTo $LogDir -download
							RemoteCopy -downloadFrom $hs1VIP -port $hs1vm1sshport -username $user -password $password -files "$fioOutputFile" -downloadTo $LogDir -download
							
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

								$TestCaseName = "azure_fio_perf"
								$TestMode = ""
								$RuntimeSec = 0
								$QDepth = 0
								$bandwidth_MBps = 0
								$BlockSize_KB = 0
								$FileSize_GB = $fileSize.split("g")[0].trim()
								$IOPS = 0
								$KernelVersion = ""
								$GuestDistro = ""
								$lat_usec = 0
								$GuestOS = "FreeBSD"
								$HostType = "MS Azure"
								$HostBy = $location
																
								$LogContents = Get-Content -Path "$LogDir\result.log"
								foreach ($line in $LogContents)
								{
								 
									if ( $line -imatch "bandwidth_MBps:" )
									{
										$bandwidth_MBps = [float]($line.Split(":")[1].trim())
									}
									
									if ( $line -imatch "TestMode:" )
									{
										$TestMode = $line.Split(":")[1].trim()
									}
									
									if ( $line -imatch "RuntimeSec:" )
									{
										$RuntimeSec = [int]($line.Split(":")[1].trim())
									}
									
									if ( $line -imatch "QDepth:" )
									{
										$QDepth = [int]($line.Split(":")[1].trim())
									}
									
									if ( $line -imatch "BlockSize_KB:" )
									{
										$BlockSize_KB = [int]($line.Split(":")[1].trim())
									}

									if ( $line -cmatch "IOPS:" )
									{
										$IOPS = [float]($line.Split(":")[1].trim())
									}

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
									
									if ( $line -imatch "lat_usec:" )
									{
										$lat_usec = [float]($line.Split(":")[1].trim())
									}										

								}
							
								$SQLQuery  = "INSERT INTO $dataTableName (TestCaseName,TestDate,HostType,HostBy,GuestDistro,InstanceSize,GuestOS,"
								$SQLQuery += "KernelVersion,DiskSetup,IOEngine,BlockSize_KB,FileSize_GB,QDepth,NumThread,TestMode,"
								$SQLQuery += "iops,bandwidth_MBps,lat_usec,RuntimeSec) VALUES "
								
								$SQLQuery += "('$TestCaseName','$TestDate','$HostType','$HostBy','$GuestDistro','$InstanceSize','$GuestOS',"
								$SQLQuery += "'$KernelVersion','$DiskSetup','$IOEngine','$BlockSize_KB','$FileSize_GB','$QDepth','$NumThread',"
								$SQLQuery += "'$TestMode','$iops','$bandwidth_MBps','$lat_usec','$RuntimeSec')"
		
								
								LogMsg "SQLQuery:"
								LogMsg $SQLQuery
								
								LogMsg  "ItemName                      Value"
								LogMsg  "TestMode                      $TestMode"
								LogMsg  "RuntimeSec                    $RuntimeSec"
								LogMsg  "bandwidth_MBps                $bandwidth_MBps"
								LogMsg  "QDepth                        $QDepth"
								LogMsg  "BlockSize_KB                  $BlockSize_KB"
								LogMsg  "FileSize_GB                   $FileSize_GB"
								LogMsg  "IOPS                          $IOPS"
								LogMsg  "NumThread                     $NumThread"
								LogMsg  "KernelVersion                 $KernelVersion"
								LogMsg  "InstanceSize                  $InstanceSize"
								LogMsg  "lat_usec                      $lat_usec"
								LogMsg  "IOEngine                      $IOEngine"
								LogMsg  "HostBy                        $HostBy"
								LogMsg  "GuestDistro                   $GuestDistro"

								$uploadResults = $true
								#Check the results validation ? TODO
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
									
									LogMsg "Great! FIO test is finished now."

									$testResult = "PASS"
								}
								else 
								{
									LogErr "Uploading the test results cancelled due to wrong database configuration."
									$testResult = "FAIL"
								}								
								
							}
							else
							{
								LogErr "Uploading the test results cancelled due to zero throughput for some connections!!"
								$testResult = "FAIL"
							}							
							
						}
						else
						{
							$testResult = "FAIL"
						}
						
						#Delete the previous result
						$out = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "rm -rf /usr/fio/*.log" -runAsSudo
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
		LogMsg "The command of max execution time: $maxExecutionTimeCmd"

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

#Return the result to the test suite script..
return $result
