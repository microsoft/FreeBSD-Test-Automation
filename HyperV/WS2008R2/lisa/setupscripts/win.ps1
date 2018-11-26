#
#
# Script to test ping on windows VM
#
#
$retVal = $false

Enable-PSRemoting -Force

winrm s winrm/config/client '@{TrustedHosts="WIN-17KR1IEDQC7"}'

$pass = cat D:\Automation\trunk\lisa\pass.txt | ConvertTo-SecureString
$cred = New-Object -type System.Management.Automation.PSCredential -ArgumentList "Administrator",$pass

$a = Invoke-Command -ComputerName WIN-17KR1IEDQC7 -ScriptBlock { ping 10.10.10.5 } -credential $cred

$b = $a|Select-String -Pattern "TTL" -Quiet
if($b -eq "True")
{
 "Ping is successfull"
 $retVal = $true
}
else
{
 "Ping Failed"
 return $false
}
return $True