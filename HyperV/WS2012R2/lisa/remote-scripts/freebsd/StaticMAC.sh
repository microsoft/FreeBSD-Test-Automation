#!/bin/bash
#
#  StaticMAC.sh
#
#  This script try checks that static MAC is relected exactly as set in hyper-v
#   
#   Test parameter :
#     NIC: It shows the apdator to be attach is of which network type and uses which network name
#         Example: NetworkAdaptor,External,External_Net
#
#     TARGET_ADDR: It is the ip address to be pinged
#
#     MAC: MAC address of NIC
#
###################################################################

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
echo "Updating test case state to running"
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
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${NIC:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter NIC is not defined in ${CONSTANTS_FILE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

if [ "${TARGET_ADDR:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TARGET_ADDR is not defined in ${CONSTANTS_FILE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 40
fi

if [ "${MAC:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TARGET_ADDR is not defined in ${CONSTANTS_FILE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 50
fi

#
# Echo TCs we cover
#
echo "Covers ${TC_COVERED}" > ~/summary.log

#
# Check that we have a hn device
#
numVMBusNics=`ifconfig | egrep "^hn" | wc -l`
if [ $numVMBusNics -gt 0 ]; then
    echo "Number of VMBus NICs (hn) found = ${numVMBusNics}"
else
    msg="Error: No VMBus NICs found"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 60
fi

#
# Get the MAC address of network adaptor
#
for j in 1 2 3 4 5 6
do
    i=`ifconfig hn1 | grep ether | cut -d " " -f 2 | cut -d ":" -f $j`
    Mac=`echo $MAC | cut -d ":" -f $j`
    if [ $i = $Mac ] ; then
        LogMsg "digits matched"$i,$Mac
    else
        LogMsg "MAC address differs, Test : Failed"
	    echo "MAC address differs, Test : Failed" >> ~/summary.log
	    UpdateTestState $ICA_TESTFAILED
	    exit 70
    fi
done
LogMsg "MAC address is the same"

ifconfig hn0 down
dhclient hn1

#
# Test the ping
#
LogMsg "ping -c 5 ${TARGET_ADDR}"
ping -c 5 ${TARGET_ADDR}
if [ $? -ne 0 ] ; then
    LogMsg "Ping failed, Test : Failed"
	echo "Ping failed, Test : Failed" >> ~/summary.log
	ifconfig hn0 up
	ifconfig hn1 down
    sleep 1 
	UpdateTestState $ICA_TESTFAILED
	exit 60
fi

echo "MAC address is the same and also ping is successful, Test : Passed" >> ~/summary.log

#
#If we are here test passed
#
LogMsg "Test case completed successfully"
UpdateTestState $ICA_TESTCOMPLETED

ifconfig hn0 up
ifconfig hn1 down

exit 0
