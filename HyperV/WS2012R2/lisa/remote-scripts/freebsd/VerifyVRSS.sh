#!/bin/bash

########################################################################
#
# VerifyVRSS.sh
# Description:
#	This script was created to automate the testing of a FreeBSD
#	Integration services. This script will verify that the vRSS is enabled.

#     
#	 To pass test parameters into test cases, the host will create
#    a file named constants.sh.  This file contains one or more
#    variable definition.
#
################################################################

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

CONSTANTS_FILE="constants.sh"

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

UpdateTestState()
{
    echo $1 > $HOME/state.txt
}

#
# Update LISA with the current status
#
cd ~
UpdateTestState $ICA_TESTRUNNING
LogMsg "Updating test case state to running"

#
# Source the constants file
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    echo "Error: no ${CONSTANTS_FILE} file" | tee >>  ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

if [ -e ~/summary.log ]; then
    LogMsg "Cleaning up previous copies of summary.log"
    rm -rf ~/summary.log
fi

#
# Identifying the test-case ID and VMBus version to match
#
if [ ! ${TC_COVERED} ]; then
	echo "The TC_COVERED variable is not defined!" | tee >>  ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

if [ ! ${NVSVERSION} ]; then
	echo "The NVSVERSION variable is not defined." | tee >>  ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

if [ ! ${LOCAL_ADDR} ]; then
	echo "The LOCAL_ADDR variable is not defined." | tee >>  ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

echo "This script covers test case: ${TC_COVERED}" | tee >>  ~/summary.log


echo "ifconfig hn1 inet ${LOCAL_ADDR}  netmask 255.255.255.0"  | tee >>  ~/summary.log
ifconfig hn1 inet ${LOCAL_ADDR} netmask 255.255.255.0
if [ $? -ne 0 ]; then
	echo "Error: unable to configure hn1" | tee >>  ~/summary.log
	UpdateTestState $ICA_TESTFAILED
	exit 70
fi

pkg info nginx
if [ $? -ne 0 ]; then
	echo "Install nginx" | tee >>  ~/summary.log
	pkg install -y nginx
	echo 'nginx_enable="YES"' >> /etc/rc.conf
    service nginx start
fi


#
# Checking the nvs version
#
nvs=`sysctl -n dev.hn.1.nvs_version`
if [ $? -ne 0 ]; then
	echo "Warning: The sysctl -n dev.hn.1.nvs_version command does not be supported now."  | tee >>  ~/summary.log
elif [ $nvs -lt $NVSVERSION ]; then
	echo "Info: Found a matching VMBus string: ${nvs}" | tee >>  ~/summary.log
	rx_ring_inuse=`sysctl -n dev.hn.1.rx_ring_inuse`
	tx_ring_inuse=`sysctl -n dev.hn.1.tx_ring_inuse`
	echo "tx_ring_inuse is $tx_ring_inuse" | tee >>  ~/summary.log
	echo "rx_ring_inuse is $rx_ring_inuse" | tee >>  ~/summary.log
	if [ $tx_ring_inuse -le 1 -a $rx_ring_inuse -le  1 ]; then 
		UpdateTestState $ICA_TESTCOMPLETED
		exit 0
	fi
fi


command="repeat 512 curl -o /dev/null  http://${LOCAL_ADDR}" 
ssh root@$TARGET_ADDR  -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no $command 
if [ $? -ne 0 ]; then
    echo "Error: Failed to execute $command" | tee >>  ~/summary.log
	UpdateTestState $ICA_TESTFAILED
	exit 1
fi

sleep 15

count=`sysctl -n dev.hn.1.rx_ring_inuse`
echo "The sysctl -n dev.hn.1.rx_ring_inuse is $count" | tee >>  ~/summary.log
for((j=0;j<$count;j++))
do
    packets=`sysctl -n dev.hn.1.rx.$j.packets`
	echo "The sysctl -n dev.hn.1.rx.$j.packets is $packets" | tee >>  ~/summary.log
	if [ $packets -eq 0 ]; then
		LogMsg "Test TestFailed"
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi
done

LogMsg "Test Passed"
UpdateTestState $ICA_TESTCOMPLETED
