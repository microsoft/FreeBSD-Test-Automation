#!/bin/bash
#
# Small_Files.sh
#
# Description:
#    Copies 10000 small files from Respository Server using NFS
#    
####################################################################

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

rm -f ~/summary.log
touch ~/summary.log
echo "Covers: TC127" >> ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
LogMsg "Loading constants.sh"

if [ -e ~/${CONSTANTS_FILE} ]; then
    source ~/${CONSTANTS_FILE}
else
    LogMsg "Error: no ~/${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure all required variables are defined in constants.sh
#
if [ ${REPOSITORY_SERVER:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable REPOSITORY_SERVER"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ ${REPOSITORY_EXPORT}:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants did not define the variable REPOSITORY_EXPORT"
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

LogMsg "REPOSITORY_SERVER = ${REPOSITORY_SERVER}"
LogMsg "REPOSITORY_EXPORT = ${REPOSITORY_EXPORT}"

#
# Mount the NFS share on the repository server and copy the manyfiles directory
#
LogMsg "Copying files from repository server"
rm -rf ~/usr/myfiles

LogMsg "mount -t nfs ${REPOSITORY_SERVER}:${REPOSITORY_EXPORT} /mnt" 
mount -t nfs  ${REPOSITORY_SERVER}:${REPOSITORY_EXPORT} /mnt &
sleep 5  
if [ ! -e /mnt/manyfiles ]; then
	kill -9 `ps aux | grep mount | awk '{print $2}'`
	echo "Try it again with nfsv4." >> ~/summary.log
    sleep 3   #Make sure kill "mount" process
	mount -t nfs -o nfsv4 ${REPOSITORY_SERVER}:${REPOSITORY_EXPORT} /mnt &
	sleep 5
	if [ ! -e  /mnt/manyfiles ]; then
		kill -9 `ps aux | grep mount | awk '{print $2}'`
		LogMsg "Error: Repository server does not have manyfiles directory"
		UpdateTestState $ICA_TESTFAILED
		echo "Find files  : Failed" >> ~/summary.log
		exit 40
	fi
fi

Size1=`cat /mnt/Size | cut -c 1-5`
Count1=`ls /mnt/manyfiles/ |wc -l`

mkdir /usr/myfiles

START=`date "+%s"`

cp -r /mnt/manyfiles/ /usr/myfiles
if [ ! -e /usr/myfiles ]; then
    LogMsg "Error: VM does not have myfiles directory"
    UpdateTestState $ICA_TESTFAILED
    echo "Copy files  : Failed" >> ~/summary.log
    exit 50
fi

END=`date "+%s"`
DIFF=`expr ${END} - ${START}`

Min=`expr ${DIFF} / 60`
Sec=`expr ${DIFF} % 60`

cd /usr

LogMsg "unmount /mnt"
umount /mnt

LogMsg "Time taken to copy files is $Min minutes and $Sec seconds"
echo "Time taken to copy files is $Min minutes and $Sec seconds" >> ~/summary.log

du -sk /usr/myfiles > /usr/Size

Size2=`cat /usr/Size | cut -c 1-5`
Count2=`ls /usr/myfiles/ |wc -l`

#
# Check if size and count of files is same
#
 if [ ${Size1} != ${Size2} ]; then
    # LogMsg "Error: Size varies"
    LogMsg "Size1 ${Size1}  Size2 ${Size2} Error: Size varies"
    UpdateTestState $ICA_TESTFAILED
    echo "Files size varies : Failed" >> ~/summary.log
    exit 60
fi

if [ ${Count1} != ${Count2} ]; then
    LogMsg "Error: Count varies"
    UpdateTestState $ICA_TESTFAILED
    echo "Files count varies  : Failed" >> ~/summary.log
    exit 70
fi

#
# Remove copied files
#
rm -rf ~/usr/myfiles
 
#
# If we made it here, everything worked.  Let ICA know
# the test completed successfully
#
LogMsg "Small_files test completed successfully"
UpdateTestState $ICA_TESTCOMPLETED

exit 0