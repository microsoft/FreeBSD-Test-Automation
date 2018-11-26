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
    This script tests keyboard functionality.

.Description
    The .xml entry for this script could look like either of the following:
    A typical XML definition for this test case would look similar to the following:
        <test>
            <testName>Hyperv_keyboard_vim</testName>
			<testScript>setupscripts\HVKBD_vim_input.ps1</testScript> 
            <testparams>
                <param>TC_COVERED=PERF-TTCP-01</param>
            </testparams>
			<timeout>10800</timeout>
            <OnError>Continue</OnError>
        </test>

.Parameter vmName
    Name of the VM to remove disk from .

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    setupScripts\HVKBD_vim_input.ps1 -hvServer localhost -vmName NameOfVm -testParams 'sshKey=path/to/ssh;rootdir=path/to/testdir;ipv4=ipaddress;'

#>

param([string] $vmName, [string] $hvServer, [string] $testParams)


#######################################################################
# Delete a file on the VM. 
#######################################################################
function DeleteFile()
{
    .\bin\plink -i ssh\${sshKey} root@${ipv4} "rm -rf /tmp/t"
    if (-not $?)
    {
        Write-Error -Message "ERROR: Unable to delete file" -ErrorAction SilentlyContinue
        return $False
    }
   
    return  $True 
}

####################################
# Get the keyboard for specified VM
####################################
function getKeyboard($vmName)
{
    $filt = "elementname='$vmName'"
    $cs = gwmi -computername "." -Namespace root\virtualization\v2 -class Msvm_computersystem -filter $filt
    $path = ${cs}.path.path
    $query2 = "ASSOCIATORS OF {$path} WHERE resultClass = Msvm_Keyboard"
    $Keyboard = gwmi -computerName "." -Namespace "root\virtualization\v2" -Query $query2
    return $Keyboard
}

####################################
# Send key code to VM. For keycode, see https://msdn.microsoft.com/en-us/library/dd375731(v=vs.85).aspx
####################################
function sendKey($vmName, [int]$keyNum)
{
    $Keyboard = getKeyboard $vmName
    $Keyboard.InvokeMethod("TypeKey", $keyNum) # Press enter
}

####################################
# Send scan code to VM, for scancode, see https://msdn.microsoft.com/en-us/library/aa299374(v=vs.60)
####################################
function sendScancodes($vmName, [byte[]]$keys)
{
    $Keyboard = getKeyboard $vmName
    $Keyboard.TypeScanCodes($keys) # Press enter
}

function createUser()
{
   # recreate login user every time or use existing one? now we reuse the existing one.
   #echo y|.\bin\plink -i ssh\${sshKey} root@${ipv4} "pw user show hvkbd && pw user del -r -n hvkbd"
   #echo y|.\bin\plink -i ssh\${sshKey} root@${ipv4} "pw useradd -s tcsh -m -n hvkbd && echo "123" | pw usermod hvkbd -h 0"
   echo y|.\bin\plink -i ssh\${sshKey} root@${ipv4} "pw user show hvkbd || pw useradd -s tcsh -m -n hvkbd && echo "123" | pw usermod hvkbd -h 0"
}

function login($vmName)
{
   # send 'hvkbd' as user
   sendKey $vmName 0x48
   sendKey $vmName 0x56
   sendKey $vmName 0x4B
   sendKey $vmName 0x42
   sendKey $vmName 0x44
   sendKey $vmName 0x0D
   # send '123' as passwd
   sendKey $vmName 0x31
   sendKey $vmName 0x32
   sendKey $vmName 0x33
   sendKey $vmName 0x0D
   # send 'cd /tmp'
   sendKey $vmName 0x43
   sendKey $vmName 0x44
   sendKey $vmName 0x20
   sendKey $vmName 0xBF
   sendKey $vmName 0x54
   sendKey $vmName 0x4D
   sendKey $vmName 0x50
   sendKey $vmName 0x0D
}

###################################
# simulate edit on a file through VIM
###################################
function simulateVI($vmName)
{
   # send 'vim t' to open file
   sendKey $vmName 0x56
   sendKey $vmName 0x49
   sendKey $vmName 0x4D
   sendKey $vmName 0x20
   sendKey $vmName 0x54
   sendKey $vmName 0x0D
   # send 'insert' 
   sendKey $vmName 0x2D
   # send '0123456789' as input
   $i = 0x30
   do {
     sendKey $vmName $i
     $i = $i + 1
   } while ($i -le 0x39)
   sendKey $vmName 0x0D # <== enter

   #send 'abcdefghijklmnopqrstuvwxyz'
   $i = 0x41
   do {
     sendKey $vmName $i
     $i = $i + 1
   } while ($i -le 0x5A)
   sendKey $vmName 0x0D # <== enter

   # send 'ASDFGHJKL:"~'
   $i = 30
   do {
     sendScancodes $vmName @([byte]42,[byte]$i)
     $i = $i + 1
   } while ($i -le 41)
   sendKey $vmName 0x0D # <== enter
   
   # send ':"~!@#$%^&*()_+'
   $i = 2
   do {
     sendScancodes $vmName @([byte]42,[byte]$i)
     $i = $i + 1
   } while ($i -le 13)
   sendKey $vmName 0x0D # <== enter

   # send 'QQWWEERRTTYYUUIIOOPP{{}}'
   $j = 0
   $i = 16
   do {
     sendScancodes $vmName @([byte]$i)
     sendScancodes $vmName @([byte]$i)
     $i = $i + 1
     $j = $j + 1
   } while ($i -le 27)
   
   sendKey $vmName 0x24 # send 'home'
   # remove the duplication
   $i = 0
   do {
      sendKey $vmName 0x27 # send '->'
      sendKey $vmName 0x2E # send 'del'
      $i = $i + 1
   } while ($i -lt $j)

   sendKey $vmName 0x26 # send 'up arrow'
   sendKey $vmName 0x24 # send 'home'
   # send ';', '->', ''', '->', '`'
   sendScancodes $vmName @(39,77,40,77,41)

   sendKey $vmName 0x27 # send '->'
   sendKey $vmName 0xBB
   
   # send 'ESC'
   sendScancodes $vmName @([byte]1)
   # send ':'
   sendScancodes $vmName @([byte]42,[byte]39)
   # send 'x' after ':' will encounter a bug: 'x' is sent as 'X'
   # the workaround is to delete 'X' and type another 'x' with
   # capslock is on
   sendKey $vmName 0xA0 # <== left 'shift'
   sendKey $vmName 0x58 # <== 'x'
   sendKey $vmName 0x0D # <== enter
}

####################################################################### 
# 
# Main script body 
# 
#######################################################################
$retVal = $false


# Check input arguments
if ($vmName -eq $null)
{
    "ERROR: VM name is null"
    return $retVal
}

# Check input params
$params = $testParams.Split(";")

foreach ($p in $params)
{
  $fields = $p.Split("=")
    
  switch ($fields[0].Trim())
    {
    "sshKey" { $sshKey = $fields[1].Trim() }
    "ipv4" { $ipv4 = $fields[1].Trim() }
    "rootdir" { $rootDir = $fields[1].Trim() }
     default  {}          
    }
}

if ($null -eq $sshKey)
{
    "ERROR: Test parameter sshKey was not specified"
    return $False
}

if ($null -eq $ipv4)
{
    "ERROR: Test parameter ipv4 was not specified"
    return $False
}

if ($null -eq $rootdir)
{
    "ERROR: Test parameter rootdir was not specified"
    return $False
}

echo $params

# Change the working directory to where we need to be
cd $rootDir

# Define and cleanup the summaryLog
$summaryLog  = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "HV synthetic keyboard test" | Out-File $summaryLog


# Source the TCUtils.ps1 file
. .\setupscripts\TCUtils.ps1

# Check if the Vm VHD in not on the same drive as the backup destination 
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if (-not $vm)
{
    "Error: VM '${vmName}' does not exist"
    return $False
}

# create the login user if it does not exist
createUser

# remove the file if it existed
DeleteFile

login $vmName

simulateVI $vmName

GetFileFromVM $ipv4 $sshKey '/tmp/t' t 

$ref = get-content .\setupscripts\hvkbd.ref

$result = get-content t
if ("$ref" -eq "$result") {
    Write-Output "Keyboard test successfully" | Out-File -Append $summaryLog
    return $True
} else {
	Write-Output "Keyboard test failed" | Out-File -Append $summaryLog
	Write-Output "The content expected is: " | Out-File -Append $summaryLog
	Write-Output "$ref" | Out-File -Append $summaryLog
	Write-Output "But, the content is: " | Out-File -Append $summaryLog
	Write-Output "$result" | Out-File -Append $summaryLog
    return $False
}

