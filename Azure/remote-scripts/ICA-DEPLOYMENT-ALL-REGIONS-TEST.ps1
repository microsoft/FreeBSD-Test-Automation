Import-Module .\TestLibs\RDFELibs.psm1 -Force 
$result = "" 
$testResult = "" 
$resultArr = @() 
$successCount = 0 
$failCount = 0 

$locationList = Get-AzureRmLocation | select Location 

foreach($location in $locationList) 
{ 
    LogMsg "Try to deploy VM in location $($location.Location)"  
    $vmUsage = Get-AzureRmVMUsage -Location $location.Location 
    LogMsg "Current core is $($vmUsage[1].CurrentValue), limit is $($vmUsage[1].Limit)" 
    if($vmUsage[1].CurrentValue -eq $vmUsage[1].Limit) 
    { 
        $successCount = $successCount + 1 
        LogMsg "Core is not enough, not create VM in $location.Location" 
    } 
    else 
    { 
        $rgName = "freebsd" + (Get-Random) 
        New-AzureRmResourceGroup -Name $rgName -Location $location.Location 
        New-AzureRmResourceGroupDeployment -Name $rgName -ResourceGroupName $rgName -TemplateParameterFile ".\remote-scripts\ICA-All-Region-TEST\azuredeploy.parameters.json" -TemplateFile ".\remote-scripts\ICA-All-Region-TEST\azuredeploy.json" -DeploymentDebugLogLevel All -Verbose 
        $ip = (Get-AzureRmPublicIpAddress -ResourceGroupName $rgName).IpAddress 
        $port=22 
        $socket = new-object Net.Sockets.TcpClient 
        $isConnected = "False" 
        try 
        { 
		    $socket.Connect($ip, $port)  
            $isConnected = "True" 
        } 
	    catch [System.Net.Sockets.SocketException] 
        { 
            $isConnected = "False" 
		    LogMsg "not connect" 
        } 

        if ($socket.Connected)  
        { 
		    LogMsg "Connect to VM successfully" 
		    $successCount = $successCount + 1 
		    $isConnected = "True" 
        } 

		$socket.Close() 
		if($isConnected -eq "True") 
		{ 
			LogMsg "Deploy pass, delete the environment" 
			Remove-AzureRmResourceGroup -Name $rgName -Force 
		}
		else 
		{ 
			$failCount = $failCount = + 1 
			LogMsg "Deploy failed, keep the environment" 
		} 
	} 
} 

if($failCount -gt 0) 
{ 
  $testResult = "FAIL" 
} 
else 
{ 
  $testResult = "PASS" 
} 

$resultArr += $testResult 
$result = GetFinalResultHeader -resultarr $resultArr 
return $result 

