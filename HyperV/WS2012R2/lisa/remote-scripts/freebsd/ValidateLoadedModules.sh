#!/bin/bash 
#
# TC-CheckCPUCount.sh
#
# Verify the BIS modules are loaded.  This test case script
# assumes the kernel was built with loadable BIS modules.
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


LogMsg()
{
    echo "$1"
}



#
# Create the state.txt file so ICA knows we are running
#
LogMsg "Test Case ValidateLoadableModules"
LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

LogMsg "Covers TC14" > ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    LogMsg "Info: no ${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Verify the various Hyper-V modules are loaded
#

#
# Is hv_vmbus loaded
#
kldstat | grep -q hv_vmbus.ko
if [ $? -ne 0 ]; then
    LogMsg "Error: hv_vmbus.ko is not loaded"
    echo "hv_vmbus.ko is not loaded" >> ~/summary.log
    exit 20
fi

#
# Is hv_utils loaded
#
kldstat | grep -q hv_utils.ko
if [ $? -ne 0 ]; then
    LogMsg "Error: hv_utils.ko is not loaded"
    echo "hv_utils.ko is not loaded" >> ~/summary.log
    exit 30
fi

#
# Is hv_netvsc loaded
#
kldstat | grep -q hv_netvsc.ko
if [ $? -ne 0 ]; then
    LogMsg "Error: hv_netvsc.ko is not loaded"
    echo "hv_netvsc.ko is not loaded" >> ~/summary.log
    exit 40
fi

#
# Is hv_storvsc loaded
#
kldstat | grep -q hv_storvsc.ko
if [ $? -ne 0 ]; then
    LogMsg "Error: hv_storvsc is not loaded"
    echo "hv_storvsc.ko is not loaded" >> ~/summary.log
    exit 50
fi

#
# If we made it here, all the checks passed
#
LogMsg "All modules loaded"
exit 0

