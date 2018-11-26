#!/bin/bash
#
# bsd_kq.sh
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

UpdateTestState $ICA_TESTRUNNING

touch  summary.log
date >>  summary.log
uname -a >>  summary.log
echo Guest Distro: `uname -r` >>  summary.log

#If we are here test executed successfully
UpdateTestState $ICA_TESTCOMPLETED

exit 0

