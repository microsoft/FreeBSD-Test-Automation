#!/bin/bash
#
# LoadUnloadnetvsc.sh
#
# Description:
#    To load-unload netvsc module
#    
#    Checking following modules:
#                               vmbus
#                               netvsc
#                               
#
#    Note: After using this scrpt VM boots without FAST IDE support
#          This script need to be executed before LoadUnloadstorvsc.sh
#
#######################################################################


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
echo "Covers: TC32" > ~/summary.log

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
# Did netvsc load
#
LogMsg "Checking if netvsc loaded"

grep -q "netvsc" $MODULES
if [ $? -ne 0 ]; then
    msg="netvsc not loaded"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

#
# Unload netvsc modules and load it again
#
i=1
while [ $i -le 5 ]
do
kldunload hv_netvsc
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
kldload hv_netvsc
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
# Did netvsc loaded again
#
LogMsg "Checking if netvsc loaded"

kldstat > $MODULES

grep -q "netvsc" $MODULES
if [ $? -ne 0 ]; then
    msg="netvsc not loaded"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 60
fi

#
# Edit next boot for disabling FAST IDE support
#
nextboot -k kernel
if [ $? -ne 0 ] ; then
    LogMsg "nextboot.conf not created"
	echo "nextboot.conf not created" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
	exit 70
fi
echo "hw.ata.disk_enable=\"1\"" >> /boot/nextboot.conf 
if [ $? -ne 0 ] ; then
    LogMsg "nextboot.conf not edited"
	echo "nextboot.conf not edited" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
	exit 80
fi
#
# If we got here, all tests passed
#
echo "Loading/Unloading netvsc successful" >> ~/summary.log
LogMsg "Updating test case state to completed"

UpdateTestState $ICA_TESTCOMPLETED

exit 0

