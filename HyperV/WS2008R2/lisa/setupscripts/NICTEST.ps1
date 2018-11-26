function switchNIC() 
{
 $Error.Clear()

 $snic = Get-VMNIC -VM PPG_ICA -VMBus
 Write-Output $snic | Out-File -Append $summaryLog
 
 Set-VMNICSwitch $snic -Virtualswitch Internal
 if ($Error.Count -eq 0)
 {
  "Completed"
  $retVal = $true
 }
 else
  {
    "Error: Unable to Switch Network Adaptor Type"
    $Error[0].Exception
    return $False
  }
}
Write-Output $retVal 
return $retVal