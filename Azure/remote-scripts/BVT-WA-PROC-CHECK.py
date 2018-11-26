#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Checking WALinuxAgent in running processes")
    temp = Run(command)
    output = temp
    if ("waagent" in output) :
                    RunLog.info('waagent service present in running processes')
                    ResultLog.info('PASS')
                    UpdateState("TestCompleted")
    else:
                    RunLog.error('waagent service absent in running processes')
                    ResultLog.error('FAIL')
                    UpdateState("TestCompleted")
        


if (IsFreeBSD()):
    RunTest("ps -ax | grep waagent | grep -v grep")
else:
    RunTest("ps -ef  | grep waagent | grep -v grep")