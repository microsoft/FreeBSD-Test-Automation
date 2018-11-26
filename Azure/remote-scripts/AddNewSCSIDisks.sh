#!/bin/bash
#
# AddNewSCSIDisks.sh
#
# Description:
#    This script test the detection of a disk inside the Linux VM by performing the following steps:
#       1. Make sure the device file was created
#       2. fdisk the device
#       3. newfs the device
#       4. Mount the device
#       5. Create a directory on the device
#       6. Copy a file to the directory
#       7. Unmount the device
#
#     Test parameters used by this scripts are:
#        $1 : Number of disks
#####################################################################

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"
ICA_TESTFAILED="TestFailed"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}


UpdateTestState()
{
    echo $1 > $HOME/state.txt
}

UpdateTestState $ICA_TESTRUNNING

touch $HOME/summary.log

echo "Number of disks attached : $1" >> ~/summary.log

let NO=$1+1
i=2
while [ $i -le $NO ]
do
	device="/dev/da${i}"

    gpart create -s GPT $device
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to create GPT on $device"
		echo "Error: Unable to create GPT on $device" >> ~/summary.log
		echo "Maybe the device $device doesn't exist, so check the /dev/ via 'ls /dev/da* /dev/ad*' command and its results are:  " >> ~/summary.log
		ls /dev/da*  /dev/ad* >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 40
    fi

    gpart add -t freebsd-ufs $device
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to add freebsd-ufs slice to ${TEST_DEVICE}"
		echo "Error: gpart add -t freebsd-ufs ${device} failed" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 50
    fi

    newfs ${device}p1
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to format the device ${device}p1"
		echo "Error: Unable to format the device ${device}p1" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 60
    fi

    LogMsg "mount ${device}p1 /mnt"
    mount ${device}p1 /mnt
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable mount device ${device}p1"
		echo "Error: Unable mount device ${device}p1" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 70
    fi

    TARGET_DIR="/mnt/IcaTest"
    LogMsg "mkdir ${TARGET_DIR}"
    mkdir ${TARGET_DIR}
    if [ $? -ne 0 ]; then
        LogMsg "Error: unable to create ${TARGET_DIR}"
		echo "Error: unable to create ${TARGET_DIR}" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 80
    fi

    LogMsg "cp ~/*.sh ${TARGET_DIR}"
    cp  /var/log/*.log ${TARGET_DIR}
    if [ $? -ne 0 ]; then
        LogMsg "Error: unable to copy files to ${TARGET_DIR}"
		echo "Error: unable to copy files to ${TARGET_DIR}" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 90
    fi

    if [ ! -e "${TARGET_DIR}/waagent.log" ]; then
        LogMsg "Error: Write to disk(${device}p1) failed"
		echo "Error: Write to disk(${device}p1) failed" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 100
    fi

    LogMsg "rm -f ${TARGET_DIR}/waagent.log"
    rm -f ${TARGET_DIR}/waagent.log
    if [ -e "${TARGET_DIR}/waagent.log" ]; then
        LogMsg "Error: Delete of file on disk(${device}p1) failed"
		echo "Error:  Delete of file on disk(${device}p1) failed" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 110
    fi

    LogMsg "umount /mnt"
    umount /mnt
    if [ $? -ne 0 ]; then
        LogMsg "Error: unable to unmount /mnt"
		echo "Error: unable to unmount /mnt" >> ~/summary.log
        UpdateTestState $ICA_TESTFAILED
        exit 120
    fi
    let i=$i+1
done

#If we are here test executed successfully
UpdateTestState $ICA_TESTCOMPLETED

exit 0

