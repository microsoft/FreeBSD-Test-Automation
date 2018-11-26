#!/usr/bin/env python

import Pyro4
import time

class TestClass(object):
    def __init__(self):
        pass

    def _set_up_vm(self, args):
        pass

    def _set_up_host(self, args):
        pass

    def _run(self, args):
        pass

    def _tear_down(self, args):
        pass

    def _request_machines(self):
        pass

    def _test_param(self, args):
        param = {
                "machines": self._machines
                }

        return param

    def _set_machines(self, machines):
        self._machines = machines

    def _set_script(self, script_name):
        self._script = script_name

def _run_on_vm(self, vm_name, func, args):
    nameserver = Pyro4.locateNS(host=args['name_server'])
    uri = nameserver.lookup('runner.%s.%s' % (vm_name, self.__class__.__name__))
    tc = Pyro4.Proxy(uri)
    return getattr(tc, func)(args)

def _run_on_host(self, host_name, func, args):
    # for now let's just use WMI to invoke methods on the hosts
    # until I figure out a better way to deploy scripts on Windows
    raise NotImplementedError

def _run_on_windows(self, vm, cmd):
    import wmi
    c = wmi.WMI(vm['ctrl_ip'], user='.\\' + vm['username'], password=vm['password'])

    pid, result = c.Win32_Process.Create(cmd)

    assert result == 0

    # wait on PID
    p = c.Win32_Process(ProcessID = pid)
    while len(p) > 0:
        time.sleep(1)
        p = c.Win32_Process(ProcessID = pid)

    return result
