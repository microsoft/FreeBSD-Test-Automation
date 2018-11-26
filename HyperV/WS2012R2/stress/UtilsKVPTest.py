#!/usr/bin/env python
import sys
import os
import time

import test_class

import subprocess

import random
import string

MAX_KVP_COUNT = 8
MAX_KVP_KEY_LENGTH = 512 
MAX_KVP_VALUE_LENGTH = 2048
KVP_POOL_FILE_PREFIX = '/usr/local/hyperv/pool/.kvp_pool_'
DEFAULT_USER_POOL = 0

class UtilsKVPTest(test_class.TestClass):
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

    def str_generator(self, length):
        return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(length))

    def write_from_host(self, args):
        import hypervlib.hyperv
        count = random.randint(1, MAX_KVP_COUNT)

        vm_name = args['vm_name']
        host_name = args['host_name']

        kvps = {}
        for i in range(count):
            key_len = random.randint(1, MAX_KVP_KEY_LENGTH)
            value_len = random.randint(1, MAX_KVP_VALUE_LENGTH)

            # FIXME: need to figure out the exact length of key and value
            kvp_key = self.str_generator(key_len / 2)
            kvp_value = self.str_generator(value_len / 2)

            print 'Writing KVP item to VM "%s" (%s, %s)' % (vm_name, kvp_key, kvp_value)
            if not hypervlib.hyperv.add_kvp_item(kvp_key, kvp_value, vm_name, host_name):
                print 'Error while writing KVP data'
                return None
            kvps[kvp_key] = kvp_value

        return kvps

    def read_bytes(self, pool):
        pool_file = KVP_POOL_FILE_PREFIX + str(pool)
        with open(pool_file, 'r') as f:
            c = f.read()
            f.close()

        return bytes(c)

    def bytes_to_str(self, b, start, end):
        buf = None
        for i in range(start, end):
            if ord(b[i]) == 0:
                buf = bytearray(i - start)
                buf[:] = b[start : i]
                break
        if (buf):
            return buf.decode('utf-8')
        return None

    def read_raw_kvp(self, pool):
        b = self.read_bytes(pool)
        key_start = 0
        val_start = 512
        step = MAX_KVP_KEY_LENGTH + MAX_KVP_VALUE_LENGTH
        data = {}
        while val_start < len(b):
            key = self.bytes_to_str(b, key_start, key_start + MAX_KVP_KEY_LENGTH)
            val = self.bytes_to_str(b, val_start, val_start + MAX_KVP_VALUE_LENGTH)
            data[key] = val
            key_start += step
            val_start += step
        return data

    def match_in_client(self, args):
        logfile = open('kvp.log', 'w')
        data = self.read_raw_kvp(DEFAULT_USER_POOL)
        logfile.write("===ACTUAL===")
        logfile.write(str(data))
        expected_data = args['kvp']
        logfile.write("===EXPECTED===")
        logfile.write(str(expected_data))
        for kvp_key, kvp_value in expected_data.iteritems():
            if kvp_key in data:
                if data[kvp_key] != expected_data[kvp_key]:
                    logfile.write('===MISMATCH===\n')
                    logfile.write('---ACTUAL---\n')
                    logfile.write(data[kvp_key] + '\n')
                    logfile.write('---EXPECTED---\n')
                    logfile.write(expected_data[kvp_key] + '\n')
                    logfile.close()
                    return False
            else:
                logfile.write('NOT FOUND: ' + kvp_key)
                logfile.close()
                return False
        return True


    def run_write_kvp(self, args):
        import hypervlib.hyperv

        for host in self._machines:
            host_name = host['host']

            args['host_name'] = host_name
            for vm in host['vms']:
                vm_name = vm['name']
                args['vm_name'] = vm_name

                written_kvps = self.write_from_host(args)
                if written_kvps is None:
                    print 'ERROR: failed to write KVP to host'
                    return 

                args['kvp'] = written_kvps

                match = test_class._run_on_vm(self, vm_name, "match_in_client", args)

                # remove the random data, we don't want KVP pool file to be flooded.
                if not match:
                    print 'ERROR: failed to add KVP item'

                print 'Removing test KVP items'
                for kvp_key in written_kvps.keys():
                    hypervlib.hyperv.remove_kvp_item(kvp_key, vm_name, host_name)

    def _run(self, args):
        self.run_write_kvp(args)

    def _tear_down(self, args): 
        pass

    def _request_machines(self):
        # EXAMPLE: requesting machines from pool
        # the size of the request array will be the number of hosts
        # required, and each array element indicates how many VMs are 
        # required on that host.

        # only 1 VM on 1 host is required
        request = {'pool': 'stress', 
                   'desc': 'utils_KVP', 
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

