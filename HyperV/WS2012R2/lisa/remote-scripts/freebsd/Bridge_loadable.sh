#!/bin/bash
# 
#  bridge.sh
#
#  To setup bridge on freebsd
#
#####################################

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

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    LogMsg "Warn : no ${CONSTANTS_FILE} found"
fi

#
# Put your test case code here
#

#
# Add bridge device support
#
echo "device if_bridge" >> /usr/freebsd/sys/amd64/conf/GENERIC
if [ $? -ne 0 ]; then
    msg="Bridge device support can't be added"
    LogMsg "Error: ${msg}"
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

cd /usr/freebsd

#
# Clean the kernel
#
LogMsg "Cleaning the FreeBSD kernel"
make clean
if [ $? != 0 ]; then
    LogMsg "Error: The kernel cleaning failed"
    echo "Cleaning Kernel   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 20
fi
echo "Cleaning Kernel  : Passed" >> ~/summary.log

#
# Build the kernel
#
LogMsg "Building the FreeBSD kernel"

make buildkernel KERNCONF=GENERIC
if [ $? != 0 ]; then
    LogMsg "Error: The kernel build failed"
    echo "Build Kernel     : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 30
fi
echo "Build Kernel     : Passed" >> ~/summary.log

#
# Install the kernel
#
LogMsg "Installing the FreeBSD kernel"

make installkernel KERNCONF=GENERIC
if [ $? != 0 ]; then
    LogMsg "Error: The kernel install failed"
    echo "Install Kernel   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 40
fi
echo "Install Kernel   : Passed" >> ~/summary.log

#
# Load bridge drivers
#
echo "if_bridge_load=\"yes\"
bridgestp_load=\"yes\"">>/boot/loader.conf
if [ $? != 0 ]; then
    echo "Edit loader.conf : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 50
fi
echo "Edit loader.conf : Passed" >> ~/summary.log

#
# Edit rc.conf to have bridge setup automatically
#
echo "cloned_interfaces=\"bridge0\"
ifconfig_bridge0=\"addm hn0 addm hn1 up\"
ifconfig_hn0=\"up\"
ifconfig_hn1=\"up\"" >> /etc/rc.conf
if [ $? != 0 ]; then
    echo "Edit rc.conf     : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 60
fi
echo "Edit rc.conf     : Passed" >> ~/summary.log

#
# Let ICA know we completed successfully
#
LogMsg "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

