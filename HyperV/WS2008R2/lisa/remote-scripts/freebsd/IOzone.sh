#!/bin/bash
# IOzone
# Performace test IOzone
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

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    echo "Warn : no ${CONSTANTS_FILE} found"
fi

#
# Put your test case code here
#

#
# Install IOzone and check if its installed successfully
#
pkg_add -r iozone
sleep 1
pkg_info > ~/info.txt

grep -q "iozone" ~/info.txt
if [ $? -ne 0 ] ; then
    LogMsg "Iozone installation failed"
	echo "Iozone installation failed" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
	exit 10
fi

LogMsg "IOzone installed successfully"

#
# run iozone
#
for i in 1 2
do
    /usr/local/bin/./iozone -R -l 2 -u 2 -t 2 -s 100m -b ~/Result${i}.xls
    if [ $? -ne 0 ] ; then
        LogMsg "Iozone test failed"
	    echo "Iozone test failed" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
	    exit 20
    fi
    sleep 1
done

LogMsg "IOzone test completed successfully"
#
# Let ICA know we completed successfully
#
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

