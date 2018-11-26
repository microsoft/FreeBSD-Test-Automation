#!/bin/bash
#
# copyExceedDiskSize.sh
#
# Description:
#    This script will fdisk a new drive, format the drive, and 
#    then try to copy a file from a NFS server that is too big
#    to fit on the new volume.  The steps are:
#       1. Make sure the device file was created
#       2. fdisk the device
#       3. newfs the device
#       4. Mount the device
#       5. Mount the NFS filesystem
#       6. Copy a large file from the NFS filesystem
#       7. Make sure the copy error is no space on device
#
#     Test parameters used by this scripts are:
#         TEST_DEVICE    : It will be assigned a value like ad3
#         NFS_SERVER     : The name or IP address of the NFS server
#         NFS_EXPORT     : The nsf export path
#         LARGE_FILENAME : Name of the very large file to copy 
#         TC_COVERED     : Test cases covered by this test
#
#####################################################################

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"
ICA_TESTFAILED="TestFailed"


UpdateTestState()
{
    echo $1 > $HOME/state.txt
}


#
# Let ICA know we are running
#
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
if [ -e ~/constants.sh ]; then
    . ~/constants.sh
else
    msg="ERROR: Unable to source the constants file."
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh defines the test parameters we need
#
if [ ${TEST_DEVICE:-UNDEFINED} = "UNDEFINED" ]; then
    msg="Error: constants.sh did not define the variable TEST_DEVICE"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ ${TC_COVERED:-UNDEFINED} = "UNDEFINED" ]; then
    msg="Error: constants.sh did not define the variable TC_COVERED"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 25
fi

if [ ${NFS_SERVER:-UNDEFINED} = "UNDEFINED" ]; then
    msg="Error: constants.sh did not define the variable NFS_SERVER"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 40
fi

if [ ${NFS_EXPORT:-UNDEFINED} = "UNDEFINED" ]; then
    msg="Error: constants.sh did not define the variable NFS_EXPORT"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 50
fi

if [ ${LARGE_FILENAME:-UNDEFINED} = "UNDEFINED" ]; then
    msg="Error: constants.sh did not define the variable LARGE_FILENAME"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 60
fi

echo "TEST_DEVICE    = ${TEST_DEVICE}"
echo "NFS_SERVER     = ${NFS_SERVER}"
echo "NFS_EXPORT     = ${NFS_EXPORT}"
echo "LARGE_FILENAME = ${LARGE_FILENAME}"

echo "Covers ${TC_COVERED}" >> ~/summary.log
echo "Target device = ${TEST_DEVICE}" >> ~/summary.log

#
# Overwrite any existing partition table.  Then fdisk the device.
#
dd if=/dev/zero of=${TEST_DEVICE} bs=1k count=1
if [ $? -ne 0 ]; then
    msg="Error: Unable to zero first 1K of ${TEST_DEVICE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 70
fi

gpart create -s GPT ${TEST_DEVICE}
if [ $? -ne 0 ]; then
    msg="Error: Unable to create GPT on ${TEST_DEVICE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi

gpart add -t freebsd-ufs ${TEST_DEVICE}
if [ $? -ne 0 ]; then
    msg="Error: Unable to add freebsd-ufs slice to ${TEST_DEVICE}"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 90
fi

#
# Now format the device
#
newfs ${TEST_DEVICE}p1
if [ $? -ne 0 ]; then
    msg="Error: Unable to format the device ${TEST_DEVICE}p1"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 100
fi

#
# Mount the new drive
#
echo "mount ${TEST_DEVICE}p1 /mnt"
mount ${TEST_DEVICE}p1 /mnt
if [ $? -ne 0 ]; then
    msg="Error: Unable mount device ${TEST_DEVICE}p1"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 110
fi

#
# Mount the NFS share
#
echo "mount -t nfs ${NFS_SERVER}:4{NFS_EXPORT} /nfs"

if [ ! -e /nfs ]; then
    mkdir /nfs
fi

mount -t nfs  ${NFS_SERVER}:${NFS_EXPORT} /nfs &
sleep 5  
if [ ! -e /nfs/testdata ]; then
	kill -9 `ps aux | grep mount | awk '{print $2}'`
	echo "Try it again with nfsv4." >> ~/summary.log
    sleep 3   #Make sure kill "mount" process
	mount -t nfs -o nfsv4 ${NFS_SERVER}:${NFS_EXPORT} /nfs &
	sleep 5
	if [ ! -e  /nfs/testdata ]; then
		kill -9 `ps aux | grep mount | awk '{print $2}'`
		LogMsg "Error: Repository server does not have testdata directory"
		UpdateTestState $ICA_TESTFAILED
		echo "Can't mount  : Failed" >> ~/summary.log
		exit 130
	fi
fi


#
# Copy the large file to the small device
#
if [ ! -e /nfs/testdata/${LARGE_FILENAME} ]; then
    msg="File ${LARGE_FILENAME} does not exist on nfs export"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 140
fi

echo "cp /nfs/testdata/${LARGE_FILENAME} /mnt/"

cp /nfs/testdata/${LARGE_FILENAME} /mnt/ 2>cpError.txt
if [ $? -eq 0 ]; then
    msg="Error: ${LARGE_FILENAME} did not fill the volume."
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 150
fi

#
# make sure the error was No space on device
#
errMsg=`cat cpError.txt`
n=`echo $errMsg | cut -f 3 -d ' '`
s=`echo $errMsg | cut -f 4 -d ' '`

echo "Copy error should be No space on device"
echo "Copy error = ${errMsg}"

if [ $n != "No" ]; then
    msg="Failed for reason other than device full"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 160
fi

if [$s != "space" ]; then
    msg="Failed for reason other than device full"
    echo $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 170
fi

echo "umount /nfs"
umount /nfs

echo "umount /mnt"
umount /mnt

UpdateTestState $ICA_TESTCOMPLETED

exit 0


