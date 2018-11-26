#!/bin/bash
#
# TC-CheckCPUCount.sh
#
# Check that the guest sees the correct number of CPUs.
# This script will read the number of CPUs it should see
# from the file constants.sh.  This file will define a
# variable named VCPU as follows:
#    VCPU=2
#
# This definition lets the test script know that it should
# see two CPUs.  If true, this script indicates the test
# case passed.  Otherwise, a failing test case is indicated.
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

echo "Covers CORE-08" > ~/summary.log
echo "Covers TC14" > ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    echo "Info: no ${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 5
fi

#
# Check the number of CPUs the system sees with the number we should see
#
echo "VCPU = ${VCPU}"
echo "VCPU = ${VCPU}" >> ~/summary.log

cpuCount=`sysctl -a | grep -i hw.ncpu | cut -d ' ' -f 2`
echo "Found ${cpuCount} CPUs"

exitSts=10
if [ $cpuCount -ne $VCPU ]; then
    UpdateTestState $ICA_TESTFAILED
    echo "Test case FAILED"
else
    UpdateTestState $ICA_TESTCOMPLETED
    echo "Test case PASSED"
    exitSts=0
fi

exit $exitSts

