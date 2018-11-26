#!/bin/bash
# MultipleSynthNetAdaptor.sh
#
# Test case for Configuring Multiple synthetic network adapter
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
    msg="The test parameter NIC is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

if [ "${TARGET_ADDR:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TARGET_ADDR is not defined in       
 ${CONSTANTS_FILE}"
    LogMsg $msg
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
    LogMsg "Number of VMBus NICs (hn) found = ${numVMBusNics}"
else
    msg="Error: No VMBus NICs found"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 50
fi
i=1
while [ $i -lt $numVMBusNics ]
do
	ifconfig hn${i} down
	if [ $? == 0 ];	then
		ifconfig hn${i} up
	else
		msg="Error at ifconfig hn${i} down"
		LogMsg $msg
		echo $msg >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 60
	fi
	if [ $? == 0 ]; 	then
		dhclient hn${i}
	else
		msg="Error at ifconfig hn${i} up"
		LogMsg $msg
		echo $msg >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 70
	fi
	if [ $? == 0 ]; 	then
		msg="Configured network card hn${i} successfully"
		echo $msg >> ~/summary.log
	else
		msg="Error at dhclient hn${i} "
		LogMsg $msg
		echo $msg >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 80
	fi
	i=$[$i+1]
done
#
# If we are here test case completed
#
UpdateTestState $ICA_TESTCOMPLETED

exit 0


