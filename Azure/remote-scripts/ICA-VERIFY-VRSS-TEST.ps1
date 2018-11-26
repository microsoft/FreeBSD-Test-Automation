# This script deploys the VMs for the vRSS test.


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
		$hs1VIP = $allVMData[0].PublicIP
		$hs1ServiceUrl = $allVMData[0].URL
		$hs1vm1IP = $allVMData[0].InternalIP
		$hs1vm1sshport = $allVMData[0].SSHPort
		$hs1vm1tcpport = $allVMData[0].TCPtestPort
		
		$hs1vm2IP = $allVMData[1].InternalIP
		$hs1vm2sshport = $allVMData[1].SSHPort
		$hs1vm2tcpport = $allVMData[1].TCPtestPort
		
		$KernelVersionVM1 = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "uname -a" -runAsSudo 
		$KernelVersionVM2 = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "uname -a" -runAsSudo 
	
		LogMsg "VM is ready for vRSS test"
		LogMsg "VM1 kernel version: $KernelVersionVM1"
		LogMsg "VM2 kernel version: $KernelVersionVM2"
        
		# On VM1
		$cmd = "pkg install -y nginx"
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command $cmd -runAsSudo
		
        $cmd = "sed -i .bak 's/^[ ]*listen[ ]*80;$/listen   $hs1vm1tcpport;/g' /usr/local/etc/nginx/nginx.conf"
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command $cmd -runAsSudo
		
		$cmd = "service nginx onestart"
        $count = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command $cmd -runAsSudo
		
		
        # On VM2
        $cmd = "pkg install -y curl"
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command $cmd -runAsSudo
       
        RemoteCopy -uploadTo $hs1VIP -port $hs1vm2sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "chmod +x *" -runAsSudo
        
        LogMsg "Executing : $($currentTestData.testScript)"
        RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "bash $($currentTestData.testScript)" -runAsSudo
        
        #Do it again
		LogMsg "Executing : $($currentTestData.testScript)"
        RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm2sshport -command "bash $($currentTestData.testScript)" -runAsSudo

        # On VM1
        $count = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "sysctl -n dev.hn.0.rx_ring_inuse" -runAsSudo
        LogMsg "The value of sysctl -n dev.hn.0.rx_ring_inuse: $count"
        for( $j = 0; $j -lt $count; $j++ )
        {
            $packets = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "sysctl -n dev.hn.0.rx.$j.packets" -runAsSudo
            if( $packets -eq 0 )
            {
                $testResult = "FAIL"
            }
            else
            {
                $testResult = "PASS"
            }
            
            LogMsg "The value of sysctl -n dev.hn.0.rx.$j.packets : $packets"
        }
        
		LogMsg "Test result : $testResult"
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = "Vrss Result"
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
        $resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
	}   
}
else
{
    LogMsg "Deploy VMs failed!"
	$testResult = "Aborted"
	$resultArr += $testResult
    $resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result
