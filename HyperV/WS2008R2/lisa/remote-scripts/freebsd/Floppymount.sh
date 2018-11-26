#!/bin/bash
#
# Floppymount.sh
#
# To mount Floppy drive on FreeBSD
# This script mount Floppy drive and unmounts it
#    
#     
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
# Cleanup from any previous test run
#
if [ -e ~/summary.log ]; then
    rm -rf ~/summary.log
fi
touch ~/summary.log

#
# Source constants.sh
#
if [ -e ~/${CONSTANTS_FILE} ]; then
    . ~/${CONSTANTS_FILE}
else
    LogMsg "ERROR: Unable to source the constants file."
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh defines the test parameters we need
#
if [ ${TC_COVERED:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

echo "Covers ${TC_COVERED}" >> ~/summary.log

#
# Check if floppy drive exists
#
ls /dev > ~/devices.txt

grep -q "fd0" ~/devices.txt
if [ $? -ne 0 ] ; then
    LogMsg "Floppy drive not found"
	echo "Floppy dive not found" >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
	exit 10
fi

#
# To mount Floppy drive
#
LogMsg "Mounting Floppy drive"
mount_msdosfs /dev/fd0 /mnt
if [ $? -ne 0 ]; then
    LogMsg "Mounting of Floppy drive Fail"
    echo "Mounting Floppy drive   : Failed" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
    exit 20
fi
echo "Mounting Floppy drive   : Passed" >>  ~/summary.log

LogMsg "Changing directory"
cd /mnt

LogMsg "Listing files"
ls

LogMsg "Creating a file"
cat <<EOF > Floppy.txt
This is just a trial
Creation of file is successful
EOF
if [ $? -ne 0 ]; then
    LogMsg "Creating file Fail"
    echo "Creating file           : Failed" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
    exit 30
fi

LogMsg "Displaying file content"
cat Floppy.txt
if [ $? -ne 0 ]; then
    LogMsg "Showing file content Fail"
    echo "Showing file content   : Failed" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
    exit 40
fi

LogMsg "Removing File"
rm Floppy.txt
if [ $? -ne 0 ]; then
    LogMsg "Removing file Fail"
    echo "Removing file           : Failed" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
    exit 50
fi

LogMsg "Come out of directory"
cd

LogMsg "Unmounting Floppy drive"
umount /mnt
if [ $? -ne 0 ]; then
    LogMsg "Unmounting of Floppy drive Fail"
    echo "Unmounting Floppy drive : Failed" >> ~/summary.log
	UpdateTestState $ICA_TESTFAILED
    exit 60
fi
echo "Unmounting Floppy drive : Passed" >>  ~/summary.log

#
# Let ICA know we completed successfully
#
echo "Mounting Floppy Drive test completed" >> ~/summary.log
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

