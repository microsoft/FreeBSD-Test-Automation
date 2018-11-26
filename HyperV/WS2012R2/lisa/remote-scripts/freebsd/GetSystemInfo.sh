#!/bin/bash

########################################################################
#
# GetSystemInfo.sh
# Description:
#	This script was created to get system info for insert them into database.
#     
#	To pass test parameters into test cases, the host will create
#   a file named constants.sh.  This file contains one or more
#   variable definition.
#
################################################################

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

CONSTANTS_FILE="constants.sh"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

UpdateTestState()
{
    echo $1 > $HOME/state.txt
}

#
# Update LISA with the current status
#
cd ~
UpdateTestState $ICA_TESTRUNNING
LogMsg "Updating test case state to running"


if [ -e ~/summary.log ]; then
    LogMsg "Cleaning up previous copies of summary.log"
    rm -rf ~/summary.log
fi

echo "Test Passed" >> ~/summary.log
LogMsg "Test Passed"
LogMsg "Test completed successfully"
LogMsg "GuestDistro  : `uname -nr`"
echo "GuestDistro : `uname -nr`" >> ~/summary.log

LogMsg "Kernel Version : `uname -a`"
echo "Kernel Version : `uname -a`" >> ~/summary.log
UpdateTestState $ICA_TESTCOMPLETED
