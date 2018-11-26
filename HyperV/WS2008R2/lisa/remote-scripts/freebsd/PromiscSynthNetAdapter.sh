#!/bin/bash
#
# PromiscSynthAdaptor.sh
#
# This test script enables and disables promiscuous mode of hn0 adaptor
#
# Test parameter :
#     NIC: It shows the apdator to be attach is of which network type and uses which network name
#         Example: NetworkAdaptor,External,External_Net
#
###################################################################

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

CONSTANTS_FILE="constants.sh"


UpdateTestState()
{
    echo $1 > ~/state.txt
}

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

#
# Create the state.txt file so ICA knows we are running
#
LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

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
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${NIC:-UNDEFINED}" = "UNDEFINED" ]; then
    echo "The test parameter NIC is not defined in ${CONSTANTS_FILE}" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    echo "The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

#
# Echo TCs we cover
#
echo "Covers ${TC_COVERED}" >> ~/summary.log

#
#Enabling/disabling promisc mode
#

ifconfig hn0 promisc
ifconfig | grep -q "PROMISC" 
if [ $? -ne 0 ];	then
    echo "Error entering hn0 promisc mode" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 50
fi
LogMsg "Promiscuous Mode Enabled"

ifconfig hn0 -promisc
ifconfig | grep -q "PROMISC"
if [ $? -eq 0 ]; 	then
    echo "Error disabling hn0 promisc mode" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 60
fi
LogMsg "Promiscuous Mode is Disabled"
#
#If we are here test is completed
#

echo "Promiscuous Mode test completed successfully" >> ~/summary.log
UpdateTestState $ICA_TESTCOMPLETED

exit 0


