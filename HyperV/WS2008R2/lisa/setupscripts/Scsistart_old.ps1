############################################################################
#
# Scsi.ps1
#
# Description:
#          Script to start iSCSI target service
#
#  
############################################################################

param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $False

"scsi.ps1"
"VM Name   = ${vmName}"
"HV Server = ${hvServer}"
"TestParams= ${testParams}"

#
# Check input arguments
#
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
# Parse the testParams string
#
$rootDir = $null

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

    if ($tokens[0].Trim() -eq "IPT")
    {
       $ipt = $tokens[1].Trim()
    }
}

if ($rootDir -eq $null)
{
    "Error: The RootDir test parameter is not defined."
    return $False
}

cd $rootDir

#
#
#
$summaryLog  = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output "Covers Scsi_Target" | Out-File $summaryLog


#
# Load the PowerShell HyperV Library
#
$sts = get-module | select-string -pattern HyperV -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\HyperV.psd1
}

#
# Start / Stop scsitarget service
#

$sstart = echo y |.\bin\plink.exe -i .\ssh\lisa_id_rsa.ppk root@${ipt} "service iscsitarget start" 2>&1

$starget = $sstart | Select-String -Pattern "done" -Quiet

if($starget -eq "True")
{
    Write-Output "SCSI target service started successfully"
    $retVal = $true
}
else
{
    Write-Output "SCSCI target service can't be started"
    return $False
}

#$Tar = Get-IscsiTarget

$Tar = Get-IscsiTargetPortal -TargetPortalAddress $ipt | Get-IscsiTarget

$Silent = Connect-IscsiTarget -NodeAddress $Tar.NodeAddress 2>&1

return $retVal