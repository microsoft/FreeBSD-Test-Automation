########################################################################
#
# FreeBSD on Hyper-V Test Code, ver. 1.0.0
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
    Stop the kvp daemon inside the FreeBSD VM, verify kvp doesn't work. Then start the kvp daemon inside the FreeBSD VM, verify kvp works.

.Description
    Stop the kvp daemon inside the FreeBSD VM, verify kvp doesn't work. Then start the kvp daemon inside the FreeBSD VM, verify kvp works by reading the IP address of the VM from host.

    A typical XML definition for this test case would look similar
    to the following:
        <test>
            <testName>StopStartKvpDaemon</testName>
            <testScript>setupscripts\BIS_StopStartKvpDaemon.ps1</testScript>
            <timeout>600</timeout>
            <onError>Abort</onError>
            <noReboot>False</noReboot>
            <testparams>
                 <param>TC_COVERED=KVP-12</param>
                 <param>sshKey=lisa_id_rsa.ppk</param>
            </testparams>
        </test>	

.Parameter vmName
    Name of the VM.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    setupScripts\BIS_StopStartKvpDaemon.ps1 -vmName "myVm" -hvServer "localhost" -TestParams "sshKey=rhel5_id_rsa.ppk"

.Link
    None.
#>


param( [String] $vmName, [String] $hvServer, [String] $testParams )

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
    "sshKey"     { $sshKey    = $fields[1].Trim() }
    default      {}       
    }
}

if (-not $rootDir)
{
    "Error: no rootdir was specified"
    return $False
}

if (-not (Test-Path $rootDir))
{
    "Error: The rootDir directory '${rootDir}' does not exist"
    return $False
}

cd $rootDir

$summaryLog  = "${vmName}_summary.log"
Del $summaryLog -ErrorAction SilentlyContinue
echo "Covers : ${tcCovered}" >> $summaryLog


#
# Source the TCUtils.ps1 file so we have access to the 
# functions it provides.
#
. .\setupScripts\TCUtils.ps1 | out-null


#
# Determine the test VMs IP address
#
"Info : Determining the IPv4 address of the VM"

$ipv4 = GetIPv4 $vmName $hvServer
if (-not $ipv4)
{
    "Error: Unable to determine IPv4 address of VM '${vmName}'"
    return $False
}

#
# Stop the KVP daemon in the VM
#
"Info : killall hv_kvp_daemon"
$cmd = "killall hv_kvp_daemon"
if (-not (SendCommandToVM $ipv4 $sshKey "${cmd}" ))
{
    "Error: Unable to stop the KVP daemon"
    return $False
}

"Sleep 20 seconds for updating the status of kvp daemon"
sleep 20

#
# Try to read the IP addresses from the network adapters object in the
# VM object. Make sure nothing can be read.
#
"Info : Creating VM object for vm ${vmName}"
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if (-not $vm)
{
    "Error: Unable to create a VM object for vm ${vmName}"
    return $False
}

"Info : Getting network adapters object"
$nics = @($vm.NetworkAdapters)
if (-not $nics)
{
    "Error: VM '${vmName}' does not have any Network Adapters"
    return $False
}

"Info : Reading IP addresses from network adapter 0"
$ipAddr = $nics[0].IpAddresses
if ($ipAddr)
{
    "Error: KVP is still working after deamon is stopped."
    return $False
}

#
# Start the KVP daemon in the VM
#
"Info : Restart KVP daemon under /usr/sbin/hv_kvp_daemon "
$cmd = "/usr/sbin/hv_kvp_daemon"
if (-not (SendCommandToVM $ipv4 $sshKey "${cmd}" ))
{
    "Error: Unable to start the KVP daemon"
    return $False
}

"Sleep 20 seconds for updating the status of kvp daemon"
sleep 20

#
# Read the IP addresses from the network adapters object in the
# VM object.
#
"Info : Creating VM object for vm ${vmName}"
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if (-not $vm)
{
    "Error: Unable to create a VM object for vm ${vmName}"
    return $False
}

"Info : Getting network adapters object"
$nics = @($vm.NetworkAdapters)
if (-not $nics)
{
    "Error: VM '${vmName}' does not have any Network Adapters"
    return $False
}

"Info : Reading IP addresses from network adapter 0"
$ipAddr = $nics[0].IpAddresses
if (-not $ipAddr)
{
    "Error: KVP is not working after deamon is started."
    return $False
}

return $True

