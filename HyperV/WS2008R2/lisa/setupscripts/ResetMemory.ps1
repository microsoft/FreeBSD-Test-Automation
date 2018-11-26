############################################################################
#
# ResetMemory.ps1
#
# This script will reset the VM memory to 1024 MB
#
# Required testParams
#    hvserver = host server name
#    vmName = Name of the VM
#    RootDir - root directory path
#
############################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)


#
# Check input arguments
#
if (-not $vmName -or $vmName.Length -eq 0)
{
    "Error: vmName is null"
    return $False
}

if (-not $hvServer -or $hvServer.Length -eq 0)
{
    "Error: hvServer is null"
    return $False
}

if (-not $testParams -or $testParams.Length -lt 3)
{
    "Error: testParams is null or invalid"
    return $False
}

$rootdir = $null

#
# Parse the testParams string
#
$params = $testParams.Split(';')
foreach ($p in $params)
{
    if ($p.Trim().Length -eq 0)
    {
        continue
    }

    $fields = $p.Trim().Split('=')
    
    if ($fields.Length -ne 2)
    {
	    #"Warn : test parameter '$p' is being ignored because it appears to be malformed"
        continue
    }
    
    if ($fields[0].Trim() -eq "RootDir")
    {
        $rootdir = $fields[1].Trim()
    }
  
}

#
# change the working directory to root dir
#

cd $rootdir

#
# Import the Hyperv module
#

$sts = get-module | select-string -pattern Hyperv -quiet
if (! $sts)
{
    Import-module .\HyperVLibV2Sp1\HyperV.psd1
}


#
# Reset the Memory of the test VM to 1024MB
#

$a = Get-VM -Name $vmName -Server $hvServer | Set-VMMemory -Memory 1024MB  2>&1


if ($a -is [System.Management.ManagementObject])
{
    "Vm memory set to 1024 MB"
}
else
{
    "Error: Unable to Set the VM memory to 1024 MB"
    return $false
}



return $true
