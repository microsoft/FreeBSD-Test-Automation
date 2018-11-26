#!/usr/bin/env python
import sys
import os
import time

import test_class

class NoopTest(test_class.TestClass):
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

    def _run(self, args):
        # get the workers
        host_one = self._machines[0]['host']

        # get a VM
        vm_one = self._machines[0]['vms'][0]['name']

	print 'Noop'


    def _tear_down(self, args):
        pass

    def _request_machines(self):
        request = {'pool': 'perf', 
                   'desc': 'perf_Noop', 
                   'req': [0]
                   }

        return request

    def _test_param(self, args):
        param = {
            'multi-threaded': True,
            'snapshot': 'ICABase',
            'remote_path': '/root/'
            }
        return param 

