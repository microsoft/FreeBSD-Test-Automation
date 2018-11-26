#!/usr/bin/env python
#######################################################################
#
# Description
#     	This is a command line portal for BIS automation test running on Jenkins
#		Customer could run this python command to schedule all BIS tests on Jenkins.
#
# History
#     1/12/2015 Created by     xiazhang
#######################################################################

import sys
import httplib
import getopt

jobs = {}

jobs["2012R2"] = "/job/CI.BIS2012R2/buildWithParameters?token=BIS"
jobs["2012"] = "/job/CI.BIS2012/buildWithParameters?token=BIS"
jobs["2008R2"] = "/job/CI.BIS2008R2/buildWithParameters?token=BIS"

succeed = 0

branchName = "dev"     #Default git branch name
hostAndPort = "10.199.253.3:8080"     #Default host(IP) and port number for HTTP connection

#You can add other control parameters in the future
shortargs = 'h'
longargs = ['help','branch=','hp=']

#To print the help information
def usage():
    print "Usage:"
    print "    %s [-h] [--help] [--branch <branchName>] [--hp <hostAndPort>]"% (sys.argv[0])
    print "Examples:"
    print "    %s --branch dev "% (sys.argv[0])
    print "    %s --branch dev --hp 10.199.253.3:8080 "% (sys.argv[0])
    
#Add the parameters from command line to the jobs 
def AddParamToJobs(jobs, parameter):
    for index in jobs.keys():
        jobs[index] = jobs[index] + parameter;

#Para the input parameters
try:
    opts,args = getopt.getopt(sys.argv[1:], shortargs, longargs);
    for opt,arg in opts:
        if opt in ("-h","--help"):
            usage();
            sys.exit(0);
      	elif opt in ("--branch"):
            branchName = arg
        elif opt in ("--hp"):
            hostAndPort = arg
except getopt.GetoptError:
    usage();
    sys.exit(1);

print "Now, the git branch is %s" % (branchName)
print "Now, the host and port for HTTP connection is %s" % (hostAndPort)

AddParamToJobs( jobs, "&branch=" + branchName );

for k, v in jobs.items():
	conn = httplib.HTTPConnection(hostAndPort)
	conn.request("HEAD", v)
	res = conn.getresponse()
	if res.status == 201:
		print "test on %s is scheduled" % (k)
		succeed += 1
	else:
		print "test on %s failed, reason: %s" % (k, res.reason)

if succeed == len(jobs):
	print "All BIS tests on Jenkins are scheduled successfully!"
else:
	print "%d BIS tests on Jenkins are not scheduled successfully" % (len(jobs)-succeed,)
