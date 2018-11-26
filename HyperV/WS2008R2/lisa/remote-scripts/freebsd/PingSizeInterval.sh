#!/bin/bash
#
# Test case for TC22 - Ping with different size packet sizes and intervals 
#

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

rm -f ~/summary.log
echo "Covers: NET-15" >> ~/summary.log
echo "Covers: TC22" >> ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    msg="Error: no ${CONSTANTS_FILE} file"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${TARGET_ADDR:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TARGET_ADDR is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

#
# Make sure we have the ping.awk file
#
if [ ! -e ~/ping.awk ]; then
    msg="The file ping.awk was not provided"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

dos2unix ~/ping.awk

#
# Ping using various size packets and intervals.
# Make sure there was not packet loss
#
count=5
for s in  0 1 48 64 512 1440 1500 1505 4096 4192 25152
do
    for i in 0.1 0.01 0.005
    do
        LogMsg "ping -s $s -i $i -c $count ${TARGET_ADDR}"
        ping -s $s -i $i -c $count ${TARGET_ADDR} > pingfile
        dropped=`awk -f ping.awk pingfile`
        if [ $dropped != "0.0" ]; then
            msg="Error: ping -s $s -i $i -c $count dropped packets"
            LogMsg $msg
            echo $msg >> ~/summary.log
            UpdateTestState $ICA_TESTFAILED
            exit 50
        fi
    done
done

#
# Now ping with size 25153 which should fail due to kernel limits
#
LogMsg "ping -s 25153 -c 1 ${TARGET_ADDR}"
ping -s 25153 -c 5 ${TARGET_ADDR} > pingfile
sts=$?
if [ $sts -eq 0 ]; then
    #
    # The ping worked when it should haved failed
    #
    msg="Error: ping -s 25153 -c 1 ${TARGET_ADDR} should have failed"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 60
else
    LogMsg "ping -s 25153 failed as expected - scenario passed"
fi

#
# Ping flood the target VM
# Note: not implemented since this is currently being tested on the corp net.
#


#
# Let ICA know the test completed successfully
#
UpdateTestState $ICA_TESTCOMPLETED

exit 0

