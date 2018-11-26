#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess

class StorVSCIOZoneTest(test_class.TestClass):
    def _set_up_vm(self, vm_name, args):
        # this piece of code will be executed first thing after the VM is 
        # booted up
        args['working_dir'] = self._test_param(None)['working_dir']
        test_class._run_on_vm(self, vm_name, "install_iozone", args)
        test_class._run_on_vm(self, vm_name, "format_drive", args)

    def _set_up_host(self, host_name, args):
        # BEFORE the VM boots up, this function will be called to prepare 
        # the host.
        # Tasks could include creating VM, configuring VM and install host 
        # software.
        pass

    def format_drive(self, args):
        DEFAULT_SCSI_DRIVE = '/dev/da1'
        
        if os.path.exists(DEFAULT_SCSI_DRIVE + 'p1'):
            # delete the partition
            subprocess.call(["gpart", "delete", "-i", "1", DEFAULT_SCSI_DRIVE])
            subprocess.call(["gpart", "destroy", DEFAULT_SCSI_DRIVE])

        time.sleep(2)
        subprocess.call(["gpart", "create", "-s", "GPT", DEFAULT_SCSI_DRIVE])
        subprocess.call(["gpart", "add", "-t", "freebsd-ufs", DEFAULT_SCSI_DRIVE])
        subprocess.call(["newfs", DEFAULT_SCSI_DRIVE + "p1"])

        time.sleep(5)
        subprocess.call(["mount", DEFAULT_SCSI_DRIVE + "p1", args['working_dir']])

    def install_iozone(self, args):
        logfile = open('install-iozone.log', 'w')
        p = subprocess.Popen(["pkg", "install", "-y" , "iozone"],
                             stdout = logfile,
                             stderr = logfile)
        p.wait()
        logfile.close()

    def run_iozone(self, args):
        # remember to copy the logs
        logfile = open('iozone.log', 'w')

        # make IOZone run on a separate drive
        os.chdir(args['working_dir'])
        p = subprocess.Popen(["iozone", "-a", "-z", "-g10g", "-Vshostc"],
                              stdout=logfile, 
                              stderr=logfile)
        p.wait()
        logfile.close()

    def _run(self, args):
        # get a host...
        # yes I know it's ugly
        host_one = self._machines[0]['host']

        # get a VM
        vm_one = self._machines[0]['vms'][0]['name']

        args['working_dir'] = self._test_param(None)['working_dir']
        test_class._run_on_vm(self, vm_one, "run_iozone", args)

    def _tear_down(self, args):
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # only 1 VM on 1 host is required
        request = {'pool': 'stress', 
                   'desc': 'storvsc_IOZone', 
                   'req': [1]
                   }

        return request

    def _test_param(self, args):
        param = {
            'multi-threaded': True,
            'snapshot': 'ICABase',
            'remote_path': '/root/',
            'working_dir': '/mnt/test'

            }
        return param 

