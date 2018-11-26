<#
JUnit XML Report Schema:
	http://windyroad.com.au/dl/Open%20Source/JUnit.xsd
Example:
	Import-Module .\UtilLibs.psm1 -Force

	StartLogReport("$pwd/report.xml")

	$testsuite = StartLogTestSuite "CloudTesting"

	$testcase = StartLogTestCase $testsuite "BVT" "CloudTesting.BVT"
	FinishLogTestCase $testcase

	$testcase = StartLogTestCase $testsuite "NETWORK" "CloudTesting.NETWORK"
	FinishLogTestCase $testcase "FAIL" "NETWORK fail" "Stack trace: XXX"

	$testcase = StartLogTestCase $testsuite "VNET" "CloudTesting.VNET"
	FinishLogTestCase $testcase "ERROR" "VNET error" "Stack trace: XXX"

	FinishLogTestSuite($testsuite)

	$testsuite = StartLogTestSuite "FCTesting"

	$testcase = StartLogTestCase $testsuite "BVT" "FCTesting.BVT"
	FinishLogTestCase $testcase

	$testcase = StartLogTestCase $testsuite "NEGATIVE" "FCTesting.NEGATIVE"
	FinishLogTestCase $testcase "FAIL" "NEGATIVE fail" "Stack trace: XXX"

	FinishLogTestSuite($testsuite)

	FinishLogReport

report.xml:
	<testsuites>
	  <testsuite name="CloudTesting" timestamp="2014-07-11T06:37:24" tests="3" failures="1" errors="1" time="0.04">
		<testcase name="BVT" classname="CloudTesting.BVT" time="0" />
		<testcase name="NETWORK" classname="CloudTesting.NETWORK" time="0">
		  <failure message="NETWORK fail">Stack trace: XXX</failure>
		</testcase>
		<testcase name="VNET" classname="CloudTesting.VNET" time="0">
		  <error message="VNET error">Stack trace: XXX</error>
		</testcase>
	  </testsuite>
	  <testsuite name="FCTesting" timestamp="2014-07-11T06:37:24" tests="2" failures="1" errors="0" time="0.03">
		<testcase name="BVT" classname="FCTesting.BVT" time="0" />
		<testcase name="NEGATIVE" classname="FCTesting.NEGATIVE" time="0">
		  <failure message="NEGATIVE fail">Stack trace: XXX</failure>
		</testcase>
	  </testsuite>
	</testsuites>
#>

[xml]$junitReport = $null
[object]$reportRootNode = $null
[string]$junitReportPath = ""
[bool]$isGenerateJunitReport=$False

Function FinishCaseReport([string]$completionCode, [string]$summaryLog, [System.Xml.XmlElement]$vm)
{
	$caseFinish = [DateTime]::Now
	$caseElapseTime = ($caseFinish - $Global:caseStart).TotalSeconds
	$testSuiteResultDetails.totalElapseTime += $caseElapseTime
	if($completionCode -eq "Success")
	{		
		$testSuiteResultDetails.totalPassTc += 1
		FinishLogTestCase $Global:testcase $caseElapseTime	
	}
	elseif($completionCode -eq "Failed")
	{
		$testSuiteResultDetails.totalFailTc += 1
		$caseLog = Get-Content -path $summaryLog
		FinishLogTestCase $Global:testcase $caseElapseTime "FAIL" "$($vm.currentTest) failed." $caseLog		
	}
	else
	{
 		$testSuiteResultDetails.totalAbortedTc += 1
		$caseLog = Get-Content -path $summaryLog
		FinishLogTestCase $Global:testcase $caseElapseTime "ERROR" "$($vm.currentTest) is aborted." $caseLog	
	}
}


Function StartLogReport([string]$reportPath, [DateTime]$startTime)
{
	if(!$junitReport)
	{
		$global:junitReport = new-object System.Xml.XmlDocument
		$newElement = $global:junitReport.CreateElement("testsuites")
		$global:reportRootNode = $global:junitReport.AppendChild($newElement)
		
		$global:junitReportPath = $reportPath
		
		$global:isGenerateJunitReport = $True
	}
	else
	{
		throw "CI report has been created."
	}
	
	return $junitReport
}

Function FinishLogReport([bool]$isFinal=$True)
{
	if(!$global:isGenerateJunitReport)
	{
		return
	}
	
	$global:junitReport.Save($global:junitReportPath)
	if($isFinal)
	{
		$global:junitReport = $null
		$global:reportRootNode = $null
		$global:junitReportPath = ""
		$global:isGenerateJunitReport=$False
	}
}

Function StartLogTestSuite([string]$testsuiteName, [DateTime]$startTime)
{
	if(!$global:isGenerateJunitReport)
	{
		return
	}
	
	$newElement = $global:junitReport.CreateElement("testsuite")
	$newElement.SetAttribute("name", $testsuiteName)
	$newElement.SetAttribute("timestamp", $startTime)
	$newElement.SetAttribute("tests", 0)
	$newElement.SetAttribute("failures", 0)
	$newElement.SetAttribute("errors", 0)
	$newElement.SetAttribute("time", 0)
	$testsuiteNode = $global:reportRootNode.AppendChild($newElement)
	
	$timer = CIStartTimer
	$testsuite = New-Object -TypeName PSObject
	Add-Member -InputObject $testsuite -MemberType NoteProperty -Name testsuiteNode -Value $testsuiteNode -Force
	Add-Member -InputObject $testsuite -MemberType NoteProperty -Name timer -Value $timer -Force
	
	return $testsuite
}

Function FinishLogTestSuite([object]$testsuite, [Float]$totalElapseTime)
{
	if(!$global:isGenerateJunitReport)
	{
		return
	}
	
	$testsuite.testsuiteNode.Attributes["time"].Value = $totalElapseTime
	FinishLogReport $False
}

Function StartLogTestCase([object]$testsuite, [string]$caseName, [string]$className)
{
	if(!$global:isGenerateJunitReport)
	{
		return
	}
	
	$newElement = $global:junitReport.CreateElement("testcase")
	$newElement.SetAttribute("name", $caseName)
	$newElement.SetAttribute("classname", $classname)
	$newElement.SetAttribute("time", 0)
	
	$testcaseNode = $testsuite.testsuiteNode.AppendChild($newElement)
	
	$timer = CIStartTimer
	$testcase = New-Object -TypeName PSObject
	Add-Member -InputObject $testcase -MemberType NoteProperty -Name testsuite -Value $testsuite -Force
	Add-Member -InputObject $testcase -MemberType NoteProperty -Name testcaseNode -Value $testcaseNode -Force
	Add-Member -InputObject $testcase -MemberType NoteProperty -Name timer -Value $timer -Force
	return $testcase
}

Function FinishLogTestCase([object]$testcase, [string]$stateTimeStamp, [string]$result="PASS", [string]$message="", [string]$detail="")
{
	if(!$global:isGenerateJunitReport)
	{
		return
	}
	
	$testcase.testcaseNode.Attributes["time"].Value = $stateTimeStamp
	
	[int]$testcase.testsuite.testsuiteNode.Attributes["tests"].Value += 1
	if ($result -eq "FAIL")
	{
		$newChildElement = $global:junitReport.CreateElement("failure")
		$newChildElement.InnerText = $detail
		$newChildElement.SetAttribute("message", $message)
		$testcase.testcaseNode.AppendChild($newChildElement)
		
		[int]$testcase.testsuite.testsuiteNode.Attributes["failures"].Value += 1
	}
	
	if ($result -eq "ERROR")
	{
		$newChildElement = $global:junitReport.CreateElement("error")
		$newChildElement.InnerText = $detail
		$newChildElement.SetAttribute("message", $message)
		$testcase.testcaseNode.AppendChild($newChildElement)
		
		[int]$testcase.testsuite.testsuiteNode.Attributes["errors"].Value += 1
	}
	FinishLogReport $False
}

Function CIStartTimer()
{
	$timer = [system.diagnostics.stopwatch]::startNew()
	return $timer
}

Function CIStopTimer([System.Diagnostics.Stopwatch]$timer)
{
	$timer.Stop()
	return [System.Math]::Round($timer.Elapsed.TotalSeconds, 2)

}

<#
Usage:
	CICompressFolderToZip $folder $zipFileName
Description:
	Compress a folder into a zip file. 
	If $zipFileName is not indicated, the zip file will be generated under the parent folder of $folder and named as same as the name of $folder.
#>
Function CICountZipItems([__ComObject] $zipFile)
{
    if ($zipFile -eq $null)
    {
        Throw "Value cannot be null: zipFile"
    }
    
    Write-Host ("Counting items in zip file (" + $zipFile.Self.Path + ")...")
    
    [int] $count = CICountZipItemsRecursive($zipFile)

    Write-Host ($count.ToString() + " items in zip file (" `
        + $zipFile.Self.Path + ").")
    
    return $count
}

Function CICountZipItemsRecursive([__ComObject] $parent)
{
    if ($parent -eq $null)
    {
        Throw "Value cannot be null: parent"
    }
    
    [int] $count = 0

    $parent.Items() |
        ForEach-Object {
            $count += 1
            
            if ($_.IsFolder -eq $true)
            {
                $count += CICountZipItemsRecursive($_.GetFolder)
            }
        }
    
    return $count
}

Function CIIsFileLocked([string] $path)
{
    if ([string]::IsNullOrEmpty($path) -eq $true)
    {
        Throw "The path must be specified."
    }
    
    [bool] $fileExists = Test-Path $path
    
    if ($fileExists -eq $false)
    {
        Throw "File does not exist (" + $path + ")"
    }
    
    [bool] $isFileLocked = $true

    $file = $null
    
    Try
    {
        $file = [IO.File]::Open(
            $path,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            [IO.FileShare]::None)
            
        $isFileLocked = $false
    }
    Catch [IO.IOException]
    {
        if ($_.Exception.Message.EndsWith(
            "it is being used by another process.") -eq $false)
        {
            Throw $_.Exception
        }
    }
    Finally
    {
        if ($file -ne $null)
        {
            $file.Close()
        }
    }
    
    return $isFileLocked
}
    
Function CIGetWaitInterval([int] $waitTime)
{
    if ($waitTime -lt 1000)
    {
        return 100
    }
    ElseIf ($waitTime -lt 5000)
    {
        return 1000
    }
    Else
    {
        return 5000
    }
}

Function CIWaitForZipOperationToFinish([__ComObject] $zipFile, [int] $expectedNumberOfItemsInZipFile, [int] $timeout)
{
    if ($zipFile -eq $null)
    {
        Throw "Value cannot be null: zipFile"
    }
    ElseIf ($expectedNumberOfItemsInZipFile -lt 1)
    {
        Throw "The expected number of items in the zip file must be specified."
    }
    
    Write-Host -NoNewLine "Waiting for zip operation to finish..."
    Start-Sleep -Milliseconds 1000 # ensure zip operation had time to start
    
    [int] $waitTime = 0
    [int] $maxWaitTime = $timeout * 1000 # [milliseconds]
    while($waitTime -lt $maxWaitTime)
    {
        [int] $waitInterval = CIGetWaitInterval($waitTime)
                
        Write-Host -NoNewLine "."
        Start-Sleep -Milliseconds $waitInterval
        $waitTime += $waitInterval

        Write-Debug ("Wait time: " + $waitTime / 1000 + " seconds")
        
        [bool] $isFileLocked = CIIsFileLocked($zipFile.Self.Path)
        
        if ($isFileLocked -eq $true)
        {
            Write-Debug "Zip file is locked by another process."
            Continue
        }
        Else
        {
            Break
        }
    }
    
    Write-Host                           
    
    if ($waitTime -ge $maxWaitTime)
    {
        Throw "Timeout exceeded waiting for zip operation"
    }
    
    [int] $count = CICountZipItems($zipFile)
    
    if ($count -eq $expectedNumberOfItemsInZipFile)
    {
        Write-Debug "The zip operation completed succesfully."
    }
    ElseIf ($count -eq 0)
    {
        Throw ("Zip file is empty. This can occur if the operation is" `
            + " cancelled by the user.")
    }
    ElseIf ($count -gt $expectedCount)
    {
        Throw "Zip file contains more than the expected number of items."
    }
}

Function CICompressFolderToZip([string]$folder, [string]$zipFileName=$null, [int]$timeout=120)
{
	[IO.DirectoryInfo] $directory = Get-Item "$folder"
	
    if ($directory -eq $null)
    {
        Throw "Value cannot be null: directory"
    }
    
    Write-Host ("Creating zip file for folder (" + $directory.FullName + ")...")
    
    [IO.DirectoryInfo] $parentDir = $directory.Parent
    
    if($zipFileName)
    {
        if(Test-Path $zipFileName)
        {
            Remove-Item $zipFileName
        }
    }
    else
    {
        if ($parentDir.FullName.EndsWith("\") -eq $true)
        {
            # e.g. $parentDir = "C:\"
            $zipFileName = $parentDir.FullName + $directory.Name + ".zip"
        }
        Else
        {
            $zipFileName = $parentDir.FullName + "\" + $directory.Name + ".zip"
        }
    }
    
    Set-Content $zipFileName ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        
    $shellApp = New-Object -ComObject Shell.Application
    $zipFile = $shellApp.NameSpace($zipFileName)

    if ($zipFile -eq $null)
    {
        Throw "Failed to get zip file object."
    }
    
    [int] $expectedCount = (Get-ChildItem $directory -Force -Recurse).Count
    $expectedCount += 1 # account for the top-level folder
    
    $zipFile.CopyHere($directory.FullName)

    # wait for CopyHere operation to complete
    CIWaitForZipOperationToFinish $zipFile $expectedCount $timeout
    
    Write-Host -Fore Green ("Successfully created zip file for folder (" `
        + $directory.FullName + ").")
}