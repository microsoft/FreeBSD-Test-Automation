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
    Modify the capacity of memory a VM has.

.Descriptioin
    Modify the capacity of memory the VM has.

.Parameter vmName
    Name of the VM to modify.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    A semicolon separated list of test parameters.

.Example
    .\ChangeMemory "testVM" "localhost" "VMEM=2GB;rootDir=D:\lisa"
or
	.\ChangeMemory "testVM" "localhost" "VMEM=512MB;rootDir=D:\lisa"
.Note
    The unit must be "MB" or "GB", others such as mb, gb, m, kb, and so on doesn't work
#>


param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $false
$min_mem = 8MB

#
# Check input arguments
#
if ($vmName -eq $null)
{
    "Error: VM name is null"
    return $retVal
}

if ($hvServer -eq $null)
{
    "Error: hvServer is null"
    return $retVal
}

if ($testParams -eq $null -or $testParams.Length -lt 3)
{
    "Error: No testParams provided"
    "       The script $MyInvocation.InvocationName requires the VMEM test parameter"
    return $retVal
}

#
# for debugging - to be removed
#
"ChangeMemory.ps1 -vmName $vmName -hvServer $hvServer -testParams $testParams"

#
# Find the testParams we require.  Complain if not found
#

$memory_capacity = 0

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    
    if ($fields[0].Trim() -eq "VMEM")
    {
        $memory_capacity = $fields[1].Trim()
        break
    }
}

	
if ($memory_capacity.EndsWith("GB"))
{
	$tmp=$memory_capacity.trim().split("GB")[0]	
	#Casting from string to int
	$tmp_number = [int] $tmp
	
	#Change GB to MB
	$memory = $tmp_number * 1024MB
} elseif ($memory_capacity.EndsWith("MB"))
{
	$tmp=$memory_capacity.trim().split("MB")[0]	
	#Casting from string to int
	$tmp_number = [int] $tmp
	$memory = $tmp_number * 1MB	
} else {
	"Error: VMEM test parameter is wrong in testParams"
}



#
# do a sanity check on the value provided in the testParams
#

$max_mem=(get-wmiobject -computername $hvServer Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum/1mb

if ($memory -gt $max_mem)
{
    "Error: Incorrect memory value: $memory (max memory = $max_mem)"
    # return $retVal
}

if ($memory -lt $min_mem)
{
    "Error: Incorrect memory value: $memory (min memory = $min_mem)"
    # return $retVal
}

#
# HyperVLib version 2
# Note: For V2, the module can only be imported once into powershell.
#       If you import it a second time, the Hyper-V library function
#       calls fail.
#
<#$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\Hyperv.psd1
}#>

#
# Update the memory on the VM
#

$mem = Set-VM -Name $vmName -ComputerName $hvServer -MemoryStartupBytes $memory

if ($? -eq "True")
{
    write-host "memory updated to $memory"
    $retVal = $true
}
else
{
    write-host "Error: Unable to update memory"
}

return $retVal
