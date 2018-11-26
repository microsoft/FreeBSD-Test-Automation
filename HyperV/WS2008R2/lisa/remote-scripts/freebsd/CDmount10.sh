#!/bin/bash
#
# CDmount.sh
#
# To mount CD drive on FreeBSD
# This script mount CD drive and unmounts it
#  
#    Variables used in the xml are:
# 
#     IsoFilename
#        The name of iso that is used to mount. 
#
#############################################################


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
# Delete any summary.log files from a previous run
#
rm -f ~/summary.log
echo "Covers: TC13" > ~/summary.log


#
# To mount CD drive
#
mkdir /cdrom

mount_cd9660 /dev/cd0 /cdrom
if [ $? -ne 0 ]; then
    LogMsg "Mounting of CD drive Fail"
    echo "Mounting CD drive   : Failed" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
    exit 10
fi
echo "Mounting CD drive   : Passed" >>  ~/summary.log

#
# list files
#
LogMsg "Listing CD contents"
ls /cdrom


#
# Unmount CD drive
#
umount /cdrom
if [ $? -ne 0 ]; then
    LogMsg "Unmounting of CD drive Fail"
    echo "Unmounting CD drive : Failed" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
    exit 20
fi
echo "Unmounting CD drive : Passed" >>  ~/summary.log
#
# If you have an error, handle the error. When terminating the
# test case, set the status to either ICA_TESTABORTED or
# ICA_TESTFAILED.
#
# UpdateTestState $ICA_TESTFAILED
# exit 1
#
# or
#
# Let ICA know we completed successfully
#
echo "Mounting CD Drive test completed" >> ~/summary.log
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

