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
.synopsis
    Insert a ISO DVD to a VM.

.Description
    Insert a ISO DVD to a VM. The ISO file must be placed under test category folder (such as TestData\KVP-Test.xml\).
	
.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the Hyper-V server hosting the test VM.

.Parameter testParams
    Test parameters are a way of passing variables into the test case script.

.Example:
    .\setupscripts\Insert-ISO.ps1 SLES11SP3X64 localhost "TC_COVERED=PERF-WCAT;TARGET_IP=192.168.1.10;SCENARIO_FILE=static.cold.ubr;SETTINGS_FILE=wcat.settings.ubr;CONFIG_APACHE_SCRIPT=perf_ubuntuconfigapache.sh;TEST_CONTENT_DIR=.\TestData\Perf_wcat.xml;WORKLOAD_CLIENT=localhost;WF_PROXY_ZIP=wfproxy.zip;APACHE_PACKAGE=apache2;rootDir=E:\lisablue\WS2012R2\lisa;TestLogDir=C:\lisa\TestResults\Perf_Wcat-20140417-112654;TestName=Perf_Wcat;scriptMode=TestCase;ipv4=192.168.1.10;sshKey=rhel5_id_rsa.ppk;ISO_NAME=SLES.iso;"
#>


param( [String] $vmName, [String] $hvServer, [String] $testParams )

#display and return params to caller script
$vmName
$hvServer
$testParams

#defined variables used
$rootDir = $null
$TEST_CONTENT_DIR = $null
$ISO_NAME = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {      
    "rootdir"              { $rootDir           = $fields[1].Trim() }
    "TEST_CONTENT_DIR"     { $TEST_CONTENT_DIR  = $fields[1].Trim() }
    "ISO_NAME"             { $ISO_NAME          = $fields[1].Trim() }
    default                {}       
    }
}

if (-not $ISO_NAME)
{
    "ERROR: ISO_NAME is null. No ISO is defined in the XML."
    return $False
}

$ISO_PATH = "$rootDir\$TEST_CONTENT_DIR\$ISO_NAME"

Set-VMDvdDrive -VMName $vmName -Path $ISO_PATH

return $true