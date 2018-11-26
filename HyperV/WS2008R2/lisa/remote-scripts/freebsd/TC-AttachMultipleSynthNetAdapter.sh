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
#if [ "${NIC:-UNDEFINED}" = "UNDEFINED" ]; then
 #   msg="The test parameter NIC is not defined in ${CONSTANTS_FILE}"
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
    msg="The test parameter TARGET_ADDR is not defined in       
 ${CONSTANTS_FILE}"
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
i=0
while [ $i -lt $numVMBusNics ]
do
	ifconfig hn${i} down
	if [ $? == 0 ];	then
		ifconfig hn${i} up
	else
		msg="Error at ifconfig hn${i} down"
		echo $msg
		echo $msg >> ~/summary.log
		exit 60
	fi
	if [ $? == 0 ]; 	then
		dhclient hn${i}
	else
		msg="Error at ifconfig hn${i} up"
		echo $msg
		echo $msg >> ~/summary.log
		exit 70
	fi
	if [ $? == 0 ]; 	then
		msg="Configured network cards successfully"
		echo $msg >> ~/summary.log
	else
		msg="Error at dhclient hn${i} "
		echo $msg
		echo $msg >> ~/summary.log
		exit 80
	fi
	i=$[$i+1]
done
#
# Configure the NIC if it is on the internal or private network
# Warning: This function assums hn0 is the vmbus device we are working with
#
UpdateTestState $ICA_TESTCOMPLETED

exit 0


