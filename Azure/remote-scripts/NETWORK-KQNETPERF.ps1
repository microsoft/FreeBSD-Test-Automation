Import-Module .\TestLibs\RDFELibs.psm1 -Force

$testResult = ""
$result = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
{
	foreach ($VMdata in $allVMData)
	{
		if ($VMdata.RoleName -imatch $currentTestData.setupType)
		{
			$hs1VIP = $VMdata.PublicIP
			$hs1vm1sshport = $VMdata.SSHPort
			$hs1vm1tcpport = $VMdata.TCPtestPort
			$hs1ServiceUrl = $VMdata.URL
			$clientGroupName = $VMdata.ResourceGroupName
		}
		elseif ($VMdata.RoleName -imatch "DTAP")
		{
			$dtapServerIp = $VMdata.PublicIP
			$dtapServerSshport = $VMdata.SSHPort
			$dtapServerTcpport = $VMdata.TCPtestPort
			$serverGroupName = $VMdata.ResourceGroupName
		}
		
	}
	
	$cmd1="$python_cmd start-kqnetperf-server.py -p $dtapServerTcpport -t2 && mv -f Runtime.log start-server.py.log"
	$cmd2="$python_cmd start-kqnetperf-client.py -c $dtapServerIp -p $dtapServerTcpport -t20"

	$server = CreateIperfNode -nodeIp $dtapServerIp -nodeSshPort $dtapServerSshport -nodeTcpPort $dtapServerTcpport -nodeIperfCmd $cmd1 -user $user -password $password -files $currentTestData.files -logDir $LogDir -groupName $serverGroupName
	$client = CreateIperfNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeTcpPort $hs1vm1tcpport -nodeIperfCmd $cmd2 -user $user -password $password -files $currentTestData.files -logDir $LogDir -groupName $clientGroupName

	RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "date >  summary.record;uname -a >>  summary.record" -runAsSudo
	
	RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
	RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
	
	RemoteCopy -uploadTo $dtapServerIp -port $dtapServerSshport -files $currentTestData.files -username $user -password $password -upload
	RunLinuxCmd -username $user -password $password -ip $dtapServerIp -port $dtapServerSshport -command "chmod +x *" -runAsSudo
	
	LogMsg "Executing : Install qkperf"
	RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "tar -xvzf kq_netperf.tgz " -runAsSudo
	RunLinuxCmd -username $user -password $password -ip $dtapServerIp -port $dtapServerSshport -command "tar -xvzf kq_netperf.tgz " -runAsSudo
	
	$resultArr = @()
	$result = "", ""
	$Subtests= $currentTestData.connections
	$connections = $Subtests.Split(",")	
	$runTimeSec= $currentTestData.runTimeSec	
	$threads= $currentTestData.threads
	$connections = $threads.Split(",")

	foreach ($thread in $threads) 
	{
	    foreach ($connection in $connections) 
		{
			try
			{
				$testResult = $null
				
			    $server.cmd = "$python_cmd start-kqnetperf-server.py -p $dtapServerTcpport -t $thread  && mv -f Runtime.log start-server.py.log"			
				
				LogMsg "Test Started for Parallel Connections $connection"
				$client.cmd = "$python_cmd start-kqnetperf-client.py -4 $dtapServerIp -p $dtapServerTcpport -t $thread -c $connection -l $runTimeSec"
				mkdir $LogDir\$connection -ErrorAction SilentlyContinue | out-null
				$server.logDir = $LogDir + "\$connection"
				$client.logDir = $LogDir + "\$connection"
				$suppressedOut = RunLinuxCmd -username $server.user -password $server.password -ip $server.ip -port $server.sshport -command "rm -rf kqnetperf-server.txt" -runAsSudo
				$testResult = KQperfClientServerTest $server $client  $runTimeSec
				
				#Rename the client log
				Copy-Item "$($client.LogDir)\kqnetperf-client.txt"   "$($client.LogDir)\$connection-$thread-$runTimeSec-freebsd.kq.log"	
			}

			catch
			{
				$ErrorMessage =  $_.Exception.Message
				LogMsg "EXCEPTION : $ErrorMessage"
			}

			Finally
			{
				$metaData = $connection 
				if (!$testResult)
				{
					$testResult = "Aborted"
				}
				$resultArr += $testResult
			}
		}

	}
	
	if( $testResult -eq "PASS" )
	{
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv summary.record  summary.log " -runAsSudo
		RemoteCopy -downloadFrom $hs1VIP -port $hs1vm1sshport -username $user -password $password -files "summary.log" -downloadTo $LogDir -download
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



