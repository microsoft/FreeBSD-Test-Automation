#!/usr/bin/env python

import sys

sys.path.append("../runner")

import runner

def test_init_vm():
	param = {
			'ssh_key_file': 'rhel5_id_rsa',
			'snapshot': 'ICABase'
			}

	runner.init_vm('FreeBSD10-TEST-2', '.', param)

if __name__ == '__main__':
    r = runner.Runner()
	#test_init_vm()
