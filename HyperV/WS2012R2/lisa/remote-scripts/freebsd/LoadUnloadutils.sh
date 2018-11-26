#!/bin/bash
#
# LoadUnloadutils.sh
#
# Description:
#    To load-unload utils module
#    
#    Checking following modules:
#                               vmbus
#                               utils
#                               
#
#  Note: Need to run LoadUnloadnetvsc.sh script before this and
#        also required setup script RemoveSCSIController.ps1
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
echo "Covers: TC" > ~/summary.log

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
    UpdateTestState $ICA_TESTABORTED
    exit 20
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
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

#
# Unload utils modules and load it again
#
i=1
while [ $i -le 5 ]
do
kldunload hv_utils
if [ $? -ne 0 ] ; then
    LogMsg "Unloading module failed"
	echo "Unloading module failed" >> ~/summary.log
    sleep 1 
	UpdateTestState $ICA_TESTFAILED
	exit 40
fi
sleep 1
LogMsg "Output of kldstat after unloading module for ${i} time(s)"
kldstat
sleep 1
kldload hv_utils
if [ $? -ne 0 ] ; then
    LogMsg "Reloading module failed"
	echo "Reloading module failed" >> ~/summary.log
    sleep 1 
	UpdateTestState $ICA_TESTFAILED
	exit 50
fi
sleep 1
LogMsg "Output of kldstat after loading module for ${i} time(s)"
kldstat
sleep 1
i=$[$i+1]
done

#
# Did utils loaded again
#
LogMsg "Checking if utils loaded"

kldstat > $MODULES

grep -q "utils" $MODULES
if [ $? -ne 0 ]; then
    msg="utils not loaded"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 60
fi
#
# If we got here, all tests passed
#
echo "Loading/Unloading utils successful" >> ~/summary.log
LogMsg "Updating test case state to completed"

UpdateTestState $ICA_TESTCOMPLETED

exit 0

