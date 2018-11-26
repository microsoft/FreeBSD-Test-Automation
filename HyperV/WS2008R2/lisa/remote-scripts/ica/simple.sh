#!/bin/bash
#

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"

DBGLEVEL=3

dbgprint()
{
    if [ $1 -le $DBGLEVEL ]; then
        echo "$2"
    fi
}

UpdateTestState()
{
    echo $1 > ~/state.txt
}

#
# Create the state.txt file so ICA knows we are running
#
UpdateTestState $ICA_TESTRUNNING

#
# Source the ICA config file
#
if [ -e ./constants.sh ]; then
    . ./constants.sh
else
    echo "Error: Unable to source constants.sh"
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

timeout=2
if [ $SLEEP_TIMEOUT ]; then
    timeout=$SLEEP_TIMEOUT
fi

echo "Sleeping for $timeout seconds"
sleep $timeout
echo "Sleep completed"

echo "Simple test" > summary.log
echo "sleep for $timeout seconds" >> summary.log

#
# Let the callknow everything worked
#
UpdateTestState $ICA_TESTCOMPLETED

exit 0

