#!/usr/bin/python

from azuremodules import *

def RunTest():
    UpdateState("TestRunning")
    RunLog.info("Checking if root password is deleted or not...")

    if (IsFreeBSD()):
        passwd_output = Run("cat /etc/passwd | grep root")
    else:
        passwd_output = Run("cat /etc/shadow | grep root")
    root_passwd = passwd_output.split(":")[1]
    if ('*' in root_passwd or '!' in root_passwd):
        RunLog.info('root password is deleted in /etc/shadow or /etc/passwd.')
        ResultLog.info('PASS')
    else:
        RunLog.error('root password not deleted.%s', passwd_output)
        ResultLog.error('FAIL')
    UpdateState("TestCompleted")

RunTest()
