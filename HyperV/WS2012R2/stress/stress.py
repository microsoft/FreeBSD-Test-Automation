#!/usr/bin/env python

# This script serves as the main entry of the stress test
# workload generator.
#
# Usage:
#   python stress.py -c <case_file_list> -m <mode> -i <interval> -p <pattern> -a <cycle_alpha> -b <cycle_beta> -l <pool>
#
#       -c <case_list>      : Specify the stress test case files to run, each case is separated by a comma (,).
#                             Each case should have a folder with corresponding name placed along with stress.py
#       -m <mode>           : Specify the stress mode, options are:
#                               oneshot
#                               repeat
#       -d <duration>       : total time of execution
#       -i <interval>       : To be used in conjunction with -m repeat, indicates in seconds how often the test will
#                             be executed.
#                             NOTE: The test will be executed when the timer expires, and if there are more
#                             than one test in case_list, all tests will be executed sequentially.
#       -p <pattern>        : Specify which pattern to use. Available patterns are:
#                               always_on   (default pattern, will be used if -p is not specified)
#                               vm_cycle
#                               host_cycle
#       -a <cycle_alpha>    : Specify Alpha (ON) cycle length, accepts same interval format as -i
#       -b <cycle_beta>     : Specify Beta (OFF) cycle length, accepts same interval format as -i
#       -l <pool>           : Specify the machine pool in which the tests will run. The pool can be configured using pool.py

import sys
import argparse
import inspect
import importlib
import os
import time
import traceback
import logging
import distutils.dir_util

import paramiko

import pool.client
import runner
import runner.utils
import hypervlib

import gc

import Pyro4

# use colorama to add color to the output
from colorlog import ColoredFormatter

logger = logging.getLogger('stress')
logger.setLevel(logging.INFO)

ch = logging.StreamHandler()
ch.setLevel(logging.INFO)

formatter = ColoredFormatter(
        '%(log_color)s %(asctime)s - %(levelname)-8s%(reset)s %(message)s',
        datefmt='%m/%d/%Y %I:%M:%S %p',
        reset=True,
        log_colors={
            'DEBUG':    'cyan',
            'INFO':     'green',
            'WARNING':  'yellow',
            'ERROR':    'red',
            'CRITICAL': 'red',
            }
        )

ch.setFormatter(formatter)
logger.addHandler(ch)

# disable paramiko INFO logger
logging.getLogger('paramiko').setLevel(logging.WARNING)

RUN_MODE_ONESHOT = 'oneshot'
RUN_MODE_REPEAT = 'repeat'

RUN_PATTERN_ALWAYS_ON = 'always_on'
RUN_PATTERN_VM_CYCLE = 'vm_cycle'
RUN_PATTERN_HOST_CYCLE = 'host_cycle'

PYRO_WAIT_TIME = 5

def build_arg_parser():
    parser = argparse.ArgumentParser(description='This script serves as the main entry of the stress test workload generator.', add_help=True)
    parser.add_argument('-c', metavar='case_list', dest='case_list', help='Specify the stress test cases to run, each case is separated by a comma (,).')
    parser.add_argument('-m', metavar='mode', dest='mode', help='Specify the stress mode, options are:\noneshot\nrepeat')
    parser.add_argument('-i', metavar='interval', dest='interval', help='To be used in conjunction with -m repeat, indicates how often (in seconds) the test will\nbe executed. \nNOTE: The test will be executed when the timer expires, and if there are more\nthan one test in case_list, all tests will be executed sequentially.')
    parser.add_argument('-p', metavar='pattern', dest='pattern', help='Specify which pattern to use. Available patterns are:\nalways_on   (default pattern, will be used if -p is not specified)\nvm_cycle\nhost_cycle')
    parser.add_argument('-a', metavar='cycle_alpha', dest='cycle_alpha', help='Specify Alpha (ON) cycle length, accepts same interval format as -i')
    parser.add_argument('-b', metavar='cycle_beta', dest='cycle_beta', help='Specify Beta (OFF) cycle length, accepts same interval format as -i')
    parser.add_argument('-l', metavar='pool', dest='pool', help='Specify the machine pool in which the tests will run. The pool can be configured using pool.py')
    parser.add_argument('-d', metavar='duration', dest='duration', help='Total time of execution in seconds')
    return parser

# to run pyro on VM, we'll need a runner script, plus the script that
# contains the test code.
# the runner script will import the test script, and spin up a pyro server
def deploy_test_script(vm_name, ip_addr, test_case, params):
    logger.info('Preparing test VM: "%s"' % vm_name)
    DEFAULT_RUNNER_DIR = 'runner'
    DEFAULT_RUNNER_SCRIPT = 'runner.py'
    DEFAULT_TEST_CLASS_SCRIPT = 'test_class.py'
    GET_PIP_SCRIPT = 'get-pip.py'
    DEPLOY_SCRIPT_DIR = 'deploy'

    s = paramiko.client.SSHClient()
    s.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())
    s.connect(ip_addr, 22, username=params['username'], password=params['password'])

    sftp = s.open_sftp()

    script = test_case.__class__.__name__ + '.py'
    logger.info("Deploying script %s" % script)

    sftp.put(script, os.path.join(params['remote_path'], script))
    sftp.put(os.path.join(DEFAULT_RUNNER_DIR, DEFAULT_RUNNER_SCRIPT), 
             os.path.join(params['remote_path'], DEFAULT_RUNNER_SCRIPT))
    sftp.put(DEFAULT_TEST_CLASS_SCRIPT, os.path.join(params['remote_path'], DEFAULT_TEST_CLASS_SCRIPT))

    remote_runner_script = os.path.join(params['remote_path'], DEFAULT_RUNNER_SCRIPT)

    logger.info('Installing remote python packages...')

    # deploy get-pip.py
    sftp.put(os.path.join(DEPLOY_SCRIPT_DIR, GET_PIP_SCRIPT),
             os.path.join(params['remote_path'], GET_PIP_SCRIPT))


    python_cmd = 'python %s' % (os.path.join(params['remote_path'], GET_PIP_SCRIPT))

    logger.debug('Python command: %s' % python_cmd)

    stdin, stdout, stderr = s.exec_command(python_cmd)

    logger.debug(stdout.readlines())
    logger.debug(stderr.readlines())

    # install Pyro4
    logger.debug('Installing Pyro4')
    stdin, stdout, stderr = s.exec_command('pip install Pyro4')

    logger.debug(stdout.readlines())
    logger.debug(stderr.readlines())

    # install python-daemon
    logger.debug('Installing python-daemon')
    stdin, stdout, stderr = s.exec_command('pip install python-daemon')

    logger.debug(stdout.readlines())
    logger.debug(stderr.readlines())


    # start the pyro server on the VM
    # kill all running pythons on FreeBSD
    #s.exec_command('killall -9 python2.7')

    # python runner.py test_case1.py <VM_IP_ADDR> <NS_IP_ADDR>
    logger.info('Starting remote runner daemon...')
    python_cmd = 'python %s %s %s %s %s' % (remote_runner_script, 
                                            vm_name, 
                                            test_case.__class__.__name__, 
                                            ip_addr, 
                                            params['name_server']
                                            )

    logger.debug("Python command: %s" % python_cmd)

    stdin, stdout, stderr = s.exec_command(python_cmd)

    logger.debug(stdout.readlines())
    logger.debug(stderr.readlines())

    # seems Pyro server need some time to initialize (talk to the NS),
    # so we give it some time to warm up
    time.sleep(PYRO_WAIT_TIME)

def prepare_test_runs(cases, args):
    test_runs = []
    for c in cases:
        # FIXME: we assume all cases are located in the same location as this script
        importlib.import_module(c)
        test_classes_pair = inspect.getmembers(sys.modules[c], inspect.isclass)

        assert len(test_classes_pair) == 1
        c = test_classes_pair[0][1]

        t = c()

        logger.info("Found test case: %s" % t.__class__.__name__)

        # get the requirement from the test case
        machine_request = t._request_machines()

        # override pool if "-l" was given
        if args.pool is not None:
            machine_request['pool'] = args.pool

        logger.debug("Machine request is: %s" % machine_request)

        # assign machines from machine pool
        machines = pool.client.request_machines(machine_request)

        # if the requirement cannot be satisfied, 
        # abort all tests and let the user know
        if machines == None:
            logger.error("Error: no available machines for test. Aborting...")
            exit(1)

        logger.info('Assigned machines:')
        
        for host in machines:
            for vm in host['vms']:
                logger.info('\t"%s" on "%s"' % (vm['name'], host['host'])) 

        t._set_machines(machines)
        test_runs.append(t)
    return test_runs

def run_test_once(tc_queue, interval):
    if interval > 0:
        logger.info('==== INTERVAL ====')
        logger.info('Sleeping for %d seconds before running test...' % interval)
    for i in range(interval):
        print interval - i,
        time.sleep(1)

    logger.info('Running test...')
    for tc, tc_param in tc_queue:
        logger.info('Current Test: %s' % tc.__class__.__name__)
        tc._run(tc_param)
    logger.info('Test complete.')

def run_interval(tc_queue, interval, duration):
    total_time = 0.0
    logger.info('=== ALPHA ===')
    while True:
        run_start = time.clock()
        run_test_once(tc_queue, interval)
        run_stop = time.clock()

        run_time = run_stop - run_start

        total_time += run_time

        logger.info('run_interval: run_time: %f, total_time: %f' % (run_time, total_time))

        if total_time >= duration:
            break
    return total_time

def vm_cycle(tc_queue, alpha, beta, interval):
    run_time = run_interval(tc_queue, interval, alpha)

    # save the VM
    # in fact, save all the VMs in the assigned machine list
    machines = []
    for func, param in tc_queue:
        machines.extend(param['machines'])  # this is a response from machine pool request

    for host in machines:
        vms = host['vms']
        for vm in vms:
            if hypervlib.hyperv.save_vm(vm['name'], host['host']) == False:
                raise Exception

    logger.info('=== BETA ===')
    logger.info('Sleeping for %d seconds before resuming VM...' % beta)
    for i in range(beta):
        time.sleep(1)
        print beta - i,

    logger.info('Resuming...')

    # resume the VM
    for host in machines:
        vms = host['vms']
        for vm in vms:
            if hypervlib.hyperv.start_vm(vm['name'], host['host']) == False:
                raise Exception


def repeat_runner(tc_queue, args):
    # calculate the total duration of the running
    duration = int(args.duration)
    interval = int(args.interval)
    pattern = args.pattern
    mode = args.mode

    if pattern is None or pattern == RUN_PATTERN_ALWAYS_ON:
        # the most common ones - VM and host keeps running
        if mode == RUN_MODE_ONESHOT:
            run_test_once(tc_queue, interval)
        if mode == RUN_MODE_REPEAT:
            run_interval(tc_queue, interval, duration)
    elif pattern == RUN_PATTERN_VM_CYCLE:
        # we don't let a "oneshot" execution run in a VM cycle
        # this is just not a very popular scenario
        alpha = int(args.cycle_alpha)
        beta = int(args.cycle_beta)
        if mode == RUN_MODE_ONESHOT:
            raise NotImplementedError
        elif mode == RUN_MODE_REPEAT:
            total_time = 0.0
            while True:
                run_start = time.clock()
                vm_cycle(tc_queue, alpha, beta, interval)
                run_stop = time.clock()

                run_time = run_stop - run_start

                total_time += run_time

                logger.info('repeat_runner: run_time: %f, total_time: %f' % (run_time, total_time))

                if total_time >= duration:
                    break
        else:
            raise NotImplementedError
    elif pattern == RUN_PATTERN_HOST_CYCLE:
        raise NotImplementedError

def prepare_test_machines(test_runs):
    for tc in test_runs:
        test_param = tc._test_param(None)

        logger.debug("Test params for test: %s" % tc.__class__.__name__)
        logger.debug(test_param)

        # push the test script to VMs
        # nothing will be deployed on the host, as deploying SSH on Windows
        # machines could introduce unnecessary security screening.
        for h in tc._machines:
            host_name = h['host']

            # run custom host initialization code
            tc._set_up_host(host_name, test_param)

            vms = h['vms']
            for vm in vms:
                # boot up the VMs first and wait for IP
                vm_name = vm['name']

                # if the VM name and host name is the same
                # we assume that the VM is actually a physical machine
                if vm_name == host_name:
                    ctrl_ip = vm['ctrl_ip']
                else:
                    # we're testing against VM
                    if len(vm['ctrl_ip']) > 0:
                        ctrl_ip = vm['ctrl_ip']
                    else:
                        ctrl_ip = runner.utils.init_vm(vm_name, host_name, test_param)

                test_param['addr'] = vm['addr']
                test_param['ctrl_ip'] = ctrl_ip
                test_param['username'] = vm['username']
                test_param['password'] = vm['password']
                test_param['name_server'] = vm['name_server']
                test_param['perf_drive'] = vm['perf_drive']
                test_param['version'] = vm['version']

                # deploy the test script to VM

                # if target is a Windows machine, skip it
                if 'Windows' not in vm['version']:
                    deploy_test_script(vm_name, ctrl_ip, tc, test_param)

                # run custom VM initialization code
                logger.info('Initializing VM: "%s"' % vm_name)

                tc._set_up_vm(vm_name, test_param)


def run(test_runs):
    prepare_test_machines(test_runs)
    # after VM initialization, there should be one Pyro server running
    # the test script.

    # Actual test steps
    run_mode = args.mode

    # calculate the total duration of the running
    duration = args.duration

    # prepare the test queue
    tc_queue = []
    for tc in test_runs:
        # make assigned machines accessable to runner functions
        test_param = tc._test_param(None)
        test_param['machines'] = tc._machines

        if len(tc._machines[0]['vms']) > 0:
            # use the first name server found
            test_param['name_server'] = tc._machines[0]['vms'][0]['name_server']

        logger.debug('Test Parameters for test: %s' % tc.__class__.__name__)
        logger.debug(test_param)

        tc_item = (tc, test_param)
        tc_queue.append(tc_item)

    if run_mode == RUN_MODE_ONESHOT:
        # this will run the test *once*
        run_test_once(tc_queue, interval=0)

    elif run_mode == RUN_MODE_REPEAT:
        # run the test repeatedly
        logger.info('Repeat mode selected')
        repeat_runner(tc_queue, args)
    else:
        logger.error('Wrong mode "%s", ' \
              'please specify "oneshot" or "repeat"' % run_mode)

    # invoke tear_down methods in each test case
    for tc in test_runs:
        logger.info('Tearing down test "%s"' % tc.__class__.__name__)
        tc._tear_down(tc._test_param(None))

    # unregister Pyro object on name server
    for tc in test_runs:
        param = tc._test_param(None)

        for host in tc._machines:
            for vm in host['vms']:
                ns = Pyro4.locateNS(host=vm['name_server'])
                name = "runner.%s.%s" % (vm['name'], tc.__class__.__name__)
                logger.debug("Unregistering %s" % name)
                ns.remove(name)

def release_pyro_objects(test_runs):
    logger.info('Releasing Pyro objects...')
    for tc in test_runs:
        params = tc._test_param(None)
        for h in tc._machines:
            host_name = h['host']

            vms = h['vms']
            for vm in vms:
                vm_name = vm['name']
                if len(vm['ctrl_ip']) > 0:
                    ctrl_ip = vm['ctrl_ip']
                else:
                    ctrl_ip = runner.utils.get_ip_for_vm(vm_name, host_name)

                if 'Windows' in vm['version']:
                    continue

                s = paramiko.client.SSHClient()
                s.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())
                s.connect(ctrl_ip, 22, username=vm['username'], password=vm['password'])

                s.exec_command('killall -9 python2.7')

def wnet_connect(host, username, password):
    import win32wnet

    unc = ''.join(['\\\\', host])
    try:
        win32wnet.WNetAddConnection2(0, None, unc, None, username, password)
    except Exception, err:
        if isinstance(err, win32wnet.error):
            if err[0] == 1219:
                win32wnet.WNetCancelConnection2(unc, 0, 0)
                return wnet_connect(host, username, password)
        raise err

def convert_unc(host, path):
    return ''.join(['\\\\', host, '\\', path.replace(':', '$')])

def collect_logs(test_runs):
    from time import gmtime, strftime
    log_time = strftime("%Y-%m-%d-%H-%M-%S", gmtime())

    logger.info('Collecting logs...')

    for tc in test_runs:
        # create log folder

        log_dir_name = os.path.join('logs', tc.__class__.__name__ + '-' + log_time)

        params = tc._test_param(None)
        for h in tc._machines:
            host_name = h['host']

            vms = h['vms']
            for vm in vms:
                vm_name = vm['name']
                if len(vm['ctrl_ip']) > 0:
                    ctrl_ip = vm['ctrl_ip']
                else:
                    ctrl_ip = runner.utils.get_ip_for_vm(vm_name, host_name)

                # if the VM is a Windows, copy logs from "c:\logs" using SMB
                if 'Windows' in vm['version']:
                    wnet_connect(ctrl_ip, vm['username'], vm['password'])
                    src_dir = convert_unc(ctrl_ip, 'c:\\logs')

                    distutils.dir_util.copy_tree(src_dir, log_dir_name)
                else:
                    if not os.path.exists(log_dir_name):
                        os.makedirs(log_dir_name)
                    s = paramiko.client.SSHClient()
                    s.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())
                    s.connect(ctrl_ip, 22, username=vm['username'], password=vm['password'])

                    sftp = s.open_sftp()


                    # we only get all .log files in \root
                    command = 'find /root -name "*.log"'
                    stdin, stdout, stderr = s.exec_command(command)
                    filelist = stdout.read().splitlines()

                    for logfile in filelist:
                        (head, filename) = os.path.split(logfile)
                        logger.info('\t%s' % filename)
                        sftp.get(logfile, os.path.join(log_dir_name, filename))

                    sftp.close()
                    s.close()




# MAIN ENTRY
if __name__ == '__main__':
    # turn off GC
    # we don't want any GC to happen because some of our cases could be
    # sitting idle for several hours, but we still want to keep resources,
    # such as SSH connections and especially Pyro connections, alive.
    gc.disable()

    # get command line arguments
    opt_parser = build_arg_parser()
    args = opt_parser.parse_args()

    # test case list, corresponds to the test filenames
    cases = args.case_list.split(',')

    # prepare test run, load test machines
    # this only needs to be done once
    test_runs = prepare_test_runs(cases, args)

    try:
        run(test_runs)
    except Exception as e:
        # release all the machines
        logger.error('Exception: %s' % str(e))

        traceback.print_exc()

    # retrieve all logs on the remote computers to \logs\[TESTNAME]-[DATETIME]\
    collect_logs(test_runs)

    # release the Pyro connection on remote VMs
    release_pyro_objects(test_runs)
    
    logger.info('Releasing machines...')
    for tc in test_runs:
        pool.client.release_machines(tc._machines)

    logger.info('All test completed.')

