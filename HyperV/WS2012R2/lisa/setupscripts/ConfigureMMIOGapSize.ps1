param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $false
$rootDir = $null
$failCount = 0
$TC_COVERED = $null
[int]$newGapSize = 0
$icaserialPath = $null
$testLogDir = $null


####################################################################### 
#
# function GetVmSettingData ()
# This function will filter all the settings for given VM
#
#######################################################################
function GetVmSettingData([String] $name, [String] $server)
{
    if (-not $name) {
        return $null
    }

    $vssd = gwmi -n root\virtualization\v2 -class Msvm_VirtualSystemSettingData -ComputerName $server
        if (-not $vssd) {
            return $null
        }

    foreach ($vm in $vssd) {
        if ($vm.ElementName -ne $name) {
            continue
        }
        return $vm
    }
    return $null
}

#######################################################################
#
# function SetMMIOgap ()
# This function will set the MMIO gap size
#
#######################################################################
function SetMMIOGap([INT] $newGapSize)
{
    #
    # Getting the VM settings
    #
    $vssd = GetVmSettingData $vmName $hvServer
    if (-not $vssd) {
        Write-Output "Error: Unable to find settings data for VM '${vmName}'!" | Tee-Object -Append -file $summaryLog
        return $false
    }

    #
    # Create a WMI management object
    #
    $mgmt = gwmi -n root\virtualization\v2 -class Msvm_VirtualSystemManagementService -ComputerName $hvServer
    if(!$?) {
        Write-Output "Error: Unable to create WMI Management Object!" | Tee-Object -Append -file $summaryLog
        return $false
    }

    $vssd.LowMmioGapSize = $newGapSize
    $sts = $mgmt.ModifySystemSettings($vssd.gettext(1))

    if ($sts.ReturnValue -ne 0) {
        Write-Output "Failed to set MMIO gap size of $newGapSize." | Tee-Object -Append -file $summaryLog
        return $false
    }
    return $true
}

#
# Checking the mandatory testParams
#
$params = $testParams.Split(";")
foreach ($p in $params) {
    $fields = $p.Split("=")

    if ($fields[0].Trim() -eq "TC_COVERED") {
        $TC_COVERED = $fields[1].Trim()
    }
    if ($fields[0].Trim() -eq "rootDir") {
        $rootDir = $fields[1].Trim()
    }
    if ($fields[0].Trim() -eq "GAPSIZE") {
        $newGapSize = $fields[1].Trim()
    }
    if ($fields[0].Trim() -eq "PIPE") {
        $serialPipe = $fields[1].Trim()
    }
    if ($fields[0].Trim() -eq "TestLogDir") {
        $testLogDir = $fields[1].Trim()
    }
}

if (-not $serialPipe) {
    "Error: Missing parameter PIPE in testParams"
    return $false
}

#
# Change the working directory for the log files
# Delete any previous summary.log file, then create a new one
#
if (-not (Test-Path $rootDir)) {
    "Error: The directory `"${rootDir}`" does not exist"
    return $retVal
}
cd $rootDir

$summaryLog = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
#Write-Output "This script covers test case: ${TC_COVERED}" | Tee-Object -Append -file $summaryLog

#######################################################################
#
# Main script body
#
#######################################################################
#
# Check input arguments
#
if (-not $vmName) {
    Write-Output "Error: VM name is null!"
    return $retVal
}

if (-not $hvServer) {
    Write-Output "Error: hvServer is null!"
    return $retVal
}

#
# Stopping the VM prior to setting the gap size
#
if ((Get-VM -Name $vmName -ComputerName $hvServer).state -ne "Off" -and $vm.Heartbeat -ne "") {
    Stop-VM -Name $vmName -ComputerName $hvServer -Force
    if(!$?) {
        Write-Output "Error: VM could not be stopped!" | Tee-Object -Append -file $summaryLog
        return $false
    }
}

$retVal = SetMMIOGap($newGapSize)

if (-not $retVal)
{
    "Error: Failed to set MMIO gap"
    return $false
}

#
# Start icaserial.exe to capture boot output from named pipe
#

Start-Process "tools\icaserial.exe" "READ \\${hvServer}\pipe\${serialPipe}" -RedirectStandardOutput "${testLogDir}\${vmName}_serial.log"

#
# Starting the VM for LISA clean-up
#
if ((Get-VM -ComputerName $hvServer -Name $vmName).State -eq "Off") {
    Start-VM -ComputerName $hvServer -Name $vmName
}

do { 
    Start-Sleep -Seconds 3
} 
until ((Get-VMIntegrationService -VMName $vmName -ComputerName $hvServer | ?{$_.name -eq "Heartbeat"}).PrimaryStatusDescription -eq "OK")

#
# Stop icaserial.exe
#
Stop-Process -ProcessName icaserial

# Look inside ${vmName}_serial.log for SMAP lines

$pattern = "SMAP\s+type=(\d+)\s+base=([0-9a-f]+)\s+len=([0-9a-f]+)"

$smapArray = Select-String -Path "${testLogDir}\${vmName}_serial.log" -Pattern $pattern -AllMatches

if ($smapArray.count -eq 0) {
    "Error: No SMAP line found in serial log"
    return $false
}

$lastBase = 0
$lastLen = 0

foreach ($m in $smapArray.matches) {
    $base = [Convert]::ToInt64($m.Groups[2].Value, 16)
    $len = [Convert]::ToInt64($m.Groups[3].Value, 16)

    if (($base + $len) -ge 0x100000000) {
        # found the last gap
        break
    }

    $lastBase = $base
    $lastLen = $len
}

# calculate the gap size based on $lastBase and $lastLen
$actualGapSize = (0x100000000 - ($lastBase + $lastLen)) / 0x100000

$actualGapSize

$retVal = $false
if ($actualGapSize -eq $newGapSize) {
    $retVal = $true
}

# Stop the VM
Stop-VM -Name $vmName -ComputerName $hvServer -Force

return $retVal
