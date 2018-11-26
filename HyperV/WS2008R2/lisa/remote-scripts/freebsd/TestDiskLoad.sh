#!/bin/bash
#
# AddNewDisk_New.sh
#
# Description:
#    This script was created to automate the testing of a FreeBSD
#    Integration services.  This script test the detection of a disk  
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
#   This test script will test a load of 256 disks                    
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
if [ ${TC_COVERED:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi
if [ ${DISKS_PER_CONTROLLER:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi
if [ ${MAX_CONTROLLERS:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

echo "Covers ${TC_COVERED}" >> ~/summary.log
LogMsg "Testing the SCSI disk load, Script will format, mount & copy files to 256 disks attached" 
TotalDisks=$MAX_CONTROLLERS*$DISKS_PER_CONTROLLER
i=1
while [ $i -le $TotalDisks ]
do
    j=da$i
    
    LogMsg "TEST_DEVICE = ${j}"
        
    #echo "Target device = ${j}" >> ~/summary.log

#
# Overwrite any existing partition table.  Then fdisk the device.
#
# dd if=/dev/zero of=${TEST_DEVICE} bs=1k count=1
# if [ $? -ne 0 ]; then
    # echo "Error: Unable to zero first 1K of ${TEST_DEVICE}"
    # UpdateTestState $ICA_TESTFAILED
    # exit 30
# fi

    #
    # Delete existing filesystem 
    #

    DEVICE=~/disk.txt
    ls /dev > $DEVICE

    #DISK=`echo ${j} | cut -c 6-8`
	grep -q "${j}p1" $DEVICE
    if [ $? -eq 0 ]; then
        LogMsg "Deleting filesystem"
        gpart delete -i 1 "${j}"
        gpart destroy "${j}"
	else
	    LogMsg "No filesystem exits"
    fi
    LogMsg "deleted - ${j}	"
    sleep 2
    LogMsg "Creating partition"
    gpart create -s GPT ${j}
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to create GPT on ${j}"
        UpdateTestState $ICA_TESTFAILED
        exit 40
    fi

    gpart add -t freebsd-ufs ${j}
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to add freebsd-ufs slice to ${j}"
        UpdateTestState $ICA_TESTFAILED
        exit 50
    fi

    newfs ${j}p1
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to format the device ${j}p1"
        UpdateTestState $ICA_TESTFAILED
        exit 60
    fi

    LogMsg "mount /dev/${j}p1 /mnt"
    mount /dev/${j}p1 /mnt
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable mount device ${j}p1"
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

    LogMsg "rm -f ${TARGET_DIR}/*.sh"
    rm -f ${TARGET_DIR}/*.sh
    if [ -e "${TARGET_DIR}/constants.sh" ]; then
        LogMsg "Error: Delete of file on disk failed"
        UpdateTestState $ICA_TESTFAILED
        exit 110
    fi
    
    LogMsg "rmdir  ${TARGET_DIR}"
    rmdir  ${TARGET_DIR}
    if [ $? -ne 0 ]; then
        LogMsg "Error: Deleting the created directory"
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
#If we are here test executed successfully
#
echo "Successfully tested SCSI disks load of ${TotalDisks} disks by format, mount & copy files to it" >> ~/summary.log
UpdateTestState $ICA_TESTCOMPLETED

exit 0

