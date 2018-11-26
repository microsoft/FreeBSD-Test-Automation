############################################################################
#
# 
#
# Description:
#      
#     Getting IP
#     
#
############################################################################
param([string] $vmName,
[string] $hvServer) 

$retVal = $false

#
# Check input arguments
# 
if (-not $vmName -or $vmName.Length -eq 0)
{
    "Error: VM name is null"
    return $retVal
}

  
     $DHCPEnabled = $false
     $IPAddress = "172.25.220.22"
     $Subnet = "255.255.255.0"
     $DnsServer = "10.171.0.37"
     $Gateway = "172.25.220.1"
     $ProtocolIFType = 4096


$NamespaceV2 = "root\virtualization"

function ReportError($Message)
{
    Write-Host $Message -ForegroundColor Red
}

#
# Print VM Info related to replication
#
function PrintVMInfo()
{
    [System.Management.ManagementObject[]]$vmobjects = Get-WmiObject -Namespace $NamespaceV2 -Query "Select * From Msvm_ComputerSystem where Caption='Virtual Machine'"  -computername $hvServer 
    CheckNullAndExit $vmobjects "Failed to find VM objects"
    Write-Host "Available Virtual Machines" -BackgroundColor Yellow -ForegroundColor Black
    foreach ($objItem in $vmobjects) {
        Write-Host "Name:             " $objItem.ElementName
        Write-Host "InstaceId:        " $objItem.Name
        Write-Host "InstallDate:      " $objItem.InstallDate
        Write-Host "ReplicationState: " @(PrintReplicationState($objItem.ReplicationState))
        Write-Host "ReplicationHealth: " @(PrintReplicationHealth($objItem.ReplicationHealth))
        Write-Host "LastReplicationTime: " @(ConvertStringToDateTime($objItem.LastReplicationTime))
        Write-Host "LastReplicationType: " @(PrintReplicationType($objItem.LastReplicationType))
        Write-Host
    }

    return $objects
}
#
# Monitors Msvm_ConcreteJob.
#
function MonitorJob($opresult)
{
    if ($opresult.ReturnValue -eq 0)
    {
        Write-Host("$TestName success.")
        return 
    }
    elseif ($opresult.ReturnValue -ne 4096)
    {
        Write-Host "$TestName failed. Error code " @(PrintJobErrorCode($opresult.ReturnValue)) -ForegroundColor Red
        return
    }
    else
    {
        #Find the job to monitor status
        $jobid = $opresult.Job.Split('=')[1]
        $concreteJob = Get-WmiObject -Query "select * from CIM_ConcreteJob where InstanceId=$jobid"  -namespace $NamespaceV2 -computername $hvServer

		$top = [Console]::CursorTop
		$left = [Console]::CursorLeft
		
        PrintJobInformation $concreteJob
        
        #Loop till job not complete
        if ($concreteJob -ne $null -AND
            ($concreteJob.PercentComplete -ne 100) -AND 
            ($concreteJob.ErrorCode -eq 0)
            )
        {
            Start-Sleep -Milliseconds 500
            
            # Following is to show progress on same position for powershell cmdline host
			if (!(get-variable  -erroraction silentlycontinue "psISE"))
			{
				[Console]::SetCursorPosition($left, $top)
			}

            MonitorJob $opresult
        }
    }
}

function CheckNullAndExit([System.Object[]] $object, [string] $message)
{
    if ($object -eq $null)
    {
        ReportError($message)
        exit 99
    }
    return     
}

function CheckSingleObject([System.Object[]] $objects, [string] $message)
{
    if ($objects.Length -gt 1)
    {
        ReportError($message)
        exit 99
    }
    return     
}

#
# Get VM object
#
function GetVirtualMachine([string] $vmName)
{
    $objects = Get-WmiObject -Namespace $NamespaceV2 -Query "Select * From Msvm_ComputerSystem Where ElementName = '$vmName' OR Name = '$vmName'"  -computername $hvServer 
    if ($objects -eq $null)
    {
     Write-Host "Virtual Machines Not Found , Please check the VM name"
     PrintVMInfo
    }

    CheckNullAndExit $objects "Failed to find VM object for $vmName"

    if ($objects.Length -gt 1)
    {
        foreach ($objItem in $objects) {
            Write-Host "ElementName: " $objItem.ElementName
            Write-Host "Name:        " $objItem.Name
            }
        CheckSingleObject $objects "Multiple VM objects found for name $vmName. This script doesn't support this. Use Name GUID as VmName parameter."
    }

    return [System.Management.ManagementObject] $objects
}


#
# Get VM Service object
#
function GetVmServiceObject()
{
    $objects = Get-WmiObject -Namespace $NamespaceV2  -Query "Select * From Msvm_VirtualSystemManagementService"  -computername $hvServer
    CheckNullAndExit $objects "Failed to find VM service object"
    CheckSingleObject $objects "Multiple VM Service objects found"
    
    return $objects
}

#
# Find first Msvm_GuestNetworkAdapterConfiguration instance.
#
function GetGuestNetworkAdapterConfiguration($VMName)
{
    $VM = gwmi -Namespace root\virtualization -class Msvm_ComputerSystem -ComputerName $hvServer | where {$_.ElementName -like $VMName}
    CheckNullAndExit $VM "Failed to find VM instance"

    # Get active settings
    
    $vmSettings = $vm.GetRelated( "Msvm_VirtualSystemSettingData", "Msvm_SettingsDefineState",$null,$null, "SettingData", "ManagedElement", $false, $null)
       
    # Get all network adapters 
    $nwAdapters = $vmSettings.GetRelated("Msvm_SyntheticEthernetPortSettingData") 

	# Find associated guest configuration data	
    $nwconfig = ($nwadapters.GetRelated("Msvm_GuestNetworkAdapterConfiguration", "Msvm_SettingDataComponent", $null, $null, "PartComponent", "GroupComponent", $false, $null) | % {$_})
	    
    if ($nwconfig -eq $null)
    {
        Write-Host "Failed to find Msvm_GuestNetworkAdapterConfiguration instance. Creating new instance."
    }

    return $nwconfig;
}

#
# Print Msvm_FailoverNetworkAdapterSettingData
#
function PrintNetworkAdapterSettingData($nasd)
{
    foreach ($objItem in $nasd) 
    {
        New-Object PSObject -Property @{      
        "InstanceID: " = $objItem.InstanceID ;
        "ProtocolIFType: " = $objItem.ProtocolIFType ;
        "DHCPEnabled: " = $objItem.DHCPEnabled ;
        "IPAddresses: " = $objItem.IPAddresses ;
        "Subnets: " = $objItem.Subnets ;
        "DefaultGateways: " = $objItem.DefaultGateways ;
        "DNSServers: " = $objItem.DNSServers ;}
    
    }
}

function StartTest($TestName)
{
    Write-Host "-------------------------------------------------------------------------"
    Write-Host $TestName 
    Write-Host "-------------------------------------------------------------------------"
    Write-Host
}


$TestName = "GetGuestNetworkAdapterConfiguration"

##############################################################################
# Main
##############################################################################

StartTest $TestName

#Get Virtual Machine Object
[System.Management.ManagementObject] $vm = GetVirtualMachine($VmName)

[System.Management.ManagementObject] $vmservice = @(GetVmServiceObject)[0]

[System.Management.ManagementObject] $nwconfig = @(GetGuestNetworkAdapterConfiguration($VmName))[0];

write-output "Msvm_GuestNetworkAdapterConfiguration before update .. please make sure that VM is running ..."
write-output "-------------------------------------------------------------------------"
write-output $TestName 
write-output "-------------------------------------------------------------------------"
PrintNetworkAdapterSettingData($nwconfig)
return $true

