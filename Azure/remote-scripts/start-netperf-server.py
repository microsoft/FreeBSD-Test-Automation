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

args = parser.parse_args()
#if no value specified then stop
command = 'netserver '  

finalCommand = command + ' >>  iperf-server.txt'

server = finalCommand
print(server)

StopNetperfServer()
StartNetperfServer(server)

