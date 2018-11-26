############################################################################
#
# DeleteSnapshot.ps1
#
############################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $false

#
# Check input arguments
#
if (-not $vmName)
{
    "Error: VM name is null"
    return $retVal
}

if (-not $hvServer)
{
    "Error: hvServer is null"
    return $retVal
}

if (-not $testParams)
{
    "Error: No testParams provided"
    "       This script requires the snapshot name as the test parameter"
    return $retVal
}

#
# Find the testParams we require.  Complain if not found
#
$Snapshot = $null

$params = $testParams.Split(";")
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
    
    if ($tokens[0].Trim() -eq "SnapshotName")
    {
        $Snapshot = $tokens[1].Trim()
    }
}          

if ($rootDir -eq $null)
{
    "Error: The RootDir test parameter is not defined."
    return $False
}

if (-not $Snapshot)
{
    "Error: Missing testParam SnapshotName"
    return $retVal
}

cd $rootDir


$summaryLog  = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue

Get-VMSnapshot -VMName $vmName -ComputerName $hvServer -Name $Snapshot | Remove-VMSnapshot -Confirm:$False
if ($? -eq "True")
{
    Write-Output "Snapshot $Snapshot delete successfully" | Out-File $summaryLog
    $retVal = $True
}
else
{
    Write-Output "Error while deleting VM snapshot" | Out-File $summaryLog
    return $False
}

Write-Output $retVal

return $retVal

