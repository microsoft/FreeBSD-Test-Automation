#!/usr/bin/python

from azuremodules import *

def RunTest(command):
    UpdateState("TestRunning")
    RunLog.info("Checking root device timeout...")
    temp = Run(command)
    rootDeviceTimeout = 300
    
    output = int(temp)
    if (output == rootDeviceTimeout) :
                    RunLog.info('SDA timeout value is %s', output)
                    ResultLog.info('PASS')
                    UpdateState("TestCompleted")
    else:
                    RunLog.error('SDA timeout value is %s', output)
                    ResultLog.error('FAIL')
                    UpdateState("TestCompleted")
        
if (IsFreeBSD()):
    RunTest("sysctl -a | grep kern.cam.da.default_timeout | awk '{print $2}'")
else:
    RunTest("cat /sys/block/sda/device/timeout")
