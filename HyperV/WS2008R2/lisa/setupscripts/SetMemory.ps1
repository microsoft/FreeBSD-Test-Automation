############################################################################
#
# SetMemory.ps1
#
# This script sets the memory of the VM to a provided value.
#
# Required testParams
#    RootDir = root directory path
#    MomoryToSet = 512/1024/2048/4096/8192MB
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
    if ($fields[0].Trim() -eq "MEMORYTOSET")
    {
        $memory = $fields[1].Trim()
    }
}

if (-not $memory)
{
    "Error: Missing testParam memory to be added"
    return $False
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
# Set the Memory of the test VM
#

$a = Get-VM -Name $vmName -Server $hvServer | Set-VMMemory -Memory $memory  2>&1


if ($a -is [System.Management.ManagementObject])
{
    "Vm memory set to $memory MB"
}
else
{
    "Error: Unable to Set the VM memory to $memory MB"
    return $False
}



return $true
