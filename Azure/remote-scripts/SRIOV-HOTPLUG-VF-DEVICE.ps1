Import-Module .\TestLibs\RDFELibs.psm1 -Force

$testResult = ""
$result = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig

if($isDeployed)
{
    Try {
        $ClientIp = $allVMData[0].PublicIP
        $ClientSshport = $allVMData[0].SSHPort

        $ServerIp = $allVMData[1].PublicIP
        $ServerSshport = $allVMData[1].SSHPort
        $ServerInterIp = $allVMData[1].InternalIP

        #Start iperf in server mode
        RunLinuxCmd -username $user -password $password -ip $ServerIp -port $ServerSshport -command "nohup iperf -s > client.out" -runAsSudo -RunInBackGround

$myString = @"
while true
do
    iperf -t 30 -c $ServerInterIp --logfile PerfResults.log
    sleep 1
done
"@
        Set-Content "$LogDir\Start_Iperf_Client.sh" $myString
        RemoteCopy -uploadTo $ClientIp -port $ClientSshport -files "$LogDir\Start_Iperf_Client.sh" -username $user -password $password -upload
        #Start iperf client
        RunLinuxCmd -username $user -password $password -ip $ClientIp -port $ClientSshport -command "sh Start_Iperf_Client.sh" -runAsSudo -RunInBackGround

        RemoteCopy -uploadTo $ClientIp -port $ClientSshport -files $currentTestData.files -username $user -password $password -upload
        RunLinuxCmd -username $user -password $password -ip $ClientIp -port $ClientSshport -command "bash SRIOV-HOTPLUG-VF-DEVICE.sh" -runAsSudo
        RemoteCopy -download -downloadFrom $ClientIp -files "/root/state.txt" -downloadTo $LogDir -port $ClientSshport -username $user -password $password
        $testStatus = Get-Content $LogDir\state.txt
        if ($testStatus -eq "TestCompleted")
        {
            $testResult = "PASS"
            LogMsg "Test Completed"
        }
    } Catch {
        $ErrorMessage =  $_.Exception.Message
        $ErrorLine = $_.InvocationInfo.ScriptLineNumber
        LogMsg "EXCEPTION : $ErrorMessage at line: $ErrorLine"
    } Finally {
        if (!$testResult)
        {
            $testResult = "Aborted"
        }
        $resultArr += $testResult
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

#Return the result and summery to the test suite script
return $result
