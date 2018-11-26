#!/usr/bin/python

from azuremodules import *

import argparse
import sys
import time

#for error checking
parser = argparse.ArgumentParser()

parser.add_argument('-H', '--serverip', help='specifies server VIP of server name', required=True)
parser.add_argument('-u', '--udp', help='switch : starts the client in udp data packets sending mode.', choices=['yes', 'no'] )
parser.add_argument('-p', '--port', help='specifies which port should be used', required=True, type= int)
parser.add_argument('-l', '--time', help='duration for which test should be run', required=True)
parser.add_argument('-m', '--length', help='length of buffer to read or write', type= int)

#parser.add_argument('-p', '--port', help='specifies which port should be used', required=True, type= int)
args = parser.parse_args()

command = 'netperf -H ' + args.serverip + ' -l ' + args.time

if args.udp == 'yes':
    command = command + ' -t UDP_STREAM'
command = command + ' -- -R 1' + ' -P ' + str(args.port) + ',' +  str(args.port) 
if args.length != None:
    command = command + ' -m ' + str(args.length)

finalCommand = 'nohup ' + command + ' >>  iperf-client.txt &'




def RunTest(client):
	UpdateState("TestRunning")
	RunLog.info("Starting netperf Client..")
	RunLog.info("Executing Command : %s", client)
	temp = Run(client)
	cmd ='sleep 2'
	tmp = Run(cmd)
	sleepTime = int(args.time) + 10 
	cmd = 'sleep ' + str(sleepTime)
	tmp = Run(cmd)

	status = isProcessRunning('netperf')
	if status == "True":
		time.sleep(60)
		Run('echo "ProcessRunning" >> iperf-client.txt')
		Run('echo "Waiting for 60 secs to let netperf process finish" >> iperf-client.txt')
		status = isProcessRunning('netperf')
		if status == "True":
			Run('echo "ProcessRunning even after 60 secs delay" >> iperf-client.txt')
		else:
			Run('echo netperf process finished after extra wait of 60 secs >>iperf-client.txt')

client = finalCommand

RunTest(client)
Run('echo "TestComplete" >> iperf-client.txt')
AnalyseClientUpdateResult()
