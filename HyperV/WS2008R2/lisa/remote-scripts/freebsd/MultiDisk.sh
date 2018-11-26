#!/bin/bash
#
# MultiDisk.sh
#
# Description:
#    This script was created to automate the testing of a FreeBSD
#    Integration services.  This script test the detection of disks  
#    inside the Linux VM by performing the following
#    Steps:
#       1. Make sure the device file was created
#       2. fdisk the device
#       3. newfs the device
#       4. Mount the device
#       5. Create a directory on the device
#       6. Copy a file to the directory
#       7. Unmount the device
#
#     Test parameters used by this scripts are:
#        NO: Number of disks attached
#           Example: If we have SCSI=0,0
#                               SCSI=0,1
#                    Then NO=2
#
#     Note: Only supports BIS driver
#
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
    LogMsg "ERROR: Unable to source the constants file."
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh defines the test parameters we need
#
if [ ${NO:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable TEST_DEVICE"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ ${TC_COVERED:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi


echo "Covers ${TC_COVERED}" >> ~/summary.log
echo "Number of disks attached : $NO" >> ~/summary.log

#
#Operations performed on disks
#
i=1
while [ $i -le $NO ]
do
    LogMsg "TEST DEVICE is /dev/da${i}"
    echo "TEST DEVICE is /dev/da${i}" >> ~/summary.log

    DEVICE=~/disk.txt
    ls /dev > $DEVICE

    DISK=`echo /dev/da$i|cut -c 6-8`
    grep -q "${DISK}p1" $DEVICE
    if [ $? -eq 0 ]; then
        LogMsg "Deleting filesystem"
        gpart delete -i 1 "${DISK}"
        gpart destroy "${DISK}"
	else
	    LogMsg "No filesystem exits"
    fi

    sleep 2

    gpart create -s GPT /dev/da${i}
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to create GPT on /dev/da${i}"
        UpdateTestState $ICA_TESTFAILED
    exit 40
    fi

    gpart add -t freebsd-ufs /dev/da${i}
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to add freebsd-ufs slice to /dev/da${i}"
        UpdateTestState $ICA_TESTFAILED
    exit 50
    fi

    newfs /dev/da${i}p1
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to format the device /dev/da${i}p1"
        UpdateTestState $ICA_TESTFAILED
    exit 60
    fi

    LogMsg "mount /dev/da${i}p1 /mnt"
    mount /dev/da${i}p1 /mnt
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable mount device ${TEST_DEVICE}p1"
        UpdateTestState $ICA_TESTFAILED
    exit 70
    fi

    TARGET_DIR="/mnt/IcaTest"
    LogMsg "mkdir ${TARGET_DIR}"
    mkdir ${TARGET_DIR}
    if [ $? -ne 0 ]; then
        LogMsg "Error: unable to create ${TARGET_DIR}"
        UpdateTestState $ICA_TESTFAILED
    exit 80
    fi

    LogMsg "cp ~/*.sh ${TARGET_DIR}"
    cp ~/*.sh ${TARGET_DIR}
    if [ $? -ne 0 ]; then
        LogMsg "Error: unable to copy files to ${TARGET_DIR}"
        UpdateTestState $ICA_TESTFAILED
    exit 90
    fi

    if [ ! -e "${TARGET_DIR}/constants.sh" ]; then
        LogMsg "Error: Write to disk failed"
        UpdateTestState $ICA_TESTFAILED
    exit 100
    fi

    LogMsg "rm -f ${TARGET_DIR}/constants.sh"
    rm -f ${TARGET_DIR}/constants.sh
    if [ -e "${TARGET_DIR}/constants.sh" ]; then
        LogMsg "Error: Delete of file on disk failed"
        UpdateTestState $ICA_TESTFAILED
    exit 110
    fi

    LogMsg "umount /mnt"
    umount /mnt
    if [ $? -ne 0 ]; then
        LogMsg "Error: unable to unmount /mnt"
        UpdateTestState $ICA_TESTFAILED
    exit 120
    fi
	i=$[$i+1]
done
#
#If we are here test is completed successfully
#
UpdateTestState $ICA_TESTCOMPLETED

exit 0