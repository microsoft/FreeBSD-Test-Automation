#!/usr/bin/python

from azuremodules import *

import sys
import time

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Checking firewall status using iptables...")
    output = Run("iptables -L > iptables.txt")
    output = Run("cat iptables.txt")
    dropRulesCount = GetStringMatchCount("iptables.txt", "policy DROP")
    dropItemsCount = GetStringMatchCount("iptables.txt", "DROP")

    if (dropRulesCount <= 0 and dropItemsCount <= 0) :
        RunLog.info('No iptables DROP rules found, and Firewall is disabled. iptables output is: %s', output)
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
    else :
        RunLog.info('A few iptables DROP rules found, looks like firewall is enabled. iptables output is: %s', output)
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

        
def RunTestForBSD():
    UpdateState("TestRunning")
    RunLog.info("Checking firewall status")
    output = Run("cat /etc/rc.conf")

    if ('firewall_enable="YES"' in output or 'pf_enable="YES"' in output or 'ipfilter_enable="YES"' in output) :
        RunLog.info('Firewall is enabled and the content of /etc/rc.conf is: %s', output)
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")
    else :
        RunLog.info('Firewall is disabled and the content of /etc/rc.conf is: %s', output)
        ResultLog.info('PASS')
        UpdateState("TestCompleted")
        

if (IsFreeBSD()):
    RunTestForBSD()
else:
    RunTest()
