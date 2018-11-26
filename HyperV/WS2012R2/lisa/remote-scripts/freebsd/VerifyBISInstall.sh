#!/bin/bash
#
# VerifyBISInstall.sh
#
# Description:
#    Verify that the BIS enlightenment drivers are installed.
#    Currently, the checks assume a monolithic kernel rather
#    than loadable modules.
#
#    The file /var/run/dmesg.boot is checked for the following
#    strings:
#
#        Vmbus load
#        vmbus0: <Vmbus Devices> on motherboard
#        vmbus-attach
#        Netvsc initializing
#        storvsc0 on vmbus0
#        heartbea0: <vmbus-heartbeat supported>
#        timesync_probe: vmbus-timesync detected
#        da0: <Msft Virtual Disk
#
####################################################################


ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

CONSTANTS_FILE="constants.sh"


UpdateTestState()
{
    echo $1 > ~/state.txt
}


#
# Create the state.txt file so ICA knows we are running
#
echo "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

#
# Delete any summary.log files from a previous run
#
rm -f ~/summary.log
echo "Covers TC10" > ~/summary.log

#
# Get the device tree
#
DEVINFOFILE=~/devinfo.txt
devinfo > $DEVINFOFILE

#
# Did VMBus load
#
echo "Checking if VMBus loaded"

grep -q "vmbus0" $DEVINFOFILE
if [ $? -ne 0 ]; then
    msg="Vmbus not loaded"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 20
fi

#
# Did storvsc load
#
echo "Checking if storvsc loaded"

grep -q "storvsc" $DEVINFOFILE
if [ $? -ne 0 ]; then
    msg="storvsc not loaded"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 30
fi

#
# Did hyperv-utils load
#
echo "Checking if hyperv-utils loaded"

grep -q "hyperv-utils0" $DEVINFOFILE
if [ $? -ne 0 ]; then
    msg="storvsc did not initialize"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 40
fi

#
# Check Heartbeat service
#
DMESGBOOT=/var/run/dmesg.boot

echo "Checking for heartbeat service"

grep -q "Hyper-V Heartbeat Service" $DMESGBOOT
if [ $? -ne 0 ]; then
    msg="No heartbeat service"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 50
fi

#
# Check KVP service
#
echo "Checking for KVP service"
echo "   Not implemented yet"

#grep -q "Hyper-V KVP Service" $DMESGBOOT
#if [ $? -ne 0 ]; then
#    msg="No KVP service"
#    echo "Error: ${msg}"
#    echo $msg >> ~/summary.log
#    UpdateTestState $ICA_TESTFAILED
#    exit 60
#fi

#
# Check Shutdown service
#
echo "Checking for Shutdown service"

grep -q "Hyper-V Shutdown Service" $DMESGBOOT
if [ $? -ne 0 ]; then
    msg="No Shutdown service"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 70
fi

#
# Check Timesync service
#
echo "Checking for Time Synch Service"

grep -q "Hyper-V Time Synch Service" $DMESGBOOT
if [ $? -ne 0 ]; then
    msg="No Timesynch service"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi

#
# Is boot disk under BIS control
#
echo "Checking if boot device is under BIS control"

grep -q "da0: <Msft Virtual Disk" $DMESGBOOT
if [ $? -ne 0 ]; then
    msg="Boot disk not controlled by BIS"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 70
fi

#
# If we got here, all tests passed
#
echo "BIS verified" >> ~/summary.log
echo "Updating test case state to completed"

UpdateTestState $ICA_TESTCOMPLETED

exit 0

