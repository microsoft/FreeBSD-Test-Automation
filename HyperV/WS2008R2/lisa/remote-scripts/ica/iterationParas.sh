##########################################################################
#!/bin/bash
#iterationParas.sh
#Description:
#    This script was created to verify the iteration parameters in
#    constants.sh
#         iteration=n
#         iterationParam=xyz
#         iterationParam=<iterationParams[i]>
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

if [ -e $HOME/constants.sh ]; then
    . $HOME/constants.sh
else
    echo "ERROR: Unable to source the constants file."
    UpdateTestState "TestAborted"
    exit 1
fi

#
# Create the state.txt file so the ICA script knows I am running
#

UpdateTestState "TestRunning"

cat $HOME/constants.sh 
echo "execute iterationParas.sh" > summary.log

dbgprint 1 "Updating test case state to completed"

echo "Remove constants.sh file"
rm -rf $HOME/constants.sh

UpdateTestState "TestCompleted"


