#!/bin/bash

################################################################
# VerifyVMBusProto.sh
#
# Description :
#    This script will verify if all the CPUs are 
#    processing VMBUS interrupts.  It also checks
#    that the negotiated VMBus protocol is correct.
#
################################################################

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

LogMsg "VerifyVMBusProto.sh"


UpdateTestState()
{
    echo "$1" > $HOME/state.txt
}

#
# Let ICA know we are running
#
UpdateTestState "TestRunning"

#
# Source constants.sh
#
if [ -e $HOME/constants.sh ]; then
    . $HOME/constants.sh
else
    LogMsg "ERROR: Unable to source the constants file."
    UpdateTestState "TestFailed"
    exit 1
fi

rm -f ~/summary.log
touch ~/summary.log
echo "Covers: VMBus_2.3.2,2.3.3" >> ~/summary.log

#Since it require to compare VCPU variable it must be defined
if [ ! ${VMBusVer} ]; then
    LogMsg "The VMBusVer variable is not defined."
	echo "The VMBusVer variable is not defined." >> ~/summary.log
    LogMsg "Terminating the test."
    UpdateTestState "TestFailed"
    exit 1
fi

#
# Getting the VCPUs Count
#
cpu=$(grep CPU -o /proc/interrupts | wc -l)
LogMsg "${cpu} CPUs found"

#
# Verifying if VMBUS interrupts are processed by the CPUs by checking /proc/interrupts file 
#
while read line
do
    if [[ $line = *hyperv* ]]; then
        for ((  i=0 ;  i<=$cpu-1;  i++ ))
        do
            intrCount=`echo $line | cut -f $(( $i+2 )) -d ' '` 
            LogMsg "CPU ${i} interrupt count = ${intrCount}"
            if [ $intrCount -ne 0 ]; then
                LogMsg "CPU ${i} is processing VMBUS interrupts"
            else
                LogMsg "Error: CPU {$i} is not processing VMBUS Interrupts."
				echo "Error: CPU {$i} is not processing VMBUS Interrupts." >> ~/summary.log
                UpdateTestState "TestFailed"
                exit 10
            fi
        done
    fi
done < "/proc/interrupts"

#
# Now check for the VMBus protocol number
# First, find the message we are interested in, and echo it so
# it is recorded in the log.
#
msg=`dmesg | grep "Vmbus version:"`
LogMsg "$msg"

#
# Extract the version number and verify it
#
vmbusVersion=`echo $msg | cut -f 4 -d :`
if [ -z "$vmbusVersion" ]; then
    LogMsg "Error: Unable to find VMBus protocol version in dmesg log"
	echo "Error: Unable to find VMBus protocol version in dmesg log" >> ~/summary.log
    UpdateTestState "TestFailed"
    exit 20
fi

LogMsg "Info: Vmbus version = ${vmbusVersion}"
echo "Info: Vmbus version = ${vmbusVersion}" >> ~/summary.log

if [ $vmbusVersion != "${VMBusVer}" ]; then
    LogMsg "Error: Incorrect VMBus protocol level was negotiated: ${vmbusVersion}"
	echo "Error: Incorrect VMBus protocol level was negotiated: ${vmbusVersion}" >> ~/summary.log
    UpdateTestState "TestFailed"
    exit 30
fi

LogMsg "Test Passed"
UpdateTestState "TestCompleted"

