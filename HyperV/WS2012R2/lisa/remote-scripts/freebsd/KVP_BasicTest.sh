#!/bin/bash
#
# KVP_BasicTest.sh
# This script will verify that the KVP daemon is started at the boot of the VM. 
# This script will install and run the KVP client tool to verify that the KVP pools are created and accessible.
# Make sure we have kvptool.tar.gz file in Automation\..\lisa\Tools folder 
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
touch ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    msg="Error: no ${CONSTANTS_FILE} file"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

#
# Echo TCs we cover
#
echo "Covers ${TC_COVERED}" > ~/summary.log

#
# Verify that the KVP Daemon is running
#
/etc/rc.d/hv_kvpd status | grep running
if [ $? -ne 0 ]; then
LogMsg "KVP Daemon is not running by default"
echo "KVP daemon not running, basic test: Failed" >> ~/summary.log
UpdateTestState $ICA_TESTFAILED
exit 10
fi	
LogMsg "KVP Daemon is started on boot and it is running"
#
# Extract and install the KVP client tool.
#
mkdir kvptool
tar -xvf kvp*.gz -C kvptool
if [ $? -ne 0 ]; then
LogMsg "Failed to extract the KVP tool tar file"
echo "Installing KVP tool: Failed" >> ~/summary.log
UpdateTestState $ICA_TESTFAILED
exit 10
fi
chmod 755 kvptool/kvp_client

#
# Run the KVP client tool and verify that the data pools are created and accessible
#
poolcount="`./kvptool/kvp_client -l | grep Pool | wc -l`"
if [ $poolcount -ne 5 ]; then
LogMsg "pools are not created properly"
echo "Pools are not listed properly, KVP Basic test: Failed" >> ~/summary.log
UpdateTestState $ICA_TESTFAILED
exit 10
fi
LogMsg "Verified that the 0-4 all the 5 data pools are listed properly"  
echo "KVP Daemon is running and data pools are listed -KVP Basic test : Passed" >>  ~/summary.log
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED
exit 0
