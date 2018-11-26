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
		
		if( $EnableAcceleratedNetworking )
		{
			LogMsg "The accelerate network is enabled"
			RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *" -runAsSudo
			LogMsg "Executing : bash $($currentTestData.testScript)"
			RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "bash $($currentTestData.testScript)" -runAsSudo
			RemoteCopy -download -downloadFrom $hs1VIP -files "/root/state.txt, /root/summary.log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
			$testStatus = Get-Content $LogDir\state.txt
			if ($testStatus -eq "TestCompleted")
			{
				LogMsg "SRIOV test successfully"
				$testResult = "PASS"
			}
			else
			{
				LogErr "SRIOV test failed"
				$testResult = "FAIL"
			}
		}
		else
		{
			LogErr "SRIOV test aborted because the accelerate network is NOT enabled in Azure"
			$testResult = "Aborted"
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
