#!/usr/bin/python

##########################################
#THIS SCRIPT ACCETPS SOME SERVER PARAMETERS.
#PLEASE RUN THE SCRIPT WITH -h OR -help FOR MORE DETAILS.
##########################################

from azuremodules import *


import argparse
import sys
 #for error checking
parser = argparse.ArgumentParser()

parser.add_argument('-p', '--port', help='specifies which port should be used',type= int)
parser.add_argument('-t', '--nthreads', help='Threads Settings', type = int)

args = parser.parse_args()

command = 'kq_netperf/kq_recvserv '
if args.port != None :
        command = command + ' -p ' + str(args.port)
if args.nthreads != None:
        command = command + ' -t ' + str(args.nthreads)
finalCommand = command + ' >>  kqnetperf-server.txt'

server = finalCommand
print(server)
#Run('echo "TestStarted" > kqnetperf-server.txt')
StopKQNetperfServer()
StartKQNetperfServer(server)
#Run('echo "TestCompleted" >> kqnetperf-server.txt')
