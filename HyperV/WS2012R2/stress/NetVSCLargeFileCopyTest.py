#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess

TEMP_FILE_NAME = 'ten_gig.tmp'
TEN_GIG_FILE_SIZE = long(10 * 2**30)

class NetVSCLargeFileCopyTest(test_class.TestClass):
    def _set_up_vm(self, vm_name, args):
        # this piece of code will be executed first thing after the VM is 
        # booted up
        args['working_dir'] = self._test_param(None)['working_dir']
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


    def generate_ten_gig_file(self, args):
        filename = args['filename']

        os.chdir(args['working_dir'])
        with open(filename, 'w') as f:
            for i in range(TEN_GIG_FILE_SIZE/512):
                f.write(os.urandom(512))          
    
    def copy_file_over_network(self, args):                
        # TODO: need to deploy paramiko on the client machine
        import paramiko

        server_ip = args['server_ip']
        
        os.chdir(args['working_dir'])

        s = paramiko.client.SSHClient()
        s.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())
        s.connect(server_ip, 
                  22, 
                  username=args['username'], 
                  password=args['password'])

        sftp = s.open_sftp()
        file_path = os.path.join(args['working_dir'], TEMP_FILE_NAME)
        sftp.get(file_path, TEMP_FILE_NAME)

        assert os.path.getsize(file_path) == TEN_GIG_FILE_SIZE

    def remove_file(self, args):
        os.remove(os.path.join(args['working_dir'], TEMP_FILE_NAME))

    def _run(self, args):
        # get a host...
        # yes I know it's ugly
        host_one = self._machines[0]['host']

        # get a VM
        vm_server = self._machines[0]['vms'][0]['name']
        vm_client = self._machines[1]['vms'][0]['name']

        args['server_ip'] = self._machines[0]['vms'][0]['addr']
        args['filename'] = TEMP_FILE_NAME
        args['working_dir'] = self._test_param(None)['working_dir']

        test_class._run_on_vm(self, vm_server, "generate_ten_gig_file", args)

        args['username'] = self._test_param(None)['username']
        args['password'] = self._test_param(None)['password']
        args['remote_path'] = self._test_param(None)['remote_path']
        test_class._run_on_vm(self, vm_client, "copy_file_over_network", args)
        print "File has been copied from server to client successfully."
        
        test_class._run_on_vm(self, vm_client, "remove_file", args)
        test_class._run_on_vm(self, vm_server, "remove_file", args)
        print "File has been removed on both server and client."

    def _tear_down(self, args):
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # only 1 VM on 1 host is required
        request = {'pool': 'stress', 
                   'desc': 'netvsc_LargeFileCopy', 
                   'req': [1,1]
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

