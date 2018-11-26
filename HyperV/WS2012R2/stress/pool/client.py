#!/usr/bin/env python

# This script is used to configure the machine pool.
# stress.py will use the pool created by this script to automatically allocate
# machines (including VMs and Hosts) from the pool.
#
# Usage:
#   python pool.py list|add|remove|update -p <pool_id> -m <host_name> -v <VM_name> 

import sys
import os
import argparse

import sqlite3

POOL_DB_DIR = 'pool'
POOL_DB_FILE = 'machines'
DEFAULT_POOL = '_default'

conn = sqlite3.connect(os.path.join(POOL_DB_DIR, POOL_DB_FILE))
conn.row_factory = sqlite3.Row

def build_arg_parser():
    parser = argparse.ArgumentParser(description='This script is used to configure the machine pool.\n' + \
                'stress.py will use the pool created by this script to automatically allocate\n' + \
                'machines (including VMs and Hosts) from the pool.\n',
                add_help=True)
    parser.add_argument('action', choices=['init', 'list', 'add', 'remove', 'update'])
    parser.add_argument('-p', metavar='pool_id', dest='pool_id', help='ID of the machine pool')
    parser.add_argument('--host', metavar='host_name', dest='host_name', help='Name of the Host machine')
    parser.add_argument('--vm', metavar='vm_name', dest='vm_name', help='Name of the VM')
    parser.add_argument('-a', metavar='ip_addr', dest='ip_addr', help='IP address of the machine')
    parser.add_argument('-v', metavar='version', dest='version', help='Version of the machine OS')
    parser.add_argument('--cpu', metavar='cpu', dest='cpu', help='Count of logical processors')
    parser.add_argument('--mem', metavar='memory', dest='mem', help='Size of the physical memory')
    parser.add_argument('-d', metavar='desc', dest='desc', help='Assign job description')

    return parser

def init_pools(args):
    c = conn.cursor()
    c.execute('''CREATE TABLE pools (name text)''')
    c.execute('''CREATE TABLE hosts (pool text, name text, ipaddr text, version text, cpu integer, mem integer)''')
    c.execute('''CREATE TABLE vms (pool text, name text, hostname text, ipaddr text, version text, cpu integer, mem integer, desc text)''')

    # create the default pool
    c.execute("INSERT INTO pools VALUES (?)", (DEFAULT_POOL,))

def list_vm(host_name):
    c = conn.cursor()
    c.execute('SELECT * FROM vms WHERE hostname="%s"' % host_name)
    vms = c.fetchall()
    print '\t\tVM:'
    for vm in vms:
        print '\t\t\tName:\t%s' % vm['name']
        print '\t\t\tIP Address:\t%s' % vm['ipaddr']
        print '\t\t\tOS Version:\t%s' % vm['version']
        print '\t\t\tCPU Core:\t%s' % vm['cpu']
        print '\t\t\tPhysical Memory:\t%s' % vm['mem']
        print '\t\t\tJob Description:\t%s' % vm['desc']
        print '\t\t\t'


def list_pool(pool_id):
    c = conn.cursor()
    print "POOL: %s" % pool_id
    c.execute('SELECT * FROM hosts WHERE pool="%s"' % pool_id)
    hosts = c.fetchall()
    print "\tHosts:"
    for h in hosts:
        print '\t\tName:\t%s' % h['name']
        print '\t\tIP Address:\t%s' % h['ipaddr']
        print '\t\tOS Version:\t%s' % h['version']
        print '\t\tCPU Core:\t%s' % h['cpu']
        print '\t\tPhysical Memory:\t%s' % h['mem']
        print '\t\t'
        list_vm(h['name'])


def list_action(args):
    c = conn.cursor()
    if args.pool_id is None:
        # list all pools
        print "Listing all pools"
        c.execute("SELECT name FROM pools")
        pools = c.fetchall()
        for p in pools:
            list_pool(p['name'])


def add_action(args):
    print "Adding"
    c = conn.cursor()

    pool = DEFAULT_POOL

    # Add new pool
    if args.pool_id is not None:
        # verify if the pool already exists
        c.execute("SELECT COUNT(*) FROM pools WHERE name=?", (args.pool_id,))
        count = c.fetchone()
        
        if count[0] == 0:
            print 'Pool "%s" does not exist, adding now.' % args.pool_id
            c.execute("INSERT INTO pools VALUES (?)", (args.pool_id,))
        pool = args.pool_id

    # Add new VM
    if args.vm_name is not None:
        # first check if the host exists
        c.execute("SELECT COUNT(*) FROM hosts WHERE name=?", (args.host_name,))
        count = c.fetchone()

        if count[0] == 0:
            raise Exception('Host "%s" does not exists!' % args.host_name)

        c.execute("SELECT COUNT(*) FROM vms WHERE name=?", (args.vm_name,))
        count = c.fetchone()

        if count[0] != 0:
            raise Exception('VM "%s" already exists!' % args.vm_name)

        c.execute("INSERT INTO vms VALUES (?, ?, ?, ?, ?, ?, ?, ?)", (pool, args.vm_name, args.host_name, args.ip_addr, args.version, int(args.cpu), int(args.mem), args.desc)) 
        print 'New VM "%s" added.' % args.vm_name
    elif args.host_name is not None:
        # Add new host machine
        c.execute("SELECT COUNT(*) FROM hosts WHERE name=?", (args.host_name,))
        count = c.fetchone()

        if count[0] != 0:
            raise Exception('Host "%s" already exists!' % args.host_name)

        c.execute("INSERT INTO hosts VALUES (?, ?, ?, ?, ?, ?)", (pool, args.host_name, args.ip_addr, args.version, int(args.cpu), int(args.mem))) 
        print 'New host "%s" added.' % args.host_name

def remove_vm(vm_name):
    c.execute("SELECT name, dest FROM vms WHERE name=?", (vm_name,))
    vm = c.fetchone()

    desc = vm['desc']
    if len(desc) > 0:
        print 'Error: VM %s is in use: "%s". Please release it before removing' % (vm_name, desc)
    else:
        # remove the vm
        c.execute("DELETE FROM vms WHERE name=?", (vm_name,))


def remove_host(host_name):
    # remove a host
    # first remove all VMs on the host

    # to remove the VM, we need to make sure they are not in use
    c.execute("SELECT COUNT(*) FROM vms WHERE desc <> ''")
    count = c.fetchone()[0]

    if count > 0:
        print 'Error: In-use VM on host "%s" detected, aborting...'
        return
    
    c.execute("SELECT name FROM vms WHERE hostname=?", (host_name,))
    vms = c.fetchall()
    for vm in vms:
        remove_vm(vm['name'])

    c.execute("DELETE FROM hosts WHERE name=?", (args.host_name,))


def remove_action(args):
    print "Removing"
    c = conn.cursor()

    if args.vm_name is not None:
        # remove a VM
        remove_vm(args.vm_name)

    if args.host_name is not None:
        remove_host(args.host_name)

    # removing a pool
    if args.pool_id is not None and args.host_name is None and args.vm_name is None:
        c.execute("SELECT COUNT(*) FROM pools WHERE name=?", (args.pool_id,))
        count = c.fetchone()[0]

        if count > 0:
            # non-empty pool
            # in this case the machines in this pool will not be removed,
            # instead they will be moved to the default pool
            print "Pool %s is not empty, moving all machines in this pool first..." % args.pool_id
            c.execute("UPDATE hosts SET pool=? WHERE pool=?", (DEFAULT_POOL, args.pool_id))
            c.execute("UPDATE vms SET pool=? WHERE pool=?", (DEFAULT_POOL, args.pool_id))

        c.execute("DELETE FROM pools WHERE name=?", (args.pool_id,))


def update_action(args):
    print "Updating"
    c = conn.cursor()

    if args.vm_name is not None:
        c.execute("SELECT * FROM vms WHERE name=?", (args.vm_name,))
        vm = c.fetchone()
        pool = vm['pool'] if args.pool_id is None else args.pool_id
        ipaddr = vm['ipaddr'] if args.ip_addr is None else args.ip_addr
        version = vm['version'] if args.version is None else args.version
        cpu = vm['cpu'] if args.cpu is None else args.cpu
        mem = vm['mem'] if args.mem is None else args.mem

        hostname = vm['hostname'] if args.host_name is None else args.host_name
        desc = vm['desc'] if args.desc is None else args.desc

        c.execute("UPDATE vms SET pool=?, hostname=?, ipaddr=?, version=?, cpu=?, mem=?, desc=? WHERE name=?", 
                (pool, hostname, ipaddr, version, cpu, mem, desc, args.vm_name))
    elif args.host_name is not None:
        c.execute("SELECT * FROM hosts WHERE name=?", (args.host_name,))
        host = c.fetchone()
        pool = host['pool'] if args.pool_id is None else args.pool_id
        ipaddr = host['ipaddr'] if args.ip_addr is None else args.ip_addr
        version = host['version'] if args.version is None else args.version
        cpu = host['cpu'] if args.cpu is None else args.cpu
        mem = host['mem'] if args.mem is None else args.mem

        c.execute("UPDATE hosts SET pool=?, ipaddr=?, version=?, cpu=?, mem=? WHERE name=?", 
                (pool, ipaddr, version, cpu, mem, args.host_name))

def request_machines(req):
    # find machines in given machine pool, according to requirement
    # EXAMPLE: requesting machines from pool
    # the size of the request array will be the number of hosts required,
    # and each array element indicates how many VMs are required on that host.

    # in this example, this test case will require 2 hosts, each host
    # should provide one VM.
    #   request = {"pool": "pool_name", "desc": "some desc text", "req": [1, 1]}
    req_idx = 0
    all_req_met = False

    req_pool = req['pool']
    req_desc = req['desc']
    req_arr = req['req']
 
    # first, find all available hosts in the pool
    c = conn.cursor()
    c.execute("SELECT name FROM hosts WHERE pool=?", (req_pool,))
    hosts = c.fetchall()

    # locate the nameserver of the pool
    c.execute("SELECT addr FROM nameserver WHERE name IS (SELECT nameserver FROM pools WHERE name=?)", (req_pool,))
    nameserver = c.fetchone()['addr']

    # return value
    # EXAMPLE:
    # ret = [{'host': 'test-host-1', 'vms': [{'name': 'test-vm-1', 'addr': '192.168.0.1'}, {'name': 'test-vm-2', 'addr': '192.168.0.2'}]},
    #        {'host': 'test-host-1', 'vms': [{'name': 'test-vm-1', 'addr': '192.168.0.1'}, {'name': 'test-vm-2', 'addr': '192.168.0.2'}]}]
    ret = []

    get_all = False

    for host in hosts:
        # in each host, find if it can meet the VM requirement
        # i.e., have enough VM as per the req

        ret_host = {'host': host['name'], 'vms': []}

        vm_req = req_arr[req_idx]

        c.execute("SELECT * FROM vms WHERE pool=? AND hostname=? AND (desc IS NULL OR desc = '')", (req_pool, host['name']))
        vms = c.fetchall()

        # set vm_req to 0 to get all VMs in the pool
        if vm_req == 0:
	    get_all = True

        if len(vms) >= vm_req or get_all == True:
	    if get_all == True:
	        vm_req = len(vms)

            # select the first # of VMs in the result set
            for i in range(vm_req):
                # FIXME: running the following will cause the machine to be *exclusively* occupied 
                # by one test case.
                # c.execute('UPDATE vms SET desc=? WHERE name=?', (req_desc, vms[i]['name']))
                # conn.commit()
                ret_host['vms'].append({'name' : vms[i]['name'], 
                                        'addr' : vms[i]['ipaddr'], 
                                        'addr6' : vms[i]['ipaddr6'],
                                        'ctrl_ip' : vms[i]['ctrl_ip'],
                                        'username' : vms[i]['username'],
                                        'password' : vms[i]['password'],
                                        'perf_drive' : vms[i]['perf_drive'],
					                    'version' : vms[i]['version'],
                                        'name_server' : nameserver
                                        })
            ret.append(ret_host)
        else:
            continue

        if get_all == True:
	    all_req_met = True
	    continue

        # requirement met
        req_idx = req_idx + 1
        if req_idx >= len(req_arr):
            # all requirement met
            all_req_met = True
            break

    if all_req_met == False:
        return None

    return ret

def release_machines(machines):
    # EXAMPLE:
    # machines = [{'host': 'test-host-1', 'vms': ['test-vm-1', 'test-vm-2']},
    #             {'host': 'test-host-2', 'vms': ['test-vm-3', 'test-vm-4']}]
    '''
    c = conn.cursor()
    for host in machines:
        host_name = host['host']
        vms = host['vms']
        for vm in vms:
            c.execute('UPDATE vms SET desc=NULL WHERE name=?', (vm,))
    conn.commit()
    '''
    pass

ACTIONS_FUNC = {
        'init': init_pools,
        'list': list_action,
        'add': add_action,
        'remove': remove_action,
        'update': update_action,
        }

if __name__ == "__main__":
    # parse command line argument
    parser = build_arg_parser()
    args = parser.parse_args()

    ACTIONS_FUNC[args.action](args)

    conn.commit()
    conn.close()
