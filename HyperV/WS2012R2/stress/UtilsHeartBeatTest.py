#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess

class UtilsHeartBeatTest(test_class.TestClass):
    def _set_up_vm(self, vm_name, args):
        # this piece of code will be executed first thing after the VM is 
        # booted up
        pass

    def _set_up_host(self, host_name, args):
        # BEFORE the VM boots up, this function will be called to prepare 
        # the host.
        # Tasks could include creating VM, configuring VM and install host 
        # software.
        pass

    def run_heartbeat(self, args):
        import hypervlib.hyperv

        for host in self._machines:
            host_name = host['host']

            for vm in host['vms']:
                vm_name = vm['name']

                print 'Querying VM "%s" for heartbeat status:' % vm_name
                
                op_status, co_status = hypervlib.hyperv.get_heartbeat_status(vm_name, 
                                                                             host_name)

                if op_status == hypervlib.hyperv.VM_HEARTBEAT_OK:
                    print 'Heartbeat OK'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_DEGRADED:
                    print 'Heartbeat OK (Degraded)'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_ERROR:
                    print 'ERROR: Heartbeat - Non-recoverable'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_NO_CONTACT:
                    print 'ERROR: Heartbeat - No Contact'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_LOST_COMM:
                    print 'ERROR: Heartbeat - Lost Communication'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_PAUSED:
                    vm_status = hypervlib.hyperv.get_vm_state(vm_name, host_name)
                    if vm_status == VM_STATE_PAUSED:
                        print 'Heartbeat OK - VM Paused'
                    else:
                        print 'ERROR: Heartbeat - Paused but VM is not paused'

    def _run(self, args):
        self.run_heartbeat(args)

    def _tear_down(self, args): 
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # only 1 VM on 1 host is required
        request = {'pool': 'stress', 
                   'desc': 'utils_HeartBeat', 
                   'req': [2]
                   }

        return request

    def _test_param(self, args):
        param = {
            'multi-threaded': True,
            'snapshot': 'ICABase',
            'remote_path': '/root/'
            }
        return param 

