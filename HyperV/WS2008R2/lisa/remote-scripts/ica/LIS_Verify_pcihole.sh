#!/bin/bash

################################################################
# Verify_pcihole.sh
#
#Description : This script will verify the PCI_hole (mmio gap) is correctly
# set on the Linux VM. It will compare the set value with the 
# user provided gap size.
################################################################



LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

# Source the constants file
UpdateTestState()
{
	echo "$1" > $HOME/state.txt
}

UpdateTestState "TestRunning"

if [ -e $HOME/constants.sh ]; then
	. $HOME/constants.sh
else
	LogMsg "ERROR: Unable to source the constants file."
	UpdateTestState "TestAborted"
	exit 1
fi

rm -f ~/summary.log
touch ~/summary.log
echo "Covers: MMIO 2.3.1, 2.3.3" >> ~/summary.log

# Getting the starting memory address from dmesg Log

addr=$(dmesg | grep -i "pci_bus" | grep "resource 8" | cut -f 11 -d ' ')
startaddr=$(echo $addr |cut -f 1 -d '-')

# Subtracting the start memory address from 4GB (0x100000000)
fourGB=0x100000000
bytes=$(echo $((($fourGB) - ($startaddr))))

#Converting the PCI_hole size in MB (megabytes)
oneMB=$((1024*1024))
mb=$(echo "$bytes/$oneMB" | bc)
LogMsg "PCI_hole size is: $mb MB"
echo "PCI_hole size is: $mb MB" >> ~/summary.log

# Comparing the PCI_hole size value with the one provided by the user
gap=$(printf "%1.f\n" ${gap})

# Checking if the gap parameter is within valid range
if [[ ($gap -ge 128) && ($gap -le 3584) ]]; then
	if [[ ($mb -eq ${gap}) || ($mb -eq ${gap}+1) ]]; then
		LogMsg "PCI_Hole size matched"
		echo "PCI_Hole size matched" >> ~/summary.log
		UpdateTestState "TestCompleted"
	else
		LogMsg "Error: PCI_Hole size does not match"
		echo "Error: PCI_Hole size does not match" >> ~/summary.log
		UpdateTestState "TestFailed"
		exit 20
	fi
else
	LogMsg "Gap Size is out of range."
	echo "Gap Size is out of range" >> ~/summary.log
	UpdateTestState "TestCompleted"
fi

LogMsg  "Exiting with state: TestCompleted."
UpdateTestState "TestCompleted"

