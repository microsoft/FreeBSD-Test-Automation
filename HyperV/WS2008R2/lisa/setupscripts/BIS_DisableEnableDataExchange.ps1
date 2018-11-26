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
    Disable the Data Exchange service, verify the KVP GET opeartion doesn't work. Then enable the Data Exchange service, add a KVP to the VM, and verify from the VM.
.Description
	Disable the Data Exchange service, then verify the KVP GET
	opeartion doesn't work by reading IP address from the VM and 
	ensure nothing is read. Then enable the Data Exchange service, add
	a KVP to the VM, and verify from the VM.

.Parameter vmName
    Name of the VM.
.Parameter hvServer
    Name of the Hyper-V server hosting the VM.
.Parameter testParams
    Test data for this test case
.Example
    setupScripts\BIS_DisableEnableDataExchange.ps1 -vmName "myVm" -hvServer "localhost -TestParams "rootDir=c:\lisa\trunk\lisa;TC_COVERED=KVP-01"
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
# Debug - display the test parameters so they are captured in the log file
#
Write-Output "TestParams : '${testParams}'"

$summaryLog  = "${vmName}_summary.log"
Del $summaryLog -ErrorAction SilentlyContinue    

#
# Find the testParams we require. Complain if not found.
#
$Key = $null
$Value = $null
$rootDir = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    
    if ($fields[0].Trim() -eq "Key")
    {
        $Key = $fields[1].Trim()
    }
    if ($fields[0].Trim() -eq "Value")
    {
        $Value = $fields[1].Trim()
    }
     if ($fields[0].Trim() -eq "RootDir")
    {
        $rootDir = $fields[1].Trim()
    }
            
}

if (-not $Key)
{
    "Error: Missing testParam Key to be added"
    return $False
}
if (-not $Value)
{
    "Error: Missing testParam Value to be added"
    return $False
}

if (-not $rootDir)
{
    "Error : No rootDir test parameter was provided"
}
else
{
	cd $rootDir
	Import-module  ${rootDir}\HyperVLibV2Sp1\Hyperv.psd1  | out-null
}

echo "Covers : ${tcCovered}" >> $summaryLog

#
# Disable the Data Exchange Service
#
$des  = Get-VMIntegrationComponent  -VM $vmName  -Server $hvServer
if (-not $des)
{
    "Error: Unable to retrieve Integration Service status from VM '${vmName}' "
    return $False
}

$serviceEnabled = Get-VMIntegrationComponent  -VM $vmName  -Server $hvServer | Where-Object {$_.description -like  "Microsoft Key-Value Pair*"}  | Where-Object {$_.enabledstate -eq [VMstate]::Running} 
if( $serviceEnabled )
{
	Set-VMIntegrationComponent -VM $vmName -ComponentName  'Key-Value Pair Exchange' | out-null
	sleep 1
}

$serviceEnabled = Get-VMIntegrationComponent  -VM $vmName  -Server $hvServer | Where-Object {$_.description -like  "Microsoft Key-Value Pair*"}  | Where-Object {$_.enabledstate -eq [VMstate]::Running} 
if( $serviceEnabled )
{
	"Error: The Data Exchange Service is not disabled for VM '${vmName}'"
    return $False
}

"Info: The Data Exchange service has been disabled"

#
# Source the TCUtils.ps1 file so we have access to the functions it provides.
#
. .\setupScripts\TCUtils.ps1 | out-null

#
# Try to read the IP addresses via KVP. Make sure nothing can be read.
#
"Info : Reading IP addresses via KVP"
$ipAddr = GetIPv4ViaKVP  $vmName $hvServer
if ($ipAddr)
{
	"Info: The IP address is $ipAddr"
    "Error: The Data Exchange service is still working after it is disabled."
    return $False
}

#
# Re-enable the Data Exchange Service
#
Set-VMIntegrationComponent -VM $vmName -ComponentName  'Key-Value Pair Exchange'  | out-null

sleep 1

$serviceEnabled = Get-VMIntegrationComponent  -VM $vmName  -Server $hvServer | Where-Object {$_.description -like  "Microsoft Key-Value Pair*"}  | Where-Object {$_.enabledstate -eq [VMstate]::Running} 
if(-not $serviceEnabled )
{
    "Error: The Data Exchange Service is not enabled for VM '${vmName}'"
    return $False
}

"Info: The Data Exchange service has been re-enabled"

write-output "Info : Adding Key=value of: ${key}=${value}"

#
# Add the Key Value pair to the Pool 0 on guest OS.
#
$VMManagementService = Get-WmiObject -class "Msvm_VirtualSystemManagementService" -namespace "root\virtualization" -ComputerName $hvServer
if (-not $VMManagementService)
{
    "Error: Unable to create a VMManagementService object"
    return $False
}

$VMGuest = Get-WmiObject -Namespace root\virtualization -ComputerName $hvServer -Query "Select * From Msvm_ComputerSystem Where ElementName='$VmName'"
if (-not $VMGuest)
{
    "Error: Unable to create VMGuest object"
    return $False
}

$Msvm_KvpExchangeDataItemPath = "\\$hvServer\root\virtualization:Msvm_KvpExchangeDataItem"
$Msvm_KvpExchangeDataItem = ([WmiClass]$Msvm_KvpExchangeDataItemPath).CreateInstance()
if (-not $Msvm_KvpExchangeDataItem)
{
    "Error: Unable to create Msvm_KvpExchangeDataItem object"
    return $False
}

#
# Populate the Msvm_KvpExchangeDataItem object
#
$Msvm_KvpExchangeDataItem.Source = 0
$Msvm_KvpExchangeDataItem.Name = $Key
$Msvm_KvpExchangeDataItem.Data = $Value

#
# Set the KVP value on the guest
#
$result = $VMManagementService.AddKvpItems($VMGuest, $Msvm_KvpExchangeDataItem.PSBase.GetText(1))
$job = [wmi]$result.Job

while($job.jobstate -lt 7) {
	$job.get()
} 

if ($job.ErrorCode -ne 0)
{
    "Error: Unable to add KVP value to guest"  
    "       error code $($job.ErrorCode)"
    return $False
}

if ($job.Status -ne "OK")
{
    "Error: KVP add job did not complete with status OK"
    return $False
}

"Info : KVP item added successfully on guest" 
 
return $True


