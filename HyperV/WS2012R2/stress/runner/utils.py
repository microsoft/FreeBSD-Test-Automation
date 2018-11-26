#!/usr/bin/env python

import socket
import sys
import paramiko
import time

from hypervlib import hyperv

SSH_PORT = 22
SLEEP_TIME_IN_SEC = 2

def _wait_on_port(vm_name, host_name, port):
    ip_addr = None
    while True:
        # get the IP of the VM
        ctrl_ip = get_ip_for_vm(vm_name, host_name)
        if ctrl_ip is not None:
            port_opened = check_port(ctrl_ip, port)

            if port_opened:
                print '%s:%s opened' % (ctrl_ip, str(port))
                return ctrl_ip
            else:
                print 'Waiting for %s:%s to be opened' % (ctrl_ip, str(port))
        else:
            print 'Waiting for IP address of VM "%s"' % vm_name
        time.sleep(SLEEP_TIME_IN_SEC)

def check_port(addr, port):
    s = socket.socket()
    try:
        s.connect((addr, port))
        return True
    except:
        return False

def get_ip_for_vm(vm_name, host_name):
    # for now let's just try using KVP to get the IP
    kvp_items = hyperv.get_kvp_intrinsic_exchange_items(vm_name, host_name)

    for item in kvp_items:
        if item['Name'] == 'NetworkAddressIPv4':
            ipv4_list = item['Data'].split(';')
	    print ipv4_list

            # we'll use the first non-local address
            # NOTE: for optimal usage, always put the "test" adapter to
            # the first on the adapter list in VM settings
            for ip in ipv4_list:
                if ip != "127.0.0.1" and not ip.startswith("192.168."):
                    return ip

    return None

# param is a dict
def init_vm(vm_name, host_name, params):
    print "init_vm"

    state = hyperv.get_vm_state(vm_name, host_name)
    if state == hyperv.VM_STATE_RUNNING:
        # if the VM is already running, there's no need to initialize it again
        # this is to avoid reverting VMs in a multi-case scenario
        ctrl_ip = _wait_on_port(vm_name, host_name, SSH_PORT)
        return ctrl_ip 
    
    # revert the VM to a known snapshot (checkpoint)
    snapshot = params['snapshot']
    snapshot_applied = hyperv.revert_to_snapshot(snapshot, vm_name, host_name)
    assert snapshot_applied == True

    # wait for VM to start up
    vm_started = hyperv.start_vm(vm_name, host_name)
    assert vm_started == True

    # wait on SSH port (default 22) for connection
    ctrl_ip = _wait_on_port(vm_name, host_name, SSH_PORT)

    ssh_client = paramiko.client.SSHClient()

    ssh_client.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())

    if 'ssh_key_file' in params:
        ssh_client.connect(ctrl_ip, port=SSH_PORT, 
                        username=params['username'], key_filename=params['ssh_key_file'])
    else:
        ssh_client.connect(ctrl_ip, port=SSH_PORT,
                            username=params['username'], password=params['password'])

    # read the uname of the target VM
    stdin, stdout, stderr = ssh_client.exec_command('uname -a')

    print 'Connected to "%s:%s" as "%s"' % (vm_name, SSH_PORT, params['username'])
    print 'Target:', stdout.readlines()

    return ctrl_ip
 
