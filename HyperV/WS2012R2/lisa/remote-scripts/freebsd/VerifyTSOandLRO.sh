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


# Create a test file named 24K.bin if it doesn't exist
if [ ! -e "/usr/local/www/nginx/24K.bin" ]; then
	echo "Create /usr/local/www/nginx/24K.bin "  | tee >>  ~/summary.log
	dd if=/dev/zero of=/usr/local/www/nginx/24K.bin bs=1024 count=24
fi

echo "Run tcpdump -c 8 -eni hn1 tcp port 80 in background."  | tee >>  ~/summary.log
tcpdump -c 8 -eni hn1 tcp port 80 > /root/TSO.log  &

command="curl -o /dev/null  http://${LOCAL_ADDR}/24K.bin" 
ssh root@$TARGET_ADDR  -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no $command 
if [ $? -ne 0 ]; then
    echo "Error: Failed to execute $command" | tee >>  ~/summary.log
	UpdateTestState $ICA_TESTFAILED
	exit 1
fi

sleep 5

#Check TSO
tso_flag=0
lengths=`cat /root/TSO.log | grep length | sed 's/^.* IPv4//g' | sed 's/:.*$//g' | sed 's/.*length//g' | tr -d " "`
for tmp in $lengths
do
	if [ $tmp -gt 1514 ]; then
		echo "The length: $tmp is greator than 1514" | tee >>  ~/summary.log
		tso_flag=1
		break
	fi
done


#Check LRO
lro_queued=`ssh  root@$TARGET_ADDR  -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  "sysctl -n  dev.hn.1.lro_queued"`
lro_flushed=`ssh root@$TARGET_ADDR  -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  "sysctl -n  dev.hn.1.lro_flushed"`

echo "sysctl -n  dev.hn.1.lro_queued is $lro_queued"    | tee >>  ~/summary.log 
echo "sysctl -n  dev.hn.1.lro_flushed is $lro_flushed"  | tee >>  ~/summary.log 

lro_flag=0
if [ $lro_queued -gt 0 -a $lro_flushed -gt 0 ]; then
	lro_flag=1
fi

if [ $tso_flag -eq 1 -a $lro_flag -eq 1 ]; then
	echo "Both TSO and LRO are enabled successfully."  | tee >>  ~/summary.log 
	LogMsg "Test Passed"
	UpdateTestState $ICA_TESTCOMPLETED
	exit 0
fi

if [ $tso_flag -eq 0 -a $lro_flag -eq 1 ]; then
	echo "TSO is enabled failed, but LRO are enabled successfully."   | tee >>  ~/summary.log 
fi

if [ $tso_flag -eq 1 -a $lro_flag -eq 0 ]; then
	echo "LRO is enabled failed, but TSO are enabled successfully."  | tee >>  ~/summary.log 
fi

if [ $tso_flag -eq 0 -a $lro_flag -eq 0 ]; then
	echo "Both TSO and LRO are enabled failed."   | tee >>  ~/summary.log 
fi

LogMsg "Test Failed"
UpdateTestState $ICA_TESTFAILED
exit 1

