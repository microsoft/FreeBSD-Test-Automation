#!/bin/bash

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
echo "Loading constants.sh"

if [ -e ~/${CONSTANTS_FILE} ]; then
    source ~/${CONSTANTS_FILE}
else
    echo "Error: no ~/${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

#
# Make sure all required variables are defined in constants.sh
#
if [ ${TC_COVERED:-UNDEFINED} = "UNDEFINED" ]; then
    echo "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

echo "Covers: ${TC_COVERED}" >> ~/summary.log

uname -a | grep -i "current"
if [ $? -eq 0 ]; then
    UpdateTestState $ICA_TESTCOMPLETED
    echo "Skip test due to this case doesn't support current version." >> ~/summary.log
    exit 0
fi


#
# Update kernel 
#
echo "Begin to update kernel" >> ~/summary.log
 
freebsd-update fetch --not-running-from-cron > ~/updatekernel.log
if [ $? -ne 0 ]; then
    UpdateTestState $ICA_TESTFAILED
    echo "freebsd-update fetch failed" >> ~/summary.log
    cat ~/updatekernel.log  >>  ~/summary.log
    exit 1
fi


freebsd-update install --not-running-from-cron >> ~/updatekernel.log
if [ $? -ne 0 ]; then
    cat  ~/updatekernel.log | grep -i "No updates needed"
    if [ $? -ne 0 ]; then
        echo "freebsd-update install failed" >> ~/summary.log
        cat ~/updatekernel.log  >>  ~/summary.log
        exit 1
    fi
fi


echo "Update kernel test completed successfully"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

