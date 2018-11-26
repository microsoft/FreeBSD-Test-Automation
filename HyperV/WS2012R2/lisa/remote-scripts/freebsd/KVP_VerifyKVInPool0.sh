#!/bin/bash
#
# KVP_VerifyKVInPool0.sh
#
# This script will verify that the Key value pair is added to the Pool 0 only. 
# The Parameters provided are - Test case number, Key Name. Value
# This test should be run after the KVP Basic test.
#
#############################################################


ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

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
# Delete any summary.log files from a previous run
#
rm -f ~/summary.log
touch ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ~/constants.sh ]; then
    . ~/constants.sh
else
    LogMsg "ERROR: Unable to source the constants file."
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi
if [ "${Key:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter Key is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi
if [ "${Value:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter Value is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

#
# Echo TCs we cover
#
echo "Covers ${TC_COVERED}" > ~/summary.log
	
# Make sure we have the kvp_client tool
#
if [ ! -e ~/kvp_client ]; then
    msg="Error: kvp_client tool is not on the system"
    LogMsg "$msg"
    echo "$msg" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 60
fi

chmod 755 ~/kvp_client
	
#
# verify that the Key Value is added to the Pool0 only
#
for i in 0 1 2 3 4
do
  ~/kvp_client -l -p $i | grep "${Key}; Value : ${Value}"
  if [ $? -ne 0 ]; then
    continue
  elif [ $i -eq 0 ]; then
    LogMsg "key value pair is found in pool 0" 
    break
  else
    echo "key value pair is found in pool ${i}, so failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 10
  fi
done
echo "Verified that the added Key value is present in pool 0 only" >> ~/summary.log
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED
exit 0
