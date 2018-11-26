#!/bin/bash
#
# bsd_stripe.sh
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

touch summary.log

date >  summary.log;
uname -a >>  summary.log
echo Guest Distro: `uname -r` >> summary.log

sum=`ls /dev/da* | wc -l`
if [$sum -gt 10 ]; then
    kldload geom_stripe
    gstripe label -v st0 /dev/da2 /dev/da3 /dev/da4 /dev/da5 /dev/da6 /dev/da7 /dev/da8 /dev/da9 /dev/da10 /dev/da11 /dev/da12 /dev/da13
	device="/dev/stripe/st0"
else
    device="/dev/da2"
fi

#If we are here test executed successfully
UpdateTestState $ICA_TESTCOMPLETED

exit 0

