#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess

class NetVSCIPerfTest(test_class.TestClass):
    def _set_up_vm(self, vm_name, args):
        # this piece of code will be executed first thing after the VM is 
        # booted up
        test_class._run_on_vm(self, vm_name, "install_iperf", args)

    def _set_up_host(self, host_name, args):
        # BEFORE the VM boots up, this function will be called to prepare 
        # the host.
        # Tasks could include creating VM, configuring VM and install host 
        # software.
        pass

    def install_iperf(self, args):
        logfile = open('install-iperf.log', 'w')

        p = subprocess.Popen(["pkg", "install", "-y" , "iperf"], 
                             stdout=logfile,
                             stderr=logfile)
        p.wait()
        logfile.close()

    def run_iperf_client(self, args):
        logfile = open('iperf-client.log', 'w')
        # remember to copy the logs
        server_ip = args['server_ip']
        p = subprocess.Popen(["iperf", "-c", server_ip, 
                              "-P", "10", "-t", "86400"],
                              stdout=logfile, 
                              stderr=logfile)
        p.wait()
        logfile.close()

    def run_iperf_server(self, args):
        logfile = open('iperf-server.log', 'w')
        # remember to copy the logs
        p = subprocess.Popen(["iperf", "-s", "-D"],
                              stdout=logfile, 
                              stderr=logfile)
        p.wait()
        logfile.close()

    def _run(self, args):
        # get a host...
        # yes I know it's ugly
        host_one = self._machines[0]['host']

        # get a VM
        vm_server = self._machines[0]['vms'][0]['name']
        vm_client = self._machines[0]['vms'][1]['name']

        args['server_ip'] = self._machines[0]['vms'][0]['addr']

        print vm_server, vm_client, args['server_ip']

        # no need to do multi-threading since iperf server can be launched
        # as a daemon, and will return immediately.
        test_class._run_on_vm(self, vm_server, "run_iperf_server", args)
        test_class._run_on_vm(self, vm_client, "run_iperf_client", args)

    def _tear_down(self, args):
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # only 1 VM on 1 host is required
        request = {'pool': 'stress', 
                   'desc': 'netvsc_IPerf', 
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

