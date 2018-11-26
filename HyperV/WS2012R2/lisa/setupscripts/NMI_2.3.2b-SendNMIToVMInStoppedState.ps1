#######################################################################
# NMI_2.3.2b-SendNMIToVMInStoppedState.ps1
#
# Description:
# This powershell automates the TC-2.3.1 - sending NMI (Non-Maskable
# interrupt) to the Linux VM fails while the VM is in "stopped" state.
#
# VM can not receive NMI when it is in following states:-
#   Starting
#   Stopping
#   Stopped
#   Saving
#   Saved
#   Restoring
#######################################################################

param([string] $vmName , [string] $hvServer)

#######################################################################
#
# Main script body
#
#######################################################################
$retVal = $false

#
# Check input arguments
#
if (-not $vmName)
{
    "Error: VM name is null. "
    return $retVal
}

if (-not $hvServer)
{
    "Error: hvServer is null"
    return $retVal
}

#
# Stopping VM prior to sending NMI
#
Stop-vm $vmName -ComputerName $hvServer -Force -Confirm:$false
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if ($vm.State -ne "off")
{
    "Error: VM could not be stopped"
    $retVal = $false
}

#
# Sending NMI to stopped VM
#
$errorstr = "Cannot inject a non-maskable interrupt into the virtual machine"

$nmistatus = Debug-VM -Name $vmName -InjectNonMaskableInterrupt -ComputerName $hvServer -Confirm:$False -Force 2>&1
$match = $nmistatus | select-string -Pattern $errorstr -Quiet

if ($match -eq "True")
{
    "Test Passed. NMI could not be sent when VM is in Stopped state"
    $retval = $true
}
else
{
    "Error: Test Failed. NMI was sent when VM was in its inappropriate state"
    return $false

}

#
# Updating the summary log with Testcase ID details
#
$summaryLog = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "Covers TC NMI-2.3.2b" | Out-File $summaryLog

return $retval
