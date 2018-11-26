#!/usr/bin/python

from azuremodules import *

import argparse
import sys
import time

parser = argparse.ArgumentParser()

parser.add_argument('-4', '--serverip', help='specifies server VIP of server name', required=True)
parser.add_argument('-p', '--port', help='specifies which port should be used', type= int)
parser.add_argument('-c', '--connections', help='Number of connections', type= int, required=True)
parser.add_argument('-t', '--nthreads', help='number of client threads to run', type= int)
parser.add_argument('-l', '--time', help='duration for which test should be run')

args = parser.parse_args()
                #if no value specified then stop
command = 'kq_netperf/kq_netperf ' +  '-4 ' + args.serverip +  ' -c' + str(args.connections)
if args.port != None :
    command = command + ' -p' + str(args.port)
if args.nthreads != None :
    command = command + ' -t' + str(args.nthreads)
if args.time != None:
    command = command + ' -l' + str(args.time)
finalCommand = 'nohup ' + command + '  >>  kqnetperf-client.txt  2>&1 &'




def RunTest(client):
    UpdateState("TestRunning")
    RunLog.info("Starting kqnetperf Client..")
    RunLog.info("Executing Command : %s", client)
    Run(client)
    cmd ='sleep 2'
    Run(cmd)
    status = isProcessRunning('kq_netperf/kq_netperf')
    if status == "True":
        Run('echo "kq_netperf client is running" >> kqnetperf-client.txt')
    else:
        Run('echo "Error: kq_netperf client is NOT running" >> kqnetperf-client.txt')
    sleepTime = int(args.time) + 20 
    cmd = 'sleep ' + str(sleepTime)
    Run(cmd)
    status = isProcessRunning('kq_netperf/kq_netperf')
    if status == "True":
        time.sleep(60)
        Run('echo "ProcessRunning" >> kqnetperf-client.txt')
        Run('echo "Waiting for 60 secs to let iperf process finish" >> kqnetperf-client.txt')
        status = isProcessRunning('kq_netperf/kq_netperf')
        if status == "True":
            Run('echo "ProcessRunning even after 60 secs delay" >> kqnetperf-client.txt')
        else:
            Run('echo kqnetperf process finished after extra wait of 60 secs >>kqnetperf-client.txt')
    #else:
        #Run('echo "ProcessRunning" >> kqnetperf-client.txt')

client = finalCommand
Run('echo "TestStarted" > kqnetperf-client.txt')
RunTest(client)
# Run('echo "TestComplete" >> kqnetperf-client.txt')
# AnalyseKQnetperfClientUpdateResult()
