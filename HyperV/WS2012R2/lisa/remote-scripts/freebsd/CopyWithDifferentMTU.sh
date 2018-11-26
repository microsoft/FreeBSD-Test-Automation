#!/bin/bash
#
# CopyWithDiffrentMTU.sh
#
# copy a large file (1GB) from a remote vm with key through scp. 
# Parameters required:
#    TARGET_ADDR
#    TARGET_PATH
#    LARGE_FILENAME

# TARGET_ADDR is the address of the remote vm.
# TARGET_PATH is the file directory on the remote vm.
# LARGE_FILENAME is the name of the large file in remote vm.

# The script will mount the nfs share and copy the $LARGE_FILENAME
# and a file named md5sum.  The file md5sum contains the md5sum
# of the $LARGE_FILENAME.  If the md5sum matches the copied files
# md5sum, the test case passes.
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

#
# Make sure constants.sh has the test parameters we require
#
echo "Checking contents of constants.sh"
if [ "${TARGET_ADDR:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="Test param TARGET_ADDR is missing from constants.sh"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ "${TARGET_PATH:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="Test param TARGET_PATH is missing from constants.sh"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

if [ "${LARGE_FILENAME:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="Test param LARGE_FILENAME is missing from constants.sh"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 40
fi

if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

echo "Covers ${TC_COVERED}" > ~/summary.log

#
# Cope the large file
#
Local_PATH="/root/testdata"
rm -rf  $Local_PATH  #Deleting any files from a previous test run


for mtu_size in 1152 9216
do 
	#Change mtu
	ifconfig hn0 mtu ${mtu_size}
	vlaue=`ifconfig hn0 | grep mtu | cut -d " " -f 6`
    msg="Current MTU is : ${vlaue}"
	echo $msg >> ~/summary.log

	echo "Start to copy the ${LARGE_FILENAME} from ${TARGET_ADDR}. Please wait."
	scp -i /root/.ssh/id_rsa_test -r root@${TARGET_ADDR}:${TARGET_PATH}  $Local_PATH
	if [ $? -ne 0 ]; then
		msg="Copy file from ${TARGET_ADDR} failed."
		echo $msg
		echo $msg >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 60
	fi

	if [ ! -e ${Local_PATH}/md5sum ]; then
		msg="The file md5sum doesn't exist"
		echo $msg
		echo $msg >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 60
	fi

	if [ ! -e ${Local_PATH}/${LARGE_FILENAME} ]; then
		msg="The file ${LARGE_FILENAME} doesn't exist"
		echo $msg
		echo $msg >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 60
	fi


	#
	# Check the MD5Sum
	#
	echo "Checking the md5sum of the file"
	sum=`cat ${Local_PATH}/md5sum | cut -f 4 -d ' '`
	fileSum=`md5 ${Local_PATH}/${LARGE_FILENAME} | cut -f 4 -d ' '`
	if [ "$sum" != "$fileSum" ]; then
		msg="md5sum of copied file does not match"
		echo $msg
		echo $msg >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 90
	fi

	rm -rf  $Local_PATH
	sleep 1
done

#Set the default mtu value	
ifconfig hn0 mtu 1500

#
# Let ICA know the test completed successfully
#
echo "Test completed successfully"

UpdateTestState $ICA_TESTCOMPLETED

exit 0

