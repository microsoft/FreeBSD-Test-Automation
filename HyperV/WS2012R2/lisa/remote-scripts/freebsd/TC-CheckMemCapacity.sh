#!/bin/bash
#
# TC-CheckMemCapacity.sh
#
# Check that the guest sees the correct capacity of memory.
# This script will read the capacity of memory it should see
# from the file constants.sh.  This file will define a
# variable named VMEM as follows:
#    VMEM=2GB
#
# This definition lets the test script know that it should
# see 2GB memory.  If true, this script indicates the test
# case passed.  Otherwise, a failing test case is indicated.
#
#Note: The unit must be "MB" or "GB", others such as mb, gb,
#      m, kb, and so on doesn't work well
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

echo "Covers CORE-09" > ~/summary.log

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
# Check the memory of VM  
#
echo "VMEM = ${VMEM}" >> ~/summary.log

memCapacity=`dmesg | grep "real memory" | cut -d "=" -f 2 | sed 's/(.*)/ /g'  | tr -d " "`
echo "Found ${memCapacity} memory"

number=`echo $VMEM | tr -d -c '0-9'`
unit=`echo $VMEM | tr -d -c 'a-zA-Z'`

#For comparing, change GB or MB to Bytes
if [ "$unit"x = "GB"x ]; then
    VMEM_Bytes=`echo "$number * 1024 * 1024 * 1024" | bc`
elif [  "$unit"x = "MB"x ]; then
    VMEM_Bytes=`echo "$number * 1024 * 1024" | bc`
fi

exitSts=10
if [ "$memCapacity"x  = "$VMEM_Bytes"x ]; then
    UpdateTestState $ICA_TESTCOMPLETED
    echo "Test case PASSED"
	exitSts=0
else
	UpdateTestState $ICA_TESTFAILED
    echo "Test case FAILED"
fi

exit $exitSts

