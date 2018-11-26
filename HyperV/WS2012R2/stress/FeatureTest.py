#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess

class FeatureTest(test_class.TestClass):
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

    def run_heartbeat(self, args):
        import hypervlib.hyperv

        for host in self._machines:
            host_name = host['host']

            for vm in host['vms']:
                vm_name = vm['name']

                print 'Querying VM "%s" for heartbeat status:' % vm_name
                
                op_status, co_status = hypervlib.hyperv.get_heartbeat_status(vm_name, 
                                                                             host_name)

                if op_status == hypervlib.hyperv.VM_HEARTBEAT_OK:
                    print 'Heartbeat OK'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_DEGRADED:
                    print 'Heartbeat OK (Degraded)'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_ERROR:
                    print 'ERROR: Heartbeat - Non-recoverable'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_NO_CONTACT:
                    print 'ERROR: Heartbeat - No Contact'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_LOST_COMM:
                    print 'ERROR: Heartbeat - Lost Communication'
                elif op_status == hypervlib.hyperv.VM_HEARTBEAT_PAUSED:
                    vm_status = hypervlib.hyperv.get_vm_state(vm_name, host_name)
                    if vm_status == VM_STATE_PAUSED:
                        print 'Heartbeat OK - VM Paused'
                    else:
                        print 'ERROR: Heartbeat - Paused but VM is not paused'

    def _prepare_xml(self, args):
        import xml.etree.ElementTree as ET
        import xml.dom.minidom as MD

        param = self._test_param(args)

        abs_path = os.path.join(param['LisaDir'], param['ConfigXML'])

        tree = ET.parse(abs_path)
        root = tree.getroot()

        # edit email
        root.find('global').find('email').find('sender').text = param['email_sender']

        root.find('global').find('email').remove(
                root.find('global').find('email').find('recipients')
                )

        root.find('global').find('email').append(ET.Element('recipients'))

        for r in param['email_recipients']:
            el = ET.SubElement(root.find('global').find('email').find('recipients'), 'to')
            el.text = r

        # edit testparam
        root.find('global').remove(
                root.find('global').find('testparams')
                )

        root.find('global').append(ET.Element('testparams'))
        for k, v in param['testparam'].iteritems():
            el = ET.SubElement(root.find('global').find('testparams'), 'param')
            el.text = "%s=%s" % (k, v)

        # edit VM
        root.find('VMs').find('vm').find('hvServer').text = args['host_name']
        root.find('VMs').find('vm').find('vmName').text = args['vm_name']
        root.find('VMs').find('vm').find('os').text = param['OS']
        root.find('VMs').find('vm').find('ipv4').text = args['vm_addr']
        root.find('VMs').find('vm').find('sshKey').text = param['ssh_key_file']

        tree.write(abs_path)


    def _run(self, args):
        host_one = self._machines[0]['host']
        vm_one = self._machines[0]['vms'][0]['name']

        args['host_name'] = host_one
        args['vm_name'] = vm_one
        args['vm_addr'] = self._machines[0]['vms'][0]['addr']

        # prepare the config XML file to point to the allocated host and VM
        self._prepare_xml(args)

        # execute LISA
        logfile = open('lisa.log', 'w')

        param = self._test_param(args)
        p = subprocess.Popen(['powershell.exe', 
                              os.path.join(param['LisaDir'], 'lisa.ps1'), 
                              'run', os.path.join(param['LisaDir'], param['ConfigXML']),
                              '-dbgLevel', '5',
                              '-email'], 
                              stdout=logfile, 
                              stderr=logfile)
        p.wait()

    def _tear_down(self, args): 
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # only 1 VM on 1 host is required
        request = {'pool': 'stress', 
                   'desc': 'feature', 
                   'req': [1]
                   }

        return request

    def _test_param(self, args):
        param = {
            'multi-threaded': True,
            'snapshot': 'ICABase',
            'remote_path': '/root/',
            'OS': 'FreeBSD',

            'LisaDir': '../lisa',
            'ConfigXML': 'xml/freebsd/FreeBSD-10.0-amd64.xml',

            'email_recipients': ['xiazhang@microsoft.com'],
            'email_sender': 'xiazhang@microsoft.com',

            'testparam': {
                'REPOSITORY_SERVER': '10.156.76.149',
                'REPOSITORY_EXPORT': '/usr/lisa/public',
                'NFS_SERVER': '10.156.76.149',
                'NFS_EXPORT': '/usr/lisa/public',
                'RootDir': 'C:\\code\\',
                'TARGET_ADDR': '10.200.50.108',
                'DEBUG': '0'
                }
            }
        return param 

