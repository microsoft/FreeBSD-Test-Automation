#!/bin/bash

########################################################################
#
# vmbus_protocol_version.sh
# Description:
#	This script was created to automate the testing of a FreeBSD
#	Integration services. This script will verify that the negotiated 
#	VMBus protocol number is correct.
#	This is available only for Windows Server 2012 R2 and newer.

#
#	The test performs the following steps:
#	 1. Make sure we have a constants.sh file.
#	 2. Take the VMBusVer variable from the test case description.

#     
#	 To pass test parameters into test cases, the host will create
#    a file named constants.sh.  This file contains one or more
#    variable definition.
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

#
# Source the constants file
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    ERRmsg="Error: no ${CONSTANTS_FILE} file"
    LogMsg $ERRmsg
    echo $ERRmsg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

if [ -e ~/summary.log ]; then
    LogMsg "Cleaning up previous copies of summary.log"
    rm -rf ~/summary.log
fi

#
# Identifying the test-case ID and VMBus version to match
#
if [ ! ${TC_COVERED} ]; then
    LogMsg "The TC_COVERED variable is not defined!"
	echo "The TC_COVERED variable is not defined!" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

if [ ! ${VMBusVer} ]; then
    LogMsg "The VMBusVer variable is not defined."
	echo "The VMBusVer variable is not defined." >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

if [ ! ${VMBusVerOnWS2012} ]; then
    LogMsg "The VMBusVerOnWS2012 variable is not defined."
	echo "The VMBusVerOnWS2012 variable is not defined." >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

echo "This script covers test case: ${TC_COVERED}" >> ~/summary.log

#
# Checking for the VMBus protocol number in the dmesg file
#
vmbus_string=`sysctl -n dev.vmbus.0.version`
if [ "$vmbus_string" = "" ]; then
	LogMsg "Error! Could not find the VMBus protocol string in dmesg."
	echo "Error! Could not find the VMBus protocol string in dmesg." >> ~/summary.log
	UpdateTestState "TestFailed"
    exit 10
elif [ "$vmbus_string" == "$VMBusVer"  -o  "$vmbus_string" == "$VMBusVerOnWS2012" ]; then
	LogMsg "Info: Found a matching VMBus string: ${vmbus_string}"
	echo -e "Info: Found a matching VMBus string:\n ${vmbus_string}" >> ~/summary.log
else
	LogMsg "The vmbus protocol version expected to be ${VMBusVer} or ${VMBusVerOnWS2012}, but it's ${vmbus_string} now."
	echo "The vmbus protocol version expected to be ${VMBusVer} or ${VMBusVerOnWS2012}, but it's ${vmbus_string} now." >> ~/summary.log
	UpdateTestState "TestFailed"
	exit 10
fi

LogMsg "Test Passed"
UpdateTestState "TestCompleted"
