#!/usr/bin/env python
import sys
import os
import time
import datetime
import calendar

import test_class

import subprocess

class UtilsTimeSyncTest(test_class.TestClass):
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

    def get_bsd_time(self, args):
        return calendar.timegm(datetime.datetime.utcnow().utctimetuple())

    def get_host_time(self, args):
        import wmi
        c = wmi.WMI(moniker="//" + args['host_name'] + '/root/cimv2')

        t = c.Win32_UTCTime()[0]

        hstm = datetime.datetime(year = t.Year,
                                 month = t.Month, 
                                 day = t.Day, 
                                 hour = t.Hour, 
                                 minute = t.Minute, 
                                 second = t.Second)
        return calendar.timegm(hstm.utctimetuple())

    def _run(self, args):

        for host in self._machines:
            host_name = host['host']

            # get host time
            # since we don't implement _run_on_host just yet, we'll have to do
            # this using WMI
            args['host_name'] = host_name
            host_time = self.get_host_time(args)

            for vm in host['vms']:
                vm_name = vm['name']

                # get VM time
                vm_time = test_class._run_on_vm(self, vm_name, "get_bsd_time", args)

                delta = abs(vm_time - host_time)
                print 'Time diff between host "%s" and VM "%s" is' % (host_name, vm_name), \
                      delta, 'seconds'

    def _tear_down(self, args): 
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # only 1 VM on 1 host is required
        request = {'pool': 'stress', 
                   'desc': 'utils_TimeSync', 
                   'req': [1]
                   }

        return request

    def _test_param(self, args):
        param = {
            'multi-threaded': True,
            'snapshot': 'ICABase',
            'remote_path': '/root/'
            }
        return param 

