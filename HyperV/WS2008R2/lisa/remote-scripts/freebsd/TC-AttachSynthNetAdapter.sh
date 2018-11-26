#!/bin/bash
#
# Test case for TC6 - Attach synthetic network adapter
#

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
    exit 50
fi

#
# Configure the NIC if it is on the internal or private network
# Warning: This function assums hn1 is the vmbus device we are working with
#
if [[ $NIC =~ [Ii]nternal ]] || [[ $NIC =~ [Pp]rivate ]]; then
    if [ "${LOCAL_ADDR:-UNDEFINED}" = "UNDEFINED" ]; then
        msg="Error: Internal/Private NICs require LOCAL_ADDR"
	echo $msg
	echo $msg >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
	exit 60
    fi

    echo "ifconfig hn1 inet ${LOCAL_ADDR}  netmask 255.255.255.0"
    ifconfig hn1 inet ${LOCAL_ADDR} netmask 255.255.255.0
    if [ $? -ne 0 ]; then
        msg="Error: unable to configure hn1"
        echo $msg
        echo $msg >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 70
    fi
fi

if [[ $NIC =~ [Ee]xternal ]]; then
    dhclient hn1
fi

ifconfig hn0 down

ping -q -c 1 $TARGET_ADDR > /dev/null
if [ $? -ne 0 ]; then
    msg="Error: Unable to ping address on network"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
	ifconfig hn0 up
	ifconfig hn1 down
    exit 80
fi

ifconfig hn0 up
ifconfig hn1 down

UpdateTestState $ICA_TESTCOMPLETED

exit 0

