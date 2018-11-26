#!/usr/local/bin/bash
#
# Template for creating ICA test case scripts to
# run on Linux distributions.
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

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ~/${CONSTANTS_FILE} ]; then
    source ~/${CONSTANTS_FILE}
else
    echo "Info: no ${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh defined the variables we need 
#
if [ ${TEST_DEVICE:-UNDEFINED} = "UNDEFINED" ]; then
    echo "Error: constants.sh did not define the variable TEST_DEVICE"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ ! -e $TEST_DEVICE ]; then
    echo "Error: The test device ${TEST_DEVICE} does not exist"
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

if [ ${BLOCK_SIZES:-UNDEFINED} = "UNDEFINED" ]; then
    echo "Error: constants.sh did not define the variable BLOCK_SIZES"
    UpdateTestState $ICA_TESTABORTED
    exit 40
fi

#
# Delete any old summary.log and create a fresh one
#
rm -f ~/summary.log
touch ~/summary.log

#
# Set the field separater to use when parsing $BLOCK_SIZES
# Then call dd once for each block size
#
IFS=","

for bs in ${BLOCK_SIZES}
do
    echo "dd if=/dev/mem of=${TEST_DEVICE} skip=8 bs=${bs}"
    results=`dd if=/dev/mem of=${TEST_DEVICE} skip=8 bs=${bs} 2>&1 | tail -n 1`
    echo -e "${results}\n"
    echo "Blocksize ${bs}:  ${results}" >> ~/summary.log
done

#
# Let ICA know we completed successfully
#
echo "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

