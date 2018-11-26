#!/bin/bash
#
# upDownNIC.sh
#
# Configure a NIC down, up, dhclient, multiple times.
#
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

echo "Covers NET-17" > ~/summary.log
echo "Covers TC13" > ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    echo "Info: no ${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

if [ "${NIC_NAME:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="NIC_NAME not defined in constants.sh"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ "${CYCLE_COUNT:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="CYCLE_COUNT not defined in constants.sh"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

echo "NIC_NAME    = ${NIC_NAME}"
echo "CYCLE_COUNT = ${CYCLE_COUNT}"

#
# Make sure CYCLE_COUNT is a reasonable value
# For not, less than or equal to 200
#
if [ $CYCLE_COUNT -gt 200 ]; then
    msg="CYCLE_COUNT is greater than 200"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 40
fi

if [ $CYCLE_COUNT -lt 1 ]; then
    msg="CYCLE_COUNT is less than 1"
    echo "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 50
fi

#
# Cycle the interface the requested number of times
#
i=0
while [ $i -lt $CYCLE_COUNT ]
do
    i=$((i+1))
    echo "Cycle $i"

    echo "ifconfig ${NIC_NAME} down"
    ifconfig ${NIC_NAME} down 2> ~/msg.txt
    if [ $? -ne 0 ]; then
        msg="Unable to ifconfig down ${NIC_NAME}"
        echo "Error: ${msg}"
        cat ~/msg.txt
        echo $msg >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 60 
    fi
	sleep 2
    echo "ifconfig ${NIC_NAME} up"
    ifconfig ${NIC_NAME} up 2> ~/msg.txt
    if [ $? -ne 0 ]; then
        msg="Unable to ifconfig up ${NIC_NAME}"
        echo "Error: ${msg}"
        cat ~/msg.txt
        echo $msg >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 70
    fi
	sleep 2
    echo "dhclient ${NIC_NAME}"
    dhclient ${NIC_NAME}
    if [ $? -ne 0 ]; then
        msg="Unable to dhclient ${NIC_NAME}"
        echo "Error: ${msg}"
        cat ~/msg.txt
        echo $msg >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 80
    fi
	sleep 2
done

#
# If we made it here, everything worked
#
UpdateTestState $ICA_TESTCOMPLETED
echo "Test case PASSED"

exit 0

