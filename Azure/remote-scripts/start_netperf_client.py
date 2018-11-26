#!/usr/bin/python

from azuremodules import *

import argparse
import sys
import time


parser = argparse.ArgumentParser()

parser.add_argument('-H', '--serverip', help='specifies server VIP of server name', required=True)
parser.add_argument('-t', '--testname', help='This option is used to tell netperf which test you wish to run', required=True)
parser.add_argument('-c', '--connections', help='Number of connections', type= int, required=True)
parser.add_argument('-l', '--time', help='duration for which test should be run', required=True)
parser.add_argument('-b', '--reuqestnums', help='the number of transactions in flight at one time', type= int, required=True)

args = parser.parse_args()

command = 'netperf -H ' + args.serverip + ' -T 2,2 -l ' + args.time + ' -t ' + args.testname + ' -- -b ' + str(args.reuqestnums) +  ' -D -k "PROTOCOL, P50_LATENCY, P90_LATENCY, P99_LATENCY, MIN_LATENCY, MAX_LATENCY, MEAN_LATENCY"'

finalCommand = command + ' >>  netperf-client.txt &'
connections = args.connections
def RunTest(client):
	UpdateState("TestRunning")
	RunLog.info("Starting netperf Client..")
	RunLog.info("Executing Command : %s", client)
	for i in range(0,connections):
		temp = Run(client)

	status = isProcessRunning('netperf -H')
	if status == "True":
		Run('echo "ProcessRunning" >> netperf-client.txt')
		time.sleep(int(args.time) + 10)
		while isProcessRunning('netperf -H') == "True":
			Run('echo "Waiting for netperf process finish" >> netperf-client.txt')
			time.sleep(5)
		Run('echo netperf process finished >>netperf-client.txt')
		ResultLog.info("PASS")
	else:
		ResultLog.info("FAIL")
	UpdateState("TestCompleted")
client = finalCommand

RunTest(client)
kernel_version = ''
kernel_info = Run('uname -a')
kernel = re.match('.*(FreeBSD\s*[0-9]+.*):\s+.*',kernel_info)
if kernel:
    kernel_version = kernel.group(1).strip()
Run('echo "Kernel Version: %s" >> netperf-client.txt' % kernel_version)
Run('echo Guest Distro: `uname -r` >> netperf-client.txt')
Run('echo "TestComplete" >> netperf-client.txt')
