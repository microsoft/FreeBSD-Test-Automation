#!/bin/bash
#
# Template for creating ICA test case scripts to
# run on Linux distributions.
#

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

rm -f ~/summary.log
touch ~/summary.log
echo "Covers: TC1, TC2" >> ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
echo "Loading constants.sh"

if [ -e ~/${CONSTANTS_FILE} ]; then
    source ~/${CONSTANTS_FILE}
else
    echo "Error: no ~/${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure all required variables are defined in constants.sh
#
if [ ${REPOSITORY_SERVER:-UNDEFINED} = "UNDEFINED" ]; then
    echo "Error: constants.sh did not define the variable REPOSITORY_SERVER"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ ${REPOSITORY_EXPORT}:-UNDEFINED} = "UNDEFINED" ]; then
    echo "Error: constants did not define the variable REPOSITORY_EXPORT"
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

echo "REPOSITORY_SERVER = ${REPOSITORY_SERVER}"
echo "REPOSITORY_EXPORT = ${REPOSITORY_EXPORT}"

#
# Mount the NFS share on the repository server and copy the current
# freebsd tarball
#
echo "Copying tarball from repository server"
rm -rf ~/freebsd-current.tar

echo "mount -t nfs ${REPOSITORY_SERVER}:${REPOSITORY_EXPORT} /mnt" 
mount -t nfs ${REPOSITORY_SERVER}:${REPOSITORY_EXPORT} /mnt
if [ ! -e /mnt/archives ]; then
    echo "Error: Repository server does not have an archives directory"
    UpdateTestState $ICA_TESTFAILED
    echo "Cloned GitHub  : Failed" >> ~/summary.log
    exit 40
fi

if [ ! -e /mnt/archives/freebsd-current.tar ]; then
    echo "Error: freebsd-current.tar file does not exist"
    UpdateTestState $ICA_TESTFAILED
    echo "Cloned GitHub  : Failed" >> ~/summary.log
    exit 50
fi

#
# cd into the nfs export so relative symlinks can be followed
#
cd /mnt/archives

echo "cp ./freebsd-current.tar /usr/"
cp ./freebsd-current.tar /usr/
if [ $? -ne 0 ]; then
    echo "Error: Unable to copy freebsd-current.tar from repository server export"
    UpdateTestState $ICA_TESTFAILED
    echo "Cloned GitHub  : Failed" >> ~/summary.log
    exit 60
fi

echo "Cloned GitHub  : Passed" >> ~/summary.log
cd /usr

echo "unmount /mnt"
umount /mnt

#
# Untar the tarball and make sure a freebsd direcgtory was created
#
echo "Info : tar -xf ./freebsd-current.tar"

if [ ! -e ./freebsd-current.tar ]; then
    echo "Error: the freebsd-current.tar file was not copied"
    UpdateTestState $ICA_TESTFAILED
    exit 65
fi

tar -xf ./freebsd-current.tar
if [ $? -ne 0 ]; then
    echo "Error: Unable to extract files from freebsd-current.tar"
    UpdateTestState $ICA_TESTFAILED
    exit 70
fi

if [ ! -e ./freebsd ]; then
    echo "Error: The git clone did not create the directory /usr/freebsd"
    echo "Clone GitHub   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 80
fi

#
# Build the kernel
#
echo "Building the FreeBSD kernel"

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

make buildkernel KERNCONF=HYPERV_VM
if [ $? != 0 ]; then
    echo "Error: The kernel build failed"
    echo "Build Kernel   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 90
fi
echo "Build Kernel   : Passed" >> ~/summary.log

#
# Install the kernel
#
echo "Installing the FreeBSD kernel"

make installkernel KERNCONF=HYPERV_VM
if [ $? != 0 ]; then
    echo "Error: The kernel install failed"
    echo "Install Kernel : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 100
fi
echo "Install Kernel : Passed" >> ~/summary.log

#
# Check that the hyper-V symbols are in the kernel
#
echo "Checking the new kernel has the Hyper-V components"

hvCount=`strings /boot/kernel/kernel | grep hv_ | wc -l`
if [ $hvCount -lt 20 ]; then
    echo "Error: The Hyper-V functions are not part of the new kernel"
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
echo "BuildKernel test completed successfully"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

