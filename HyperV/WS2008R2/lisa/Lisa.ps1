########################################################################
# lisa.ps1  --  Linux Integration Services Automation
#
# Description:
#     This powershell script automates the tasks required to test
#     the LIS components on multiple platforms.  This is the entry
#     script into the automation.  Depending on the command line
#     arguments, functions in other scripts will be invoked.
#
#     Other required powershell scripts:
#         stateEngine.ps1
#             Provides the functions that drive the VMs running
#             test case scripts.
#
#         utils.ps1
#             Provides utility functions.
#
#         validatexml.ps1
#             Functions to validate the tags in your xml file.
#
# History:
#   7-07-2011  nmeier  Created.
#
#
########################################################################

param([string] $cmdVerb,
      [string] $cmdNoun,
      [string] $VMs,
      [string] $vmName,
      [string] $hvServer,
      [string] $ipv4,
      [string] $sshKey,
      [string] $suite,
      [string] $testParams,
      [switch] $email,
      [switch] $examples,
      [int]    $dbgLevel=0
     )


#
# Global variables
#
$lisaVersion = "2.0 - Alpha 1"
$logfileRootDir = ".\TestResults"
$logFile = "ica.log"

$testDir = $null
$xmlConfig = $null

$testStartTime = [DateTime]::Now
Import-Module .\UtilLibs.psm1 -Force

########################################################################
#
# LogMsg()
#
########################################################################
function LogMsg([int]$level, [string]$msg)
{
    if ($level -le $dbgLevel)
    {
        $now = [Datetime]::Now.ToString("MM/dd/yyyy hh:mm:ss : ")
        ($now + $msg) | out-file -encoding ASCII -append -filePath $logfile
        
        $color = "white"
        if ( $msg.StartsWith("Error"))
        {
            $color = "red"
        }
        elseif ($msg.StartsWith("Warn"))
        {
            $color = "Yellow"
        }
        else
        {
            $color = "gray"
        }
        
        write-host -f $color "$msg"
    }
}


########################################################################
#
# Usage()
#
########################################################################
function Usage()
{
    write-host -f Cyan "`nLISA version $lisaVersion`r`n"
    write-host "Usage: lisa cmdVerb cmdNoun [options]`r`n"
    write-host "    cmdVerb  cmdNoun      options     Description"
    write-host "    -------  -----------  ----------  -------------------------------------"
    write-host "    help                              : Display this usage message"
    write-host "                          -examples   : Display usage examples"
    write-host "    validate xmlFilename              : Validate the .xml file"                   
    write-host "                          -datachecks : Perform data checks on the Hyper-V server"
    write-host "    run      xmlFilename              : Run tests on VMs defined in the xmlFilename"
    write-host "                          -eMail      : Send an e-mail after tests complete"
    write-host "                          -VMs        : Comma separated list of VM names to run tests"
    write-host "                          -vmName     : Name of a user supplied VM"
    write-host "                          -hvServer   : Name (or IP) of HyperV server hosting user supplied VM"
    write-host "                          -ipv4       : IP address of a user supplied VM"
    write-host "                          -sshKey     : The SSH key of a user supplied VM"
    write-host "                          -suite      : Name of test suite to run on user supplied VM"
    write-host "                          -testParams : Quoted string of semicolon separated parameters"
    write-host "                                         -testParams `"a=1;b='x y';c=3`""
    write-host
    write-host "  Common options"
    write-host "         -dbgLevel   : Specifies the level of debug messages"
    write-host "`n"
    
    if ($examples)
    {
        Write-host "`r`nExamples"
        write-host "    Run tests on all VMs defined in the specified xml file"
        write-host "        .\lisa run xml\mySmokeTests.xml`r`n"
        write-host "    Run tests on a specific subset of VMs defined in the xml file"
        write-host "        .\lisa run xml\mySmokeTests.xml -VMs rhel61, sles11sp1`r`n"
        write-host "    Run tests on a single VM not listed in the .xml file"
        write-host "        .\lisa run xml\mySmokeTests.xml -vmName Fedora13 -hvServer win8Srv -ipv4 10.10.22.34 -suite Smoke -sshKey rhel_id_rsa.ppk`r`n"
        write-host "    Validate the contents of your .xml file"
        write-host "        .\lisa validate xml\mySmokeTests.xml`r`n"
        write-host
    }
}



#####################################################################
#
# Test-Admin
#
#####################################################################
function Test-Admin()
{
	<#
	.Synopsis
    	Check if process is running as an Administrator
    .Description
        Test if the user context this process is running as
        has Administrator privileges
    .Example
        Test-Admin
	#> 
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}


#####################################################################
#
# AddUserToXmlTree
#
#####################################################################
function AddUserVmToXmlTree ([string] $vmName, [string] $hvServer, [string] $ipv4, [string] $sshKey, [string] $testSuite, [XML] $xml)
{
    <#
    .Synopsis
        Add a new <VM> element to the XML data
        
    .Description
    
    .Parameter vmName
    
    .Parameter hvServer
    
    .Parameter ipv4
    
    .Parameter password
    
    .Parameter testSuite
    
    .Parameter xml
    
    .ReturnValue
        none.
        
    .Example
    
    #>
    
    #
    # Insert a new VM definition for the user supuplied VM
    #

    # Create a new XML element
    $newVM = $xml.CreateElement("VM")
    
    #
    # Add the core child elements to the new XML element
    #
    $newName = $xml.CreateElement("vmName")
    $newName.set_InnerText($vmName)
    $newVM.AppendChild($newName)
    
    $newHvServer = $xml.CreateElement("hvServer")
    $newHvServer.set_InnerText($hvServer)
    $newVM.AppendChild($newHvServer)
    
    $newIpv4 = $xml.CreateElement("ipv4")
    $newIpv4.set_InnerText($ipv4)
    $newVM.AppendChild($newIpv4)
    
    $newSshKey = $xml.CreateElement("sshKey")
    $newSshKey.set_InnerText($sshKey)
    $newVM.AppendChild($newSshKey)
    
    $newTestSuite = $xml.CreateElement("testSuite")
    $newTestSuite.set_InnerText($testSuite)
    $newVM.AppendChild($newTestSuite)
    
    #
    # Add the vm XML element to the XML data
    #
    $xml.config.VMs.AppendChild($newVM)
    
    #
    # Now remove all the other VMs we don't care about
    #
    PruneVMsFromXmlTree $vmName $xml
}


#####################################################################
#
# PruneVMsFromXmlTree
#
#####################################################################
function PruneVMsFromXmlTree ([string] $vmName, [XML] $xml)
{
    if ($vmName)
    {
        $vms = $vmName.Split(" ")

        #
        # Now remove some of the VMs from the xml tree
        #
        foreach ($vm in $xml.config.VMs.vm)
        {
            if ($vms -notcontains $($vm.vmName))
            {
                LogMsg 5 "Info : Removing $($vm.vmName) from XML tree"
                $xml.config.VMs.RemoveChild($vm) | out-null
            }
        }

        #
        # Complain if an unknown VM was specified
        #
        foreach ($name in $vms)
        {
            $found = $false
            foreach ($vm in $xml.config.VMs.vm)
            {
                if ($name -eq $($vm.vmName))
                {
                    $found = $true
                }   
            }
        
            if (! $found)
            {
                LogMsg 0 "Warn : Unknown VM, name = $name"
            }
        }
    }
    else
    {
        LogMsg 0 "Warn : PruneVMsFromXMLTree - was passed a null vmName"
    }
}


#####################################################################
#
# AddTestParamsToVMs
#
#####################################################################
function AddTestParamsToVMs ($xmlData, $tParams)
{
    $params = $tParams.Split(";")
    if ($params)
    {
        foreach($vm in $xmlData.config.VMs.vm)
        {
            $tp = $vm.testParams
            
            #
            # Add the vm.testParams element if it does not exist
            #
            if (-not $vm.testParams)
            {
                $newTestParams = $xmlData.CreateElement("testParams")
                $tp = $vm.AppendChild($newTestParams)
            }
            
            #
            # Add a <param> for each parameter from the command line
            #
            foreach($param in $params)
            {
                $newParam = $xmlData.CreateElement("param")
                $newParam.set_InnerText($param.Trim())
                $tp.AppendChild($newParam)
            }
        }
    }
}


#####################################################################
#
# RunTests
#
#####################################################################
function RunTests ([String] $xmlFilename )
{
    #
    # Make sure we have a .xml filename to work with
    #
    if (! $xmlFilename)
    {
        write-host -f Red "Error: xml filename missing"
        return $false
    }

    #
    # Make sure the .xml file exists, then load it
    #
    if (! (test-path $xmlFilename))
    {
        write-host -f Red "Error: XML config file '$xmlFilename' does not exist."
        return $false
    }

    $xmlConfig = [xml] (Get-Content -Path $xmlFilename)
    if ($null -eq $xmlConfig)
    {
        write-host -f Red "Error: Unable to parse the .xml file"
        return $false
    }

    $rootDir = $logfileRootDir
    if ($xmlConfig.config.global.logfileRootDir)
    {
        $rootDir = $xmlConfig.config.global.logfileRootDir
    }
    
    #
    # Create the directory for the log files if it does not exist
    #
    if (! (test-path $rootDir))
    {
        $d = mkdir $rootDir -erroraction:silentlycontinue
        if ($d -eq $null)
        {
            write-host -f red "Error: root log directory does not exist and cannot be created"
            write-host -f red "       root log directory = $rootDir"
            return $false
        }
    }
    
    $fname = [System.IO.Path]::GetFilenameWithoutExtension($xmlFilename)
    $testRunDir = $fname + "-" + $Script:testStartTime.ToString("yyyyMMdd-HHmmss")
    $testDir = join-path -path $rootDir -childPath $testRunDir
    mkdir $testDir | out-null
    
    $logFile = Join-Path -path $testDir -childPath $logFile
        
    LogMsg 0 "LIS Automation script - version $lisaVersion"
    LogMsg 4 "Info : Created directory: $testDir"
    LogMsg 4 "Info : Logfile =  $logfile"
    LogMsg 4 "Info : Using XML file:  $xmlFilename"

    if (-not (Test-Admin))
    {
        LogMsg 0 "Error: Access denied. The script must be run as Administrator."
        LogMsg 0 "Error:                The WMI calls require administrator privileges."
        return $False
    }

    #
    # See if we need to modify the in memory copy of the .xml file
    #
    if ($vmName)
    {
        #
        # Run tests on a user supplied VM
        #
        if ($hvServer -and $ipv4 -and $password -and $testSuite)
        {   
            #
            # Add the user provided VM to the in memory copy of the xml
            # file, then remove all the other VMs from the in memory copy
            #
            AddUserVmToXmlTree $vmName $hvServer $ipv4 $sshKey $testSuite $xmlConfig
        }
        else
        {
            LogMsg 0 "Error: For user supplied VM, you must specify all of the following options:`n         -vmName -hvServer -ipv4 -password -testSuite"
        }
    }
    elseif ($VMs)
    {     
        #
        # Run tests on a subset of VMs defined in the XML file.  Remove the un-used
        # VMs from the in memory copy of the XML file.
        #
        PruneVMsFromXmlTree $VMs $xmlConfig
        if (-not $xmlConfig.config.VMs)
        {
            LogMsg 0 "Error: No defined VMs to run tests"
            LogMsg 0 "Error: The following VMs do not exist: $VMs"
            return $false
        }
    }

    #
    # If testParams were specified, add them to the VMs
    #
    if ($testParams)
    {
        AddTestParamsToVMs $xmlConfig $testParams
    }

    
    # Start to generate test report
	if( $testReport -eq $null )
	{
		$testReport = "$pwd\report.xml"
	}
	StartLogReport $testReport 
	$Global:testsuite = StartLogTestSuite "BIS" $Script:testStartTime
	$Global:testSuiteResultDetails=@{"totalTc"=0;"totalPassTc"=0;"totalFailTc"=0;"totalAbortedTc"=0;"totalElapseTime"=0}
	$startTime = [Datetime]::Now.ToUniversalTime()

    
    LogMsg 10 "Info : Calling RunICTests"
    . .\stateEngine.ps1
    RunICTests $xmlConfig

    # Finish to generate test report	
	$endTime = [Datetime]::Now.ToUniversalTime()
	$testSuiteResultDetails.totalElapseTime = ($endTime-$startTime).TotalSeconds
	FinishLogTestSuite $testsuite $testSuiteResultDetails.totalElapseTime
	FinishLogReport
	Write-Host $testSuiteResultDetails.totalPassTc,$testSuiteResultDetails.totalFailTc,$testSuiteResultDetails.totalAbortedTc

	# Compress logs
	if( $reportCompressFile -eq $null )
	{
		$reportCompressFile = "$pwd\logs.zip"
	}
	CICompressFolderToZip "$testDir" $reportCompressFile
	
    
    #
    # email the test results if requested
    #
    if ($eMail)
    {
        SendEmail $xmlConfig $Script:testStartTime $xmlFilename
    }

    $summary = SummaryToString $xmlConfig $Script:testStartTime $xmlFilename
    
    #
    # Remove the HTML tags
    $summary = $summary.Replace("<br />", "`r`n")
    $summary = $summary.Replace("<pre>", "")
    $summary = $summary.Replace("</pre>", "")

    LogMsg 0 "$summary"

    return $true
}


#####################################################################
#
# ValidateXMLFile
#
#####################################################################
function ValidateXMLFile ([String] $xmlFilename)
{
    . .\validatexml.ps1
    ValidateUserXmlFile $xmlFilename
}


########################################################################
#
#  Main body of the script
#
########################################################################

if ( $help)
{
    Usage
    exit 0
}

$retVal = 0

switch ($cmdVerb)
{
"run" {
        $sts = RunTests $cmdNoun
        if (! $sts)
        {
            $retVal = 2
        }
    }
"validate" {
        $sts = ValidateXmlFile $cmdNoun
        if (! $sts)
        {
            $retVal = 3
        }
    }
"help" {
        Usage
        $retVal = 0
    }
default    {
        if ($cmdVerb.Length -eq 0)
        {
            Usage
            $retVal = 0
        }
        else
        {
            LogMsg 0 "Unknown command verb: $cmdVerb"
            Usage
        }
    }
}

exit $retVal