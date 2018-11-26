#!/bin/bash
#
# BootMultipleTimes1.sh
#
# To verify and check that VM reboots 50 times cotinuously without any errors.
# This script copies the booting script in to the start up
#  
#
#############################################################


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
    echo $1 > /root/state.txt
}

b=`cat /root/count.txt` 
echo $b
j=`expr 50 - $b`
if [ $b = 50 ]; then 
    LogMsg "Updating test case state to running"
    UpdateTestState $ICA_TESTRUNNING
    sleep 5
#
# Delete any summary.log files from a previous run
#
    rm -f ~/summary.log
    echo "Covers: TC31" > ~/summary.log
#
# Copy the booting script in to the rc.local
#
    echo "sh /root/BootMultipleTimes.sh" >> /etc/rc.local
    if [ $? -ne 0 ]; then
        LogMsg "Failed to update rc.local"
        echo "updating rc.local : Failed" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 10
    fi
    echo "Update rc.local : Passed" >>  ~/summary.log
    echo `expr $b - 1` > /root/count.txt
    init 6
elif [ $b -gt 0 ]; then
    LogMsg "Booting count:${j}" >> /root/BootMultipletimes.log
    echo `expr $b - 1` > /root/count.txt
    init 6
elif [ $b -eq 0 ]; then
    LogMsg "Booting count:${j}" >> /root/BootMultipletimes.log
    echo "Rebooting 50 times test completed successfully" >> /root/summary.log
    LogMsg "Updating test case state to completed" >> /root/BootMultipletimes.log
    UpdateTestState $ICA_TESTCOMPLETED
    exit 0
fi