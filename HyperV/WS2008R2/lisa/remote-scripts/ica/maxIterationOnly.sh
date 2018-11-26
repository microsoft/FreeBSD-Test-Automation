##########################################################################
#!/bin/bash
#maxIterationOnly.sh
#Description:
#    This script was created to verify the only the maxiteration
#    property parameters in configuration file

#History : 
#Created By : xiliang@microsoft.com
##########################################################################

echo "####################################################################"
echo "This is test case to verify the iteration parameters in
constants.sh"

DEBUG_LEVEL=3

function dbgprint()
{
    if [ $1 -le $DEBUG_LEVEL ]; then
        echo "$2"
    fi
}

function UpdateTestState()
{
    echo $1 > $HOME/state.txt
}

if [ -e ~/summary.log ]; then
    dbgprint 1 "Cleaning up previous copies of summary.log"
    rm -rf ~/summary.log
fi

cd ~

#
# Convert any .sh files to Unix format
#
dos2unix -f ica/* > /dev/null 2>&1

# Source the constants file

#
# Create the state.txt file so the ICA script knows I am running
#

UpdateTestState "TestRunning"

echo "execute maxIterationOnly.sh" > summary.log

dbgprint 1 "Updating test case state to completed"
UpdateTestState "TestCompleted"
