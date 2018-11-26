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
    Verify the KVP GET operation works
.Description
    Verify the KVP GET operation works.  This operation is used
    to populate the IP address into a VMs NetworkAdapter object.

    A typical test case definition for this test script would look
    similar to the following:
        <test>
            <testName>KVP_TestGET</testName>
            <testScript>SetupScripts\KVP_TestKvpGET.ps1</testScript>
            <timeout>600</timeout>
            <onError>Continue</onError>
            <noReboot>True</noReboot>
            <testparams>
                <param>rootDir=D:\lisa\trunk\lisablue</param>
                <param>TC_COVERED=KVP-06</param>
            </testparams>
        </test>
.Parameter vmName
    Name of the VM to test.
.Parameter hvServer
    Name of the Hyper-V server hosting the VM.
.Parameter testParams
    Test data for this test case
.Example
    setupScripts\Kvp_TestKvpGET.ps1 -vmName "myVm" -hvServer "localhost -TestParams "rootDir=c:\lisa\trunk\lisa;TC_COVERED=KVP-06"
.Link
    None.
#>



param( [String] $vmName,
       [String] $hvServer,
       [String] $testParams
)


#######################################################################
#
# Main script body
#
#######################################################################

#
# Make sure the required arguments were passed
#
if (-not $vmName)
{
    "Error: no VMName was specified"
    return $False
}

if (-not $hvServer)
{
    "Error: No hvServer was specified"
    return $False
}

if (-not $testParams)
{
    "Error: No test parameters specified"
    return $False
}

#
# Parse the test parameters
#
$rootDir = $null
$tcCovered = "Undefined"

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {      
    "rootdir"    { $rootDir   = $fields[1].Trim() }
    "TC_COVERED" { $tcCovered = $fields[1].Trim() }
    default      {}       
    }
}

if (-not $rootDir)
{
    "Error: No rootdir was specified"
    return $False
}

if (-not (Test-Path $rootDir))
{
    "Error: The rootDir directory '${rootDir}' does not exist"
    return $False
}

cd $rootDir
Import-module  ${rootDir}\HyperVLibV2Sp1\Hyperv.psd1 | out-null

$summaryLog  = "${vmName}_summary.log"
Del $summaryLog -ErrorAction SilentlyContinue
echo "Covers : ${tcCovered}" >> $summaryLog

#
# Debug - display the test parameters so they are captured in the log file
#
"TestParams : '${testParams}'"

#
# Source the utilFunctions.ps1 file so we have access to the functions it provides.
#
. .\utilFunctions.ps1 | out-null

#
# Read the IP addresses via KVP.  
# This is populated with the KVP GET operation.
#
"Info :Reading IP addresses via KVP"
$ipAddr = GetIPv4  $vmName $hvServer
if (-not $ipAddr)
{
    "Error: IP address cannot be read"
    return $False
}

"Info: The IPv4 is $ipAddr"

return $True



