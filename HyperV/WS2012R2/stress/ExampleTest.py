#!/usr/bin/env python
import sys
import os
import time

import test_class

class ExampleTest(test_class.TestClass):
    def _set_up_vm(self, vm_name, args):
        # this piece of code will be executed first thing after the VM is 
        # booted up
        print "_set_up_vm:", vm_name

    def _set_up_host(self, host_name, args):
        # BEFORE the VM boots up, this function will be called to prepare 
        # the host.
        # Tasks could include creating VM, configuring VM and install host 
        # software.
        print "_set_up_host:", host_name

    def start_example(self, args):
        print "example"
        f = open('testfile', 'a')

        f.write(time.strftime("%Y-%m-%d %H:%M:%S\n", time.gmtime()))
        f.close()
        return args

    def _run(self, args):
        # EXAMPLE: do something...
        print 'Inside _run'

        # get a host...
        # yes I know it's ugly
        host_one = self._machines[0]['host']

        # get a VM
        vm_one = self._machines[0]['vms'][0]['name']

        test_class._run_on_vm(self, vm_one, "start_example", args)

    def _tear_down(self, args):
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # in this example, this test case will require 1 host, each host
        # should provide one VM.
        request = {'pool': 'stress', 
                   'desc': 'example', 
                   'req': [1]
                   }

        return request

    def _test_param(self, args):
        param = {
            'multi-threaded': True,
            #'ssh_key_file': 'rhel5_id_rsa',
            'snapshot': 'ICABase',
            'username': 'root',
            'password': '1*admin',
            'remote_path': '/root/',
            'name_server': '172.23.140.42'
            }
        return param 

