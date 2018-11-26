############################################################################
#
# GetNonIntrinsicValues.ps1
#
# Description:
#     This PowerShell test script verifies the non-intrisic data i.e. Pool1 key value pairs.
#     Parameters to be passed are - VM Name, HV server name, test case number, Key Value pair           
#
#     This test should be run after the KVP Basic Test.
#
############################################################################
param([string] $vmName, [string] $hvServer, [string] $testParams)

$script:retVal = $false 

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
    "This script requires the Key & value as the test parameters"
    return $retVal
}

#
# Find the testParams we require.  Complain if not found
#
$Key = $null
$TC_COVERED = $null

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    
    if ($fields[0].Trim() -eq "Key")
    {
        $Key = $fields[1].Trim()
    }
        
    if ($fields[0].Trim() -eq "TC_COVERED")
    {
        $TC_COVERED = $fields[1].Trim()
    }
            
}

if (-not $Key)
{
    "Error: Missing testParam Key to be added"
    return $retVal
}
if (-not $TC_COVERED)
{
    "Error: Missing testParam Value to be added"
    return $retVal
}

#
# creating the summary file
#
$summaryLog  = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-Output $TC_COVERED | Out-File $summaryLog


#
# Verify that the non-intrinsic values are available and can be read.
#

filter Import-Non-IntrinsicXml
{
    $CimXml = [Xml]$_
    $CimObj = New-Object -TypeName System.Object
    foreach ($CimProperty in $CimXml.SelectNodes("/INSTANCE/PROPERTY"))
    {
        $CimObj | Add-Member -MemberType NoteProperty -Name $CimProperty.NAME -Value $CimProperty.VALUE
        if ($CimProperty.VALUE -eq $Key)
        {
          Write-Host "Key added to pool 1 is verified"
          $CimObj
          $script:retVal = $true
          return
        }
    }
   
}

$Vm = Get-WmiObject -Namespace root\virtualization -Query "Select * From Msvm_ComputerSystem Where ElementName=`'$VmName`'"
$Kvp = Get-WmiObject -Namespace root\virtualization -Query "Associators of {$Vm} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent"

if ($kvp.GuestExchangeItems.Count -eq 0)
{
 Write-Output "Error: Non-intrinsic values are not available in pool 1"
 return $retVal
}

Write-host "Verifying the Non-Intrinsic values on guest"
$Kvp.GuestExchangeItems | Import-Non-IntrinsicXml

if ($retVal -eq $false )
{
 write-host "Error (non-intrinsic data) - Key inserted from guest is not found in Pool 1"
 return $retVal
}

write-host "Non-intrinsic values are verfied and available on guest OS"

return $retVal

