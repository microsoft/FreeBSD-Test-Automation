#!/usr/bin/env python

import platform
import wmi
import time

import utils
import kvp_utils


WIN_VER_WS2012 = 9200

VM_STATE_UNKNOWN    = 0
VM_STATE_OTHER      = 1
VM_STATE_RUNNING    = 2
VM_STATE_OFF        = 3
VM_STATE_SHUTDOWN   = 4
VM_STATE_SAVED      = 6
VM_STATE_PAUSED     = 9

STATE_CODE_STARTED  = 4096

VM_HEARTBEAT_OK         = 2
VM_HEARTBEAT_DEGRADED   = 3
VM_HEARTBEAT_ERROR      = 7
VM_HEARTBEAT_NO_CONTACT = 12
VM_HEARTBEAT_LOST_COMM  = 13
VM_HEARTBEAT_PAUSED     = 15

TEMP_CIM_XML_FILE = 'temp-cim.xml'

def get_virt_namespace():
    osname = platform.system()
    if osname != "Windows":
        print "HyperVLib can only be used on Windows!"
        exit(1)

    c = wmi.WMI()
    virt_namespace = "/root/virtualization"
    for os in c.Win32_OperatingSystem():
        if int(os.BuildNumber) >= WIN_VER_WS2012:
            # We're running on Server 2012 and above
            # use v2 namespace
            virt_namespace += "/v2"
        break

    return virt_namespace

# create a WMI connection to the virtualization namespace
def create_virt_conn(hostname='.'):
    conn_str = "//" + hostname + get_virt_namespace()

    c = wmi.WMI(moniker=conn_str)
    return c

def get_vmms(hostname='.'):
    conn = create_virt_conn(hostname)
    vmms = conn.Msvm_VirtualSystemManagementService()[0]

    return vmms

def get_snapshot_service(hostname='.'):
    conn = create_virt_conn(hostname)
    return conn.Msvm_VirtualSystemSnapshotService()[0]

# list all VMs on 
def list_vm(hostname='.'):
    vms = []
    conn = create_virt_conn(hostname)
    for vm in conn.Msvm_ComputerSystem(['ElementName']):
        vms.append(vm.ElementName)

    return vms

def get_vm(vm_name, hostname='.'):
    conn = create_virt_conn(hostname)

    # query the VM using ElementName
    vm = conn.Msvm_ComputerSystem(ElementName = vm_name)[0]

    return vm

def get_vm_state(vm_name, hostname='.'):
    enabled_state = get_vm(vm_name, hostname).EnabledState
    if enabled_state == VM_STATE_OTHER:
        return get_vm(vm_name, hostname).OtherEnabledState
    return enabled_state

# save the specific VM
def save_vm(vm_name, hostname='.'):
    conn = create_virt_conn(hostname)

    vm = get_vm(vm_name, hostname)
    # get the current state of the VM
    current_state = get_vm_state(vm_name, hostname)

    print current_state

    if current_state == VM_STATE_RUNNING:
        job_path, requested_state = vm.RequestStateChange(VM_STATE_SAVED)
    elif current_state == VM_STATE_SAVED:
        return True
    else:
        return False

    if requested_state == STATE_CODE_STARTED:
        if utils.job_completed(job_path):
            print vm_name, "saved."
            return True
        else:
            print vm_name, "failed to save."
    else:
        print "cannot change", vm_name, "to saved."
    return False

def start_vm(vm_name, hostname='.'):
    conn = create_virt_conn(hostname)

    vm = get_vm(vm_name, hostname)
    # get the current state of the VM
    current_state = get_vm_state(vm_name, hostname)

    print current_state

    if current_state != VM_STATE_RUNNING:
        job_path, requested_state = vm.RequestStateChange(VM_STATE_RUNNING)
    else:
        return True

    if requested_state == STATE_CODE_STARTED:
        if utils.job_completed(job_path):
            print vm_name, "started."
            return True
        else:
            print vm_name, "failed to start."
    else:
        print "cannot change", vm_name, "to running."
    return False

def stop_vm(vm_name, hostname='.'):
    conn = create_virt_conn(hostname)

    vm = get_vm(vm_name, hostname)

    current_state = get_vm_state(vm_name, hostname)

    print current_state

    if current_state != VM_STATE_OFF:
        job_path, ret = vm.RequestStateChange(VM_STATE_OFF)

    if ret == STATE_CODE_STARTED:
        if utils.job_completed(job_path):
            print vm_name, "stopped."
            return True
        else:
            print vm_name, "failed to stop."
    else:
        print "Cannot turn off VM"
    return False

def revert_to_snapshot(snapshot_name, vm_name, hostname='.'):
    conn = create_virt_conn(hostname)

    snapshot_service = get_snapshot_service(hostname)
    vm = get_vm(vm_name, hostname)

    snapshots = vm.associators(wmi_result_class="Msvm_VirtualSystemSettingData")

    for s in snapshots:
        if s.ElementName == snapshot_name:
            # snapshot found, reverting...
            snapshot = s
            print 'Reverting to snapshot "%s"' % snapshot_name
            job_path, ret = snapshot_service.ApplySnapshot(Snapshot=snapshot.path_())

            if ret == STATE_CODE_STARTED:
                if utils.job_completed(job_path):
                    print 'VM "%s" reverted to snapshot "%s"' % (vm_name, snapshot_name)
                else:
                    print 'VM "%s" failed to revert to snapshot "%s"' % (vm_name, snapshot_name)

                # return now since we found the correct snapshot object
                return True
            else:
                continue

    return False

def get_kvp_intrinsic_exchange_items(vm_name, hostname='.'):
    conn = create_virt_conn(hostname)

    vm = get_vm(vm_name, hostname)

    kvps = vm.associators("Msvm_SystemDevice", wmi_result_class="Msvm_KvpExchangeComponent")

    ret = []
    if len(kvps) > 0:
        items = kvps[0].GuestIntrinsicExchangeItems
        for item in items:
            ret.append(kvp_utils.parse_kvp_data_item(item))

        return ret
    return None

def add_kvp_item(kvp_key, kvp_value, vm_name, hostname='.'):
    # http://blogs.msdn.com/b/taylorb/archive/2008/07/06/hyper-v-wmi-kvp-exchange-aka-data-exchange-adding-new-items-from-parent-host.aspx
    conn = create_virt_conn(hostname)

    vm = get_vm(vm_name, hostname)

    kvps = vm.associators("Msvm_SystemDevice", wmi_result_class="Msvm_KvpExchangeComponent")

    vmms = get_vmms(hostname)

    
    data_item = conn.Msvm_KvpExchangeDataItem.new()

    data_item.Name = kvp_key
    data_item.Data = kvp_value
    data_item.Source = 0

    job_path, ret_val = vmms.AddKvpItems(TargetSystem=vm.path_(), DataItems=[data_item.GetText_(1)])

    if ret_val == STATE_CODE_STARTED:
        if utils.job_completed(job_path):
            print vm_name, " KVP item added."
            return True
        else:
            print vm_name, "failed to add KVP item, code:", ret_val
    else:
        print "Cannot add KVP item"

    return False

def remove_kvp_item(kvp_key, vm_name, hostname='.'):
    conn = create_virt_conn(hostname)

    vm = get_vm(vm_name, hostname)

    kvps = vm.associators("Msvm_SystemDevice", wmi_result_class="Msvm_KvpExchangeComponent")

    vmms = get_vmms(hostname)

    data_item = conn.Msvm_KvpExchangeDataItem.new()

    data_item.Name = kvp_key
    data_item.Data = ''
    data_item.Source = 0

    job_path, ret_val = vmms.RemoveKvpItems(TargetSystem=vm.path_(), DataItems=[data_item.GetText_(1)])

    if ret_val == STATE_CODE_STARTED:
        if utils.job_completed(job_path):
            print vm_name, " KVP item removed."
            return True
        else:
            print vm_name, "failed to remove KVP item, code:", ret_val
    else:
        print "Cannot remove KVP item"

    return False



def get_heartbeat_status(vm_name, hostname='.'):
    # http://msdn.microsoft.com/en-us/library/hh850157(v=vs.85).aspx
    conn = create_virt_conn(hostname)

    vm = get_vm(vm_name, hostname)
    
    hbs = vm.associators(wmi_result_class="Msvm_HeartbeatComponent")

    # read the operational status
    if len(hbs) > 0:
        op_status = hbs[0].OperationalStatus[0]

        print op_status

        # TODO: fill this with application data
        co_status = 0
        
        return op_status, co_status

    return None


