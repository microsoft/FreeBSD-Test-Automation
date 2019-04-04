#!/bin/bash

ICA_TESTRUNNING="TestRunning"
ICA_TESTCOMPLETED="TestCompleted"
ICA_TESTABORTED="TestAborted"
ICA_TESTFAILED="TestFailed"

LogMsg()
{
    # To add the timestamp to the log file
    echo `date "+%a %b %d %T %Y"` : ${1} 
}

UpdateTestState()
{
    echo $1 > $HOME/state.txt
}

UpdateTestState $ICA_TESTRUNNING

ifconfig -a | grep -i mlxen | grep -v grep
if [ $? -ne 0 ]; then
    LogMsg "Not found mlxenX interface via ifconfig -a"
    UpdateTestState $ICA_TESTFAILED
    exit 0
fi

vf_pci_device=$(pciconf -lbv | grep -i mlx | grep -v grep | awk  -F "@" '{print $1}')
if [ -z $vf_pci_device ]; then
    LogMsg "Not found mlx driver via pciconf -lbv"
    UpdateTestState $ICA_TESTFAILED
    exit 0
fi

for ((counter=1; counter<10; ++counter))
do
    LogMsg "The $counter iterations to disable and enable the VF device"
    # Disable the VF
    devctl disable $vf_pci_device
    if [ 0 -ne $? ]; then
        LogMsg "Disable the $vf_pci_device failed"
        UpdateTestState $ICA_TESTFAILED
        exit 0
    fi
    
    sleep 5
    ifconfig -a | grep -i mlxen | grep -v grep
    if [ $? -eq 0 ]; then
        LogMsg "Disable the VF device failed at $counter iterations"
        UpdateTestState $ICA_TESTFAILED
        exit 0
    fi

    # Enable the VF
    devctl enable $vf_pci_device
    if [ 0 -ne $? ]; then
        LogMsg "Enable the $vf_pci_device failed"
        UpdateTestState $ICA_TESTFAILED
        exit 0
    fi

    sleep 5
    ifconfig -a | grep -i mlxen | grep -v grep
    if [ $? -ne 0 ]; then
        LogMsg "Enable the VF device failed at $counter iterations"
        UpdateTestState $ICA_TESTFAILED
        exit 0
    fi
done

#If we are here test executed successfully
UpdateTestState $ICA_TESTCOMPLETED

exit 0
