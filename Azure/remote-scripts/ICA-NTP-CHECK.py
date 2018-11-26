#!/usr/bin/env python
from azuremodules import *

def RunTest():
    UpdateState("TestRunning")
    ntpoutput = Run("ntpd --version")
    RunLog.info(ntpoutput)
    ResultLog.info('PASS')
    UpdateState("TestCompleted")
    
RunTest()