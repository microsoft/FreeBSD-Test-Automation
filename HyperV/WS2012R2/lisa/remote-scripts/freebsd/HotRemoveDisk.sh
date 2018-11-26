#!/bin/bash
#
# HotRemoveDisk.sh
#
# Description:
#    This script is to verify the hard disk really removed from VM.

#
#     Test parameters used by this scripts are:
#         NO             : Number of disks
#         
#####################################################################

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"
ICA_TESTFAILED="TestFailed"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamps to the log file
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
# Clean-up from any previous test run
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
    LogMsg "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 15
fi

if [ ${TC_COVERED:-UNDEFINED} = "UNDEFINED" ]; then
    LogMsg "Error: constants.sh did not define the variable TC_COVERED"
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

echo "Covers ${TC_COVERED}" >> ~/summary.log
echo "Number of disk removed : $NO" >> ~/summary.log

i=1
while [ $i -le $NO ]
do
	ls /dev/da* | grep "/dev/da$i"
	if [ $? -eq 0 ]; then
		LogMsg "Error: /dev/da$i still exists"
		echo "Error: /dev/da$i still exists"   >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi
	LogMsg "Info: /dev/da$i is removed "
	i=$[$i+1]
done

#
#If we are here test executed successfully
#
UpdateTestState $ICA_TESTCOMPLETED

exit 0

