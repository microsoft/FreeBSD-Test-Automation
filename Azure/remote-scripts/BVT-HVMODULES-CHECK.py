#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    UpdateState("TestStarted")
    if (IsFreeBSD()):
        hvModules=["hv_utils"]
        RunLog.info("For FreeBSD 10+, all hyperV modules are integrate in kernel, check module hv_utils is enough.")
    else:
        hvModules=["hv_storvsc","hv_netvsc","hv_vmbus","hv_utils","hid_hyperv",]
    totalModules = len(hvModules)
    presentModules = 0
    UpdateState("TestRunning")
    RunLog.info("Checking for hyperV modules.")
    temp = Run(command)
    output = temp
    for module in hvModules :
        if (module in output) :
            RunLog.info('Module %s : Present.', module)
            presentModules = presentModules + 1
        else :
            RunLog.error('Module %s : Absent.', module)
            
    if (totalModules == presentModules) :
        RunLog.info("All modules are present.")
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.error('one or more module(s) are absent.')
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

if (IsFreeBSD()):
    RunTest("kldstat -v | grep hv_utils")
else:
    RunTest("lsmod")