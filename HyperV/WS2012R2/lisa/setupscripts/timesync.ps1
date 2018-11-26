########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0  
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################


<#
.Synopsis
    Verify the time on the VM.

.Description
    Verify the time on the VM synched with the Hyper-V host.
    This is not a long term time sync test.
        <test>
            <testName>Time_Sync_With_Host</testName>
            <testScript>setupScripts\timesync.ps1</testScript>
            <timeout>600</timeout>
            <onError>Continue</onError>
            <noReboot>True</noReboot>
            <testParams>
                <param>testDelay=60</param>
                <param>MaxTimeDiff=0.9</param>
                <param>TC_COVERED=CORE-02</param>
                <param>rootDir=D:\Lisa\trunk\lisablue</param>
            </testParams>
        </test>

    Test parameters
        TestDelay
            Default is 0.  This parameter is optional.
            Specifies a time in seconds, to sleep before
            asking the test VM for its time.

        MaxTimeDiff
            Default is 1 second.  This parameter is optional.
            Specifies the maximum time difference to allow.
            Since the time is collected from the VM via SSH
            network delays will increase the actual difference.

        TC_COVERED
            Required.
            Identifies the test case this test covers.

        RootDir
            Required.
            PowerShell test scripts are run as a PowerShell job.
            When a PowerShell job runs, the current directory
            will not be correct.  This specifies the directory
            that should be the current directory for the test.

.Parameter vmName
    Name of the VM to test.

.Parameter  hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter  testParams
    A string with test parameters.

.Example
    .\timesync.ps1 -vmName "myVM" -hvServer "myServer" -testParams "sshKey=lisa_id_rsa.ppk;rootDir=D:\lisa\trunk\lisablue"
#>



param ([String] $vmName, [String] $hvServer, [String] $testParams)


#####################################################################
#
# AskVmForTime()
#
#####################################################################
function AskVmForTime([String] $sshKey, [String] $ipv4, [string] $command)
{
    <#
    .Synopsis
        Send a time command to a VM
    .Description
        Use SSH to request the data/time on a Linux VM.
    .Parameter sshKey
        SSH key for the VM
    .Parameter ipv4
        IPv4 address of the VM
    .Parameter command
        Linux date command to send to the VM
    .Output
        The date/time string returned from the Linux VM.
    .Example
        AskVmForTime "lisa_id_rsa.ppk" "192.168.1.101" 'date "+%m/%d/%Y%t%T%p "'
    #>

    $retVal = $null

    $sshKeyPath = Resolve-Path $sshKey
    
    #
    # Note: We did not use SendCommandToVM since it does not return
    #       the output of the command.
    #
    $dt = .\bin\plink -i ${sshKeyPath} root@${ipv4} $command
    if ($?)
    {
        $retVal = $dt
    }
    else
    {
        LogMsg 0 "Error: $vmName unable to send command to VM. Command = '$command'"
    }

    return $retVal
}


#####################################################################
#
# GetUnixVMTime()
#
#####################################################################
function GetUnixVMTime([String] $sshKey, [String] $ipv4)
{
    <#
    .Synopsis
        Return a Linux VM current time as a string.
    .Description
        Return a Linxu VM current time as a string
    .Parameter sshKey
        SSH key used to connect to the Linux VM
    .Parameter ivp4
        IP address of the target Linux VM
    .Example
        GetUnixVMTime "lisa_id_rsa.ppk" "192.168.6.101"
    #>

    if (-not $sshKey)
    {
        return $null
    }

    if (-not $ipv4)
    {
        return $null
    }

    #
    # now=`date "+%m/%d/%Y %H:%M:%S%p"
    # returns 04/27/2012 16:10:30PM
    #
    $unixTimeStr = $null
    $command =  'date "+%m/%d/%Y%t%T%p "'

    $unixTimeStr = AskVMForTime ${sshKey} $ipv4 $command
    if (-not $unixTimeStr -and $unixTimeStr.Length -lt 20)
    {
        return $null
    }
    
    return $unixTimeStr
}




#####################################################################
#
# UpdateVmTimezoneBasedOnHost()
#
#####################################################################
function UpdateVmTimezoneBasedOnHost([String] $sshKey, [String] $ipv4)
{
	#In our test env, the usual time zone is Pacific or China Standard Time
	$command = ""
	$localTimeZone = (Get-WmiObject win32_timezone).StandardName
	if( $localTimeZone  -like "Pacific*" )
	{
		$command = "cp  /usr/share/zoneinfo/PST8PDT  /etc/localtime"
	}

	if( $localTimeZone  -like "China*" )
	{
		$command = "cp  /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime"
	}
	
	# Add other time zone if it's needed
	
	if( !$command )
	{
		"Error: Time zone is not updated"
		return 1
	}

	"The command is $command"
	AskVMForTime ${sshKey} $ipv4 $command

}

#####################################################################
#
# Main script body
#
#####################################################################

$retVal = $False

#
# Make sure all command line arguments were provided
#
if (-not $vmName)
{
    "Error: vmName argument is null"
    return $False
}

if (-not $hvServer)
{
    "Error: hvServer argument is null"
    return $False
}

if (-not $testParams)
{
    "Error: testParams argument is null"
    return $False
}

"timesync.ps1"
"  vmName    = ${vmName}"
"  hvServer  = ${hvServer}"
"  testParams= ${testParams}"

#
# Parse the testParams string
#
"Parsing test parameters"
$sshKey = $null
$ipv4 = $null
$maxTimeDiff = "5.1"  #The time in vm will be synced with host every 5 seconds
$rootDir = $null
$tcCovered = "unknown"
$testDelay = "10"

$params = $testParams.Split(";")
foreach($p in $params)
{
    $tokens = $p.Trim().Split("=")
    if ($tokens.Length -ne 2)
    {
        continue   # Just ignore the parameter
    }
    
    $val = $tokens[1].Trim()
    
    switch($tokens[0].Trim().ToLower())
    {
    "ipv4"        { $ipv4        = $val }
    "sshkey"      { $sshKey      = $val }
    "rootdir"     { $rootDir     = $val }
    "MaxTimeDiff" { $maxTimeDiff = $val }
    "TC_COVERED"  { $tcCovered   = $val }
    "TestDelay"   { $testDelay   = $val }
    default       { continue }
    }
}

#
# Make sure the required testParams were found
#
"Verify required test parameters were provided"
if (-not $sshKey)
{
    "Error: testParams is missing the sshKey parameter"
    return $False
}

#
# Change the working directory to where we should be
#
if (-not (Test-Path $rootDir))
{
    "Error: The directory `"${rootDir}`" does not exist"
    return $False
}

"Changing directory to ${rootDir}"
cd $rootDir

#
# Delete any summary.log from a previous test run, then create a new file
#
$summaryLog = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
"Covers ${tcCovered}" >> $summaryLog

#
# Source the utility functions so we have access to them
#
. .\setupscripts\TCUtils.ps1

#
# Determin the IPv4 address of the test VM
#
"Determine IPv4 address for VM '${vmName}'"
if (-not $ipv4)
{
    $ipv4 = GetIPv4 $vmName $hvServer
    if (-not $ipv4)
    {
        "Error: Unable to determin the IPv4 address for VM ${vmName}"  >> $summaryLog
        return $False
    }
}

"Test data"
"  ipv4        = ${ipv4}"
"  sshKey      = ${sshKey}"
"  maxTimeDiff = ${maxTimeDiff}"
"  testDelay   = ${testDelay}"
"  rootDir     = ${rootDir}"


#
# If the test delay was specified, sleep for a bit
#
if ($testDelay -ne "0")
{
    "Sleeping for ${testDelay} seconds"
    Start-Sleep -S $testDelay
}


UpdateVmTimezoneBasedOnHost -sshKey "ssh\${sshKey}" -ipv4 $ipv4

$i = 0
$totalTimes = 3
do{
	$i += 1
	#
	# Get a time string from the VM, then convert the Unix time string into a .NET DateTime object
	#
	"Get time from Unix VM"
	$unixTimeStr = GetUnixVMTime -sshKey "ssh\${sshKey}" -ipv4 $ipv4
	if (-not $unixTimeStr)
	{
		"Error: Unable to get date/time string from VM" >> $summaryLog
		return $False
	}

	#
	# Get our time
	#
	$windowsTime = [DateTime]::Now

	#
	# Convert the Unix tiime string into a DateTime object
	#
	$unixTime = [DateTime]::Parse($unixTimeStr)

	#
	# Compute the timespan, then convert it to the absolute value of the total difference in seconds
	#
	"Compute time difference between localhost and Linux VM"
	$diffInSeconds = $null
	$timeSpan = $windowsTime - $unixTime
	if (-not $timeSpan)
	{
		"Error: Unable to compute timespan"  >> $summaryLog
		return $False
	}

	$diffInSeconds = [Math]::Abs($timeSpan.TotalSeconds)

	#
	# Display the data
	#
	"Windows time: $($windowsTime.ToString())" >> $summaryLog
	"Unix time: $($unixTime.ToString())"  >> $summaryLog
	"Difference: ${diffInSeconds}"  >> $summaryLog

	if ($diffInSeconds -and $diffInSeconds -lt $maxTimeDiff)
	{
		$msg = "Test case passed at ${i}/${totalTimes}."
		$msg
		$msg >> $summaryLog
		$retVal = $true
	}
	else
	{
		$msg = "Test case FAILED. Time difference is greater than ${maxTimeDiff} seconds."
		$msg
		$msg >> $summaryLog
		$retVal = $False
		break
	}
	
	sleep 10
	
}while( $i -lt $totalTimes)

return $retVal
