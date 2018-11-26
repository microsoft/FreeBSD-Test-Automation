Import-Module .\TestLibs\RDFELibs.psm1 -Force

$testResult = ""
$result = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig

if($isDeployed)
{
	
	$ClientIp = $allVMData[0].PublicIP
	$ClientSshport = $allVMData[0].SSHPort
	$vmName =$allVMData[0].RoleName
    $rgNameOfVM = $allVMData[0].ResourceGroupName
	
	$ServerIp = $allVMData[1].PublicIP
	$ServerSshport = $allVMData[1].SSHPort
	$ServerInterIp = $allVMData[1].InternalIP
	
	LogMsg "Install netperf on both of server and client VMs"
	$tmp = RunLinuxCmd -username $user -password $password -ip $ClientIp -port $ClientSshport -command "pkg install -y netperf" -runAsSudo
	$tmp = RunLinuxCmd -username $user -password $password -ip $ServerIp -port $ServerSshport -command "pkg install -y netperf" -runAsSudo

	$cmd1="$python_cmd start_netperf_server.py"
	$cmd2="$python_cmd start_netperf_client.py -H $ServerInterIp -t TCP_RR -l 120"

	$server = CreateIperfNode -nodeIp $ServerIp -nodeSshPort $ServerSshport  -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir
	$client = CreateIperfNode -nodeIp $ClientIp -nodeSshPort $ClientSshport  -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir 

	$vmInfo = Get-AzureRMVM –Name $vmName  –ResourceGroupName $rgNameOfVM
	$InstanceSize = $vmInfo.HardwareProfile.VmSize
	
	$resultArr = @()
	$testNames= $currentTestData.testNames.Split(",")
	$connections= $currentTestData.connections.Split(",")
	$requestNums= $currentTestData.requestNums.Split(",")
	$runTimeSec= $currentTestData.runTimeSec	
	$TestDate = (Get-Date -Format yyyy-MM-dd).trim()

	if ( $EnableAcceleratedNetworking )
	{
		$dataPath = "SRIOV"
	}
	else
	{
		$dataPath = "Synthetic"
	}	

	foreach ($testName in $testNames)
	{
		try
		{
			$testResult = $null
			foreach ( $connectionNum in $connections)
			{
				foreach ( $requestNum in $requestNums)
				{
					$server.cmd = "$python_cmd start_netperf_server.py"			
					
					LogMsg "Test Started for testName $testName with connection $connectionNum and requestNum $requestNum"
					$client.cmd = "$python_cmd start_netperf_client.py -H $ServerInterIp -t $testName -l $runTimeSec -c $connectionNum -b $requestNum"
					mkdir $LogDir\$testName -ErrorAction SilentlyContinue | out-null
					$server.logDir = $LogDir + "\$testName"
					$client.logDir = $LogDir + "\$testName"
					$testResult = NetperfLatencyTest $server $client

					if( $testResult -eq "PASS" )
					{
						#Rename the client log
						$newFileName = "netperf-$testName-$connectionNum-$requestNum.log"
						Rename-Item "$($client.LogDir)\netperf-client.txt"   "$newFileName"
					
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
						
							$ConnectionString = "Server=$dataSource;uid=$databaseUser; pwd=$databasePassword;Database=$database;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
							$TestCaseName = "azure_network_latency"
							$HostType = "MS Azure"
							$GuestOS = "FreeBSD"
							$KernelVersion = ""
							$GuestDistro = ""
							$P50_LATENCY = @()
							$P90_LATENCY = @()
							$P99_LATENCY = @()
							$MIN_LATENCY = @()
							$MAX_LATENCY = @()
							$MEAN_LATENCY = @()
							$Latency50Percentile_ms = 0
							$Latency90Percentile_ms = 0
							$Latency99Percentile_ms = 0
							$MinLatency_ms = 0
							$MaxLatency_ms = 0
							$MeanLatency_ms = 0
							$Protocol = ""
							$HostBy = $xmlConfig.config.Azure.General.Location
							$HostBy = $HostBy.Replace('"',"")
							
							$LogContents = Get-Content -Path "$($client.LogDir)\$newFileName"
							foreach ($line in $LogContents)
							{
								if ( $line -imatch "Guest Distro:" )
								{
									$GuestDistro = $line.Split(":")[1].trim()
								}
								
								if ( $line -imatch "Kernel Version:" )
								{
									$KernelVersion = $line.Split(":")[1].trim()
								}								
								if ( $line -imatch "PROTOCOL=" )
								{
									$Protocol = ($line.Split("=")[1].trim())
								}
								if ( $line -imatch "P50_LATENCY=" )
								{
									$P50_LATENCY += [float]($line.Split("=")[1].trim())
								}
								if ( $line -imatch "P90_LATENCY=" )
								{
									$P90_LATENCY += [float]($line.Split("=")[1].trim())
								}
								if ( $line -imatch "P99_LATENCY=" )
								{
									$P99_LATENCY += [float]($line.Split("=")[1].trim())
								}
								if ( $line -imatch "MIN_LATENCY=" )
								{
									$MIN_LATENCY += [float]($line.Split("=")[1].trim())
								}
								if ( $line -imatch "MAX_LATENCY=" )
								{
									$MAX_LATENCY += [float]($line.Split("=")[1].trim())
								}
								if ( $line -imatch "MEAN_LATENCY=" )
								{
									$MEAN_LATENCY += [float]($line.Split("=")[1].trim())
								}								
							}
							$Latency50Percentile_ms = ($P50_LATENCY | Measure-Object -Average).Average
							$Latency90Percentile_ms = ($P90_LATENCY | Measure-Object -Average).Average
							$Latency99Percentile_ms = ($P99_LATENCY | Measure-Object -Average).Average
							$MinLatency_ms = ($MIN_LATENCY | Measure-Object -Average).Average
							$MaxLatency_ms = ($MAX_LATENCY | Measure-Object -Average).Average
							$MeanLatency_ms = ($MEAN_LATENCY | Measure-Object -Average).Average
							
							$SQLQuery  = "INSERT INTO $dataTableName (TestCaseName,dataPath,TestDate,HostType,HostBy,GuestDistro,InstanceSize,GuestOS,"
							$SQLQuery += "KernelVersion,Protocol,Connection,RequestPerConnection,Latency50Percentile_ms,Latency90Percentile_ms,Latency99Percentile_ms,"
							$SQLQuery += "MinLatency_ms,MaxLatency_ms,MeanLatency_ms) VALUES "
							
							$SQLQuery += "('$TestCaseName','$dataPath','$TestDate','$HostType','$HostBy','$GuestDistro','$InstanceSize','$GuestOS',"
							$SQLQuery += "'$KernelVersion','$Protocol','$connectionNum','$requestNum','$Latency50Percentile_ms','$Latency90Percentile_ms','$Latency99Percentile_ms',"
							$SQLQuery += "'$MinLatency_ms','$MaxLatency_ms',$MeanLatency_ms)"

							LogMsg  "SQLQuery:"
							LogMsg  $SQLQuery						
							$uploadResults = $true
							#Check the results validation ? TODO
							if ($uploadResults)
							{
								$Connection = New-Object System.Data.SqlClient.SqlConnection
								$Connection.ConnectionString = $ConnectionString
								$Connection.Open()

								$command = $Connection.CreateCommand()
								$command.CommandText = $SQLQuery
								$result = $command.executenonquery()
								Write-Host "result: $result"
								$Connection.Close()
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
							LogErr "Uploading the test results cancelled due to wrong database configuration!"
							$testResult = "FAIL"
						}
					}
				}
			}			
		}

		catch
		{
			$ErrorMessage =  $_.Exception.Message
			LogMsg "EXCEPTION : $ErrorMessage"
			$testResult = "Aborted"
		}

		Finally
		{
			$metaData = $protocol 
			if (!$testResult)
			{
				$testResult = "Aborted"
			}
			$resultArr += $testResult
		}
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



