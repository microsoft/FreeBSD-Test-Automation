############################################################################
#
# TestExportImport.ps1
#
# Description:
#     This is a PowerShell test case script that runs on the on
#     the ICA host rather than the VM.
#
#     This script exports the VM, Imports it back, verifies that the imported VM has the snapshots also. 
#      Finally it deletes the imported VM.
#     
#
#     The ICA scripts will always pass the vmName, hvServer, and a
#     string of testParams to the PowerShell test case script. For
#     example, if the <testParams> section was written as:
#
#         <testParams>
#             <param>TestCaseTimeout=300</param>
#         </testParams>
#
#     The string passed in the testParams variable to the PowerShell
#     test case script script would be:
#
#         "TestCaseTimeout=300"
#
#     The PowerShell test case scripts need to parse the testParam
#     string to find any parameters it needs.
#
#     All setup and cleanup scripts must return a boolean ($true or $false)
#     to indicate if the script completed successfully or not.
#
############################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)


function CheckCurrentStateFor([String] $vmName, $newState)
{
    $stateChanged = $False
    
    $vm = Get-VM -Name $vmName -ComputerName $hvServer
    
    if ($($vm.State) -eq $newState)
    {
        $stateChanged = $True
    }
    
    return $stateChanged
}



#####################################################################
#
# TestPort
#
#####################################################################
function TestPort ([String] $serverName, [Int] $port=22, [Int] $to=3)
{
    $retVal = $False
    $timeout = $to * 1000
  
    #
    # Try an async connect to the specified machine/port
    #
    $tcpclient = new-Object system.Net.Sockets.TcpClient
    $iar = $tcpclient.BeginConnect($serverName,$port,$null,$null)
    
    #
    # Wait for the connect to complete. Also set a timeout
    # so we don't wait all day
    #
    $connected = $iar.AsyncWaitHandle.WaitOne($timeout,$false)
    
    # Check to see if the connection is done
    if($connected)
    {
        #
        # Close our connection
        #
        try
        {
            $sts = $tcpclient.EndConnect($iar) | out-Null
            $retVal = $true
        }
        catch
        {
            # Nothing we need to do...
        }

        #if($sts)
        #{
        #    $retVal = $true
        #}
    }
    $tcpclient.Close()

    return $retVal
}


#####################################################################
#
# Main script body
#
#####################################################################

$retVal = $False

"TestExportImport.ps1"
"VM Name   = ${vmName}"
"HV Server = ${hvServer}"
"TestParams= ${testParams}"
#
# Check input arguments
#
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

#
# Parse the testParams string
#
$rootDir = $null
$vmIPAddr = $null

$params = $testParams.Split(';')
foreach ($p in $params)
{
    if ($p.Trim().Length -eq 0)
    {
        continue
    }

    $tokens = $p.Trim().Split('=')
    
    if ($tokens.Length -ne 2)
    {
	"Warn : test parameter '$p' is being ignored because it appears to be malformed"
     continue
    }
    
    if ($tokens[0].Trim() -eq "RootDir")
    {
        $rootDir = $tokens[1].Trim()
    }
    
    if ($tokens[0].Trim() -eq "ipv4")
    {
        $vmIPAddr = $tokens[1].Trim()
    }
}

if ($rootDir -eq $null)
{
    "Error: The RootDir test parameter is not defined."
    return $False
}

if ($vmIPAddr -eq $null)
{
    "Error: The ipv4 test parameter is not defined."
    return $False
}

cd $rootDir

#
#
#
$summaryLog  = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "Covers TC92" | Out-File $summaryLog

#
# Set the test case timeout to 10 minutes
#
$testCaseTimeout = 600

#
# Load the PowerShell HyperV Library
#
<#$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\HyperV.psd1
}#>

#
# Check that the VM is present on the server and it is in running state.
#
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if (-not $vm)
{
    "Error: Cannot find VM ${vmName} on server ${hvServer}"
    Write-Output "VM ${vmName} not found" | Out-File -Append $summaryLog
    return $False
}

if ($($vm.State) -ne "Running")
{
    "Error: VM ${vmName} is not in the running state"
    Write-Output "The Invoke-Shutdown was not sent" | Out-File -Append $summaryLog
    return $False
}

#
# While checking for VM startup Wait for TCP port 22 to be available on the VM
#

while ($testCaseTimeout -gt 0)
{

    if ( (TestPort $vmIPAddr) )
    {
        break
    }
     
    Start-Sleep -seconds 2
    $testCaseTimeout -= 2
}

if ($testCaseTimeout -eq 0)
{
    Write-Output "Error: Test case timed out for VM to go to Running" | Out-File -Append $summaryLog
    return $False
}

Write-Output "VM ${vmName} is present on server and running" 

#
# Stop the VM to export it. 
#

while ($testCaseTimeout -gt 0)
{
    #stop-VM -VM $vmName -Server $hvServer -Wait -Force -Verbose
    Stop-VM -Name $vmName -ComputerName $hvServer -Force -Verbose
        
    if ( (CheckCurrentStateFor $vmName ("Off")))
    {
        break
    }   

    Start-Sleep -seconds 2
    $testCaseTimeout -= 2
}


if ($testCaseTimeout -eq 0)
{
    Write-Output "Error: Test case timed out waiting for VM to stop" | Out-File -Append $summaryLog
    return $False
}

Write-Output "VM ${vmName} is stopped successfully" 

#
# Delete Export directory if it is exists
#
Remove-Item -Path "${rootDir}\${VmName}" -Recurse -Force -ErrorAction SilentlyContinue

#
# Create a Snapshot before exporting the VM
#

#New-VMSnapshot -VM $vmName -Server $hvServer -Wait -Force | Rename-VMSnapshot -NewName "TestExport" -Force
Checkpoint-VM -Name $vmName -ComputerName $hvServer -SnapshotName "TestExport" -Confirm:$False
if ($? -ne "True")
{
    Write-Output "Error while creating the snapshot" | Out-File -Append $summaryLog
    return $false
}

Write-Output "Successfully created a new snapshot before exporting the VM" 

#
# export the VM.
#

#HyperV\Export-VM -VM $vmName -Server $hvServer -Path $rootDir  -wait -CopyState -Verbose
Export-VM -Name $vmName -ComputerName $hvServer -Path $rootDir -Confirm:$False -Verbose
if ($? -ne "True")
{
    Write-Output "Error while exporting the VM" | Out-File -Append $summaryLog
    return $false
}

Write-Output "VM ${vmName} exported successfully"  

#
# Before importing the VM from exported folder, Delete the created snapshot from the orignal VM.
#

#Get-VMSnapshot -VM $vmName -Server $hvServer -Name "TestExport" | Remove-VMSnapshot -Force
Get-VMSnapshot -VMName $vmName -ComputerName $hvServer -Name "TestExport" | Remove-VMSnapshot -Confirm:$False

#
# Save the GUID of exported VM.
#

$ExportedVM = Get-VM -Name $vmName -ComputerName $hvServer

$ExportedVMID = $ExportedVM.VMId

#
# Import back the above exported VM.
#

$vmConfig = Get-Item "${rootDir}\$vmName\Virtual Machines\*.xml"

#HyperV\Import-VM -Paths ${rootDir}\${vmName} -Server $hvServer -ReimportVM $vmName  -Force -wait -Verbose | Out-Null
Import-VM -Path $vmConfig -ComputerName $hvServer -VhdDestinationPath "${rootDir}\${vmName}" -VirtualMachinePath "${rootDir}\${vmName}" -Copy -GenerateNewId -Verbose -Confirm:$False
if ($? -ne "True")
{
    Write-Output "Error while importing the VM" | Out-File -Append $summaryLog
    return $false
}

Write-Output "VM ${vmName} is imported back successfully"  

#
# Check that the imported VM has a snapshot 'TestExport', apply the snapshot and start the VM.
#

$VMs = Get-VM -Name $vmName -ComputerName localhost

#$VMIDs = $VMs.VMId

<#$b = $VMIDs.Count

$a = 0
while ($a -lt $b)
{
 if ($ExportedVMID -ne $VMIDs[$a])
 {
    $ImportedVM = $VMs[$a]
    break
 }
 $a++
}#>
$newName = "Imported_VM"

foreach ($Vm in $VMs)
{  
   if ($ExportedVMID -ne $($Vm.VMId))
   {
       $ImportedVM = $Vm.VMId
       Get-VM -Id $Vm.VMId | Rename-VM -NewName $newName
       break
   }
}


#Get-VMSnapshot -Server $hvServer -vm  $ImportedVM -Name "TestExport" | Restore-VMSnapshot -Force -Verbose
Get-VMSnapshot -VMName $newName -ComputerName $hvServer -Name "TestExport" | Restore-VMSnapshot -Confirm:$False -Verbose
if ($? -ne "True")
{
    Write-Output "Error while applying the snapshot to imported VM $ImportedVM" | Out-File -Append $summaryLog
    return $false
}

Start-VM $newName

Start-Sleep -Seconds 100

#
# Verify that the imported VM has started successfully
#

<#while ($testCaseTimeout -gt 0)
{  
   $IS = Get-VMIntegrationService -VMName $newName -ComputerName $hvServer -Name "Heartbeat"
   if ($($IS.PrimaryOperationalStatus) -eq "OK")
    {
        break
    }
    Start-Sleep -seconds 2
    $testCaseTimeout -= 2
}#>
while ($testCaseTimeout -gt 0)
{
    $VMN = Get-VMNetworkAdapter -VMName $newName -ComputerName $hvServer
    $NewvmIPAddr = $($VMN.IPAddresses)
    if ( (TestPort $NewvmIPAddr) )
    {
        break
    }
     
    Start-Sleep -seconds 2
    $testCaseTimeout -= 2
}

if ($testCaseTimeout -eq 0)
{
    Write-Output "Error: Test case timed out waiting for Imported VM to reboot" | Out-File -Append $summaryLog
    return $False
}

Write-Output "Imported VM ${vmName} has a snapshot TestExport, applied the snapshot and VM started successfully" 

#
# Cleanup - stop the imported VM, remove it and delete the export folder. 
# 
#Stop-VM $ImportedVM -Wait -force -Verbose
Stop-VM -Name $newName -ComputerName $hvServer -Force -Verbose
if ($? -ne "True")
{
    Write-Output "Error while stopping the VM" | Out-File -Append $summaryLog
    return $false
}

Write-Output "VM exported with a new snapshot and imported back successfully" | Out-File -Append $summaryLog
   
#Remove-VM $ImportedVM -wait -Force -Verbose
Remove-VM -Name $newName -ComputerName $hvServer -Force -Verbose
if ($? -ne "True")
{
    Write-Output "Error while removing the Imported VM" | Out-File -Append $summaryLog
    return $false
}
else
{
    Write-Output "Imported VM Removed, test completed" | Out-File -Append $summaryLog
    $retVal = $True
}
  
Remove-Item -Path "${rootDir}\${VmName}" -Recurse -Force
if ($? -ne "True")
{
    Write-Output "Error while deleting the export folder trying again"
    del -Recurse -Path "${rootDir}\${VmName}" -Force
}
   
#Write-Output "Imported VM ${vmName} is stopped and deleted successfully" 

return $retVal