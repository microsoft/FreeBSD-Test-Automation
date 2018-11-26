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
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    echo "Warn : no ${CONSTANTS_FILE} found"
fi

#
# Cloning Tree
#
cd /usr
echo "Cloning tree : "
git clone https://github.com/FreeBSDonHyper-V/freebsd.git
if [ $? != 0 ]; then
    echo "Error: Cloning tree failed"
    echo "Cloning tree  : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 10
fi
echo "Cloning tree : Passed" >> ~/summary.log

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

make buildkernel KERNCONF=GENERIC
if [ $? != 0 ]; then
    echo "Error: The kernel build failed"
    echo "Build Kernel   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 20
fi
echo "Build Kernel   : Passed" >> ~/summary.log

#
# Install the kernel
#
echo "Installing the FreeBSD kernel"

make installkernel KERNCONF=GENERIC
if [ $? != 0 ]; then
    echo "Error: The kernel install failed"
    echo "Install Kernel : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 30
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

    exit 40
fi
echo "Verify Kernel  : Passed" >> ~/summary.log

#
#Edit /boot/loader.conf
#
echo "hv_vmbus_load=\"yes\"
hv_utils_load=\"yes\"
hv_netvsc_load=\"yes\"
hv_storvsc_load=\"yes\"">>/boot/loader.conf
	if [ "$?" = "0" ]; then
 echo "Error Editing!" >> ~/summary.log
UpdateTestState $ICA_TESTFAILED
exit 40
fi
echo "Done Editing!" >> ~/summary.log

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
