#!/bin/bash
#
# VerifyLoadableModules.sh
#
# Description:
#    Verify that the BIS loadable modules drivers are loaded.
#    
#    Checking following modules:
#                               vmbus
#                               storvsc
#                               netvsc
#                               utils
#
#    The file /var/run/dmesg.boot is checked for the following
#    strings:
#
#        #        da0: <Msft Virtual Disk
#
####################################################################


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
    echo $1 > ~/state.txt
}


#
# Create the state.txt file so ICA knows we are running
#
LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

#
# Delete any summary.log files from a previous run
#
rm -f ~/summary.log
echo "Covers: TC25, TC26" > ~/summary.log

#
# Get the modules tree
#
MODULES=~/modules.txt
kldstat > $MODULES


#
# Did VMBus load
#
LogMsg "Checking if VMBus loaded"

grep -q "vmbus" $MODULES
if [ $? -ne 0 ]; then
    msg="Vmbus not loaded"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 20
fi

#
# Did storvsc load
#
LogMsg "Checking if storvsc loaded"

grep -q "storvsc" $MODULES
if [ $? -ne 0 ]; then
    msg="storvsc not loaded"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 30
fi

#
# Did netvsc load
#
LogMsg "Checking if netvsc loaded"

grep -q "netvsc" $MODULES
if [ $? -ne 0 ]; then
    msg="netvsc not loaded"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 30
fi


#
# Did utils load
#
LogMsg "Checking if utils loaded"

grep -q "utils" $MODULES
if [ $? -ne 0 ]; then
    msg="utils not loaded"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 30
fi

#
# Is boot disk under BIS control
#
DMESGBOOT=/var/run/dmesg.boot
LogMsg "Checking if boot device is under BIS control"

grep -q "da0: <Msft Virtual Disk" $DMESGBOOT
if [ $? -ne 0 ]; then
    msg="Boot disk not controlled by BIS"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 70
fi

#
# If we got here, all tests passed
#
echo "BIS loadable modules verified" >> ~/summary.log
LogMsg "Updating test case state to completed"

UpdateTestState $ICA_TESTCOMPLETED

exit 0

