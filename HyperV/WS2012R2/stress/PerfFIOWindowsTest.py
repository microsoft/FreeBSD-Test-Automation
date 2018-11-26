#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess
import socket

DEFAULT_COOL_DOWN_TIME = 5

class PerfFIOWindowsTest(test_class.TestClass):
    def _set_up_vm(self, vm_name, args):
        # this piece of code will be executed first thing after the VM is 
        # booted up
        pass


    def _set_up_host(self, host_name, args):
        # BEFORE the VM boots up, this function will be Popened to prepare 
        # the host.
        # Tasks could include creating VM, configuring VM and install host 
        # software.
        pass

    def run_fio_on_windows(self, vm, args):
        hostname = vm['name']

        iodepth = args['iodepth']
        numjobs = args['numjobs']
        runtime = args['runtime']
        device = args['perf_drive']
        count = args['count']

        for block_size, mix_read, mix_write in args['run_param']:
            test_name = '%s-%dk-%d-%d-%d-test' % (hostname, block_size, mix_read, mix_write, count)

            command = '\"c:\\Program Files\\fio\\fio.exe\" --direct=1 --rw=randrw --iodepth=%d --numjobs=%d --runtime=%d --group_reporting --norandommap --randrepeat=0 --refill_buffers --filename=\\\\.\\%s --rwmixread=%d --rwmixwrite=%d --bs=%dk --name=%s --output=c:\\logs\\%s.log --minimal --ioengine=windowsaio' % (iodepth, numjobs, runtime, device, mix_read, mix_write, block_size, test_name, test_name)

            test_class._run_on_windows(self, vm, command)


    def _run(self, args):
        # get the workers

        args = dict(args.items() + self._test_param(None).items())

        for host in self._machines:
            for vm in host['vms']:
                print 'Running test on VM: "%s"' % vm['name']
                for i in range(3):
                    print 'Iterate #%d' % i
                    args['perf_drive'] = vm['perf_drive']
                    args['count'] = i

                    self.run_fio_on_windows(vm, args)

                    # cool down a bit
                    time.sleep(DEFAULT_COOL_DOWN_TIME)

    def _tear_down(self, args):
        pass

    def _request_machines(self):
        request = {'pool': 'perf', 
                   'desc': 'perf_FIO', 
                   'req': [0]
                   }

        return request

    def _test_param(self, args):
        param = {
            'multi-threaded': True,
            'snapshot': 'ICABase',
            'remote_path': '/root/',
            'threads': [1],
            'run_param': [(4, 100, 0), (4, 0, 100), (8, 70, 30)],
            'iodepth': 16,
            'numjobs': 16,
            'runtime': 60
            }
        return param 

