#!/bin/bash
#
# BuildKernel.sh
#
# Description:
#    To build monolithic kernel
#	 
#      
#    Variables from constants.sh used by this script:
#     REPOSITORY_SERVER
#      The name, or IP address of a repository server. The repository server
#      pulls down the current project source code nightly and creates tar files.
#      Example:  REPOSITORY_SERVER = 10.200.41.228
#
#     REPOSITORY_EXPORT
#      The name of the NFS export on the repository server that contain
#      the tar files of the FreeBSD project.
#      Example:  REPOSITORY_EXPORT = /usr/lisa/public
#
#     DEBUG
#      A build flag that controls whether the kernel is built with Witness
#      and invariants.  Set DEBUG to 1 to enable Witness and Invariants.
#      Example:  DEBUG = 0
#
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
echo "Covers: TC1, TC2" >> ~/summary.log

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
# Mount the NFS share on the repository server and copy the current
# freebsd tarball
#
LogMsg "Copying tarball from repository server"
rm -rf ~/freebsd-current.tar

LogMsg "mount -t nfs ${REPOSITORY_SERVER}:${REPOSITORY_EXPORT} /mnt" 
mount -t nfs ${REPOSITORY_SERVER}:${REPOSITORY_EXPORT} /mnt
if [ ! -e /mnt/archives ]; then
    LogMsg "Error: Repository server does not have an archives directory"
    UpdateTestState $ICA_TESTFAILED
    echo "Cloned GitHub  : Failed" >> ~/summary.log
    exit 40
fi

if [ ! -e /mnt/archives/freebsd-current.tar.bz2 ]; then
    LogMsg "Error: freebsd-current.tar.bz2 file does not exist"
    UpdateTestState $ICA_TESTFAILED
    echo "Cloned GitHub  : Failed" >> ~/summary.log
    exit 50
fi

#
# cd into the nfs export so relative symlinks can be followed
#
cd /mnt/archives

LogMsg "cp ./freebsd-current.tar.bz2 /usr/"
cp ./freebsd-current.tar.bz2 /usr/
if [ $? -ne 0 ]; then
    LogMsg "Error: Unable to copy freebsd-current.tar.bz2 from repository server export"
    UpdateTestState $ICA_TESTFAILED
    echo "Cloned GitHub  : Failed" >> ~/summary.log
    exit 60
fi

echo "Cloned GitHub  : Passed" >> ~/summary.log
cd /usr

LogMsg "unmount /mnt"
umount /mnt

#
# Untar the tarball and make sure a freebsd direcgtory was created
#
LogMsg "Info : tar -xf ./freebsd-current.tar.bz2"

if [ ! -e ./freebsd-current.tar.bz2 ]; then
    LogMsg "Error: the freebsd-current.tar.bz2 file was not copied"
    UpdateTestState $ICA_TESTFAILED
    exit 65
fi

tar -xf ./freebsd-current.tar.bz2
if [ $? -ne 0 ]; then
    LogMsg "Error: Unable to extract files from freebsd-current.tar.bz2"
    UpdateTestState $ICA_TESTFAILED
    exit 70
fi

if [ ! -e ./freebsd ]; then
    LogMsg "Error: The git clone did not create the directory /usr/freebsd"
    echo "Clone GitHub   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi

#
# Build the kernel
#
LogMsg "Building the FreeBSD kernel"

cd /usr/freebsd
gitbranch=`git branch | cut -f 2 -d ' '`
echo "Branch         : ${gitbranch}" >> ~/summary.log

#
# Write the last check-in date to summary.log
#
git log | head -n 5 |
while read line
do
    if [[ $line =~ ^Date: ]]; then
        echo "Last check-in  : ${line:8}" >> ~/summary.log
	break
    fi
done

if [ $DEBUG == 1 ]; then
	echo "options     INVARIANTS" >> sys/amd64/conf/HYPERV_VM
	echo "options     INVARIANT_SUPPORT" >> sys/amd64/conf/HYPERV_VM
	echo "options     WITNESS" >> sys/amd64/conf/HYPERV_VM
	echo "options     KDB" >> sys/amd64/conf/HYPERV_VM
	echo "options     DDB" >> sys/amd64/conf/HYPERV_VM
	echo "options     KDB_TRACE" >> sys/amd64/conf/HYPERV_VM
	echo "Debug enabled  : Yes" >> ~/summary.log
fi

make -j4 buildkernel KERNCONF=HYPERV_VM -DNO_CLEAN
if [ $? != 0 ]; then
    LogMsg "Error: The kernel build failed"
    echo "Build Kernel   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 90
fi
echo "Build Kernel   : Passed" >> ~/summary.log

#
# Install the kernel
#
LogMsg "Installing the FreeBSD kernel"

make installkernel KERNCONF=HYPERV_VM
if [ $? != 0 ]; then
    LogMsg "Error: The kernel install failed"
    echo "Install Kernel : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 100
fi
echo "Install Kernel : Passed" >> ~/summary.log

#
# Check that the hyper-V symbols are in the kernel
#
LogMsg "Checking the new kernel has the Hyper-V components"

hvCount=`strings /boot/kernel/kernel | grep hv_ | wc -l`
if [ $hvCount -lt 20 ]; then
    LogMsg "Error: The Hyper-V functions are not part of the new kernel"
    echo "Verify Kernel : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 110
fi
echo "Verify Kernel  : Passed" >> ~/summary.log

#
# Set a boot option to get past a bug
#
#echo "hw.ata.disk_enable=1" >> /boot/loader.conf
#if [ $? != 0 ]; then
#    echo "Error: Unable to set boot option in /boot/loader.conf"
#    echo "Set boot option: Failed" >> ~/summary.log
#    UpdateTestState $ICA_TESTFAILED
#    exit 120
#fi

#
# If we made it here, everything worked.  Let ICA know
# the test completed successfully
#
LogMsg "BuildKernel test completed successfully"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

