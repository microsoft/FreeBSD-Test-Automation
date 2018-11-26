#!/bin/bash
#
# ICA-NETWORK-BASIC-SRIOV-BSD-TEST.sh
#
#####################################################################

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"
ICA_TESTFAILED="TestFailed"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}  >>  /root/summary.log  # To add the timestamp to the log file
}


UpdateTestState()
{
    echo $1 > /root/state.txt
}

rm -f /root/summary.log

UpdateTestState $ICA_TESTRUNNING

ifconfig -a | grep -i mlxen0 | grep -v grep
if [ $? -ne 0 ]; then
    LogMsg "Not found mlxen0 via ifconfig -a"
    pciconf -lbv | grep -i mlx | grep -v grep
    if [ $? -ne 0 ]; then
        LogMsg "Found mlx driver via pciconf -lbv"
    else
        LogMsg "Not found mlx driver via pciconf -lbv"
    fi
    UpdateTestState ICA_TESTFAILED
    exit 0
else
    LogMsg "Found mlxen0 via ifconfig -a"
fi

#If we are here test executed successfully
UpdateTestState $ICA_TESTCOMPLETED

exit 0

