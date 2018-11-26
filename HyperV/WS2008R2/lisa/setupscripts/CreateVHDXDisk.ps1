#######################################################################
#
# This is a script that works only on Windows 8 server.
#
#######################################################################kex
param (
        $Server = "localhost",
        $ParentVHDX,
        $VHDXPath
      )
$s = New-PSSession -ComputerName $Server
Invoke-Command -Session $s -scriptBlock {
    param($Remote_VHDXPath, $Remote_ParentVHD)
    Import-Module Hyper-V
    New-VHD -Path $Remote_VHDXPath -ParentPath $Remote_ParentVHD -VHDFormat VHDX -VHDType Differencing
} -Args $VHDXPath,$ParentVHDX
