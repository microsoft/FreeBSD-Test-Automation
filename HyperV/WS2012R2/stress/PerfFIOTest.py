#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess
import socket

DEFAULT_COOL_DOWN_TIME = 5

class PerfFIOTest(test_class.TestClass):
    def _set_up_vm(self, vm_name, args):
        # this piece of code will be executed first thing after the VM is 
        # booted up

        test_class._run_on_vm(self, vm_name, "install_fio", args)

    def _set_up_host(self, host_name, args):
        # BEFORE the VM boots up, this function will be Popened to prepare 
        # the host.
        # Tasks could include creating VM, configuring VM and install host 
        # software.
        pass

    def install_fio(self, args):
        logfile = open(os.path.join(args['remote_path'], 'install-fio.log'), 'w')

        if 'FreeBSD' in args['version']:
            subprocess.Popen(['pkg', 'install', '-y', 'git'],
                        stdout = logfile,
                        stderr = logfile).wait()

            subprocess.Popen(['pkg', 'install', '-y', 'gmake'],
                        stdout = logfile,
                        stderr = logfile).wait()


        os.chdir(args['remote_path'])

        subprocess.Popen(['git', 'clone', 'https://github.com/axboe/fio.git'], 
                        stdout = logfile, stderr = logfile).wait()


        os.chdir(os.path.join(args['remote_path'], 'fio'))

        make_cmd = 'make'
        if 'FreeBSD' in args['version']:
            make_cmd = 'gmake'
        subprocess.Popen([make_cmd], stdout = logfile, stderr = logfile).wait()

        subprocess.Popen([make_cmd, 'install'], stdout = logfile, stderr = logfile).wait()

        os.chdir(args['remote_path'])

        logfile.close()

    def run_fio(self, args):
        hostname = socket.gethostname()

        iodepth = args['iodepth']
        numjobs = args['numjobs']
        runtime = args['runtime']
        device = args['perf_drive']
        count = args['count']

        for block_size, mix_read, mix_write in args['run_param']:
            test_name = '%s-%dk-%d-%d-%d-test' % (hostname, block_size, mix_read, mix_write, count),

            subprocess.call(['fio', 
                            '--direct=1',
                            '--rw=randrw',
                            '--iodepth=%d' % iodepth,
                            '--numjobs=%d' % numjobs,
                            '--runtime=%d' % runtime,
                            '--group_reporting',
                            '--norandommap',
                            '--randrepeat=0',
                            '--ioengine=posixaio',
                            '--refill_buffers',
                            '--filename=/dev/%s' % device,
                            '--rwmixread=%d' % mix_read,
                            '--rwmixwrite=%d' % mix_write,
                            '--bs=%dk' % block_size,
                            '--name=%s' % test_name,
                            '--output=%s.log' % test_name,
                            '--minimal'])


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
                    test_class._run_on_vm(self, vm['name'], 'run_fio', args)

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

