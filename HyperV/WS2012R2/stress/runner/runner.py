#!/usr/bin/env python

import sys
import time

import Pyro4
import importlib
import inspect

import daemon

def runner(vm_name, module_name, ip_addr, name_server):
    # import from custom test script
    importlib.import_module(module_name)

    test_class = inspect.getmembers(sys.modules[module_name], inspect.isclass)[0][1]

    test_inst = test_class()

    Pyro4.config.HOST = ip_addr

    daemon=Pyro4.Daemon()
    ns = Pyro4.locateNS(host=name_server)
    uri = daemon.register(test_inst)

    print 'Registered URI: "%s"' % uri

    obj_path = "runner.%s.%s" % (vm_name, module_name)

    # try to lookup the name if already exist

    is_exist = True
    try:
        print 'Looking up existing object'
        old_uri = ns.lookup(obj_path)
        print 'Found existing object: "%s"', old_uri
    except Pyro4.errors.NamingError:
        # the object doesn't exist
        is_exist = False

    if is_exist:
        print 'Object already exist on NS, removing...'
        ns.remove(obj_path)

    ns.register(obj_path, uri)
    print 'Object registered as "%s"' % obj_path

    print 'Initiating request loop'
    daemon.requestLoop()

def run():
    vm_name     = sys.argv[1]
    module_name = sys.argv[2]
    ip_addr     = sys.argv[3]
    name_server = sys.argv[4]

    print 'Running %s in background...' % module_name
    with daemon.DaemonContext():
        runner(vm_name, module_name, ip_addr, name_server)

if __name__=='__main__':
    assert len(sys.argv) == 5

    run()
