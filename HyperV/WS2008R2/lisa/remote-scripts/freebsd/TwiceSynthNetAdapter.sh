#!/bin/bash
#
# Configure synthetic network adapter twice
#

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

CONSTANTS_FILE="constants.sh"


UpdateTestState()
{
    echo $1 > ~/state.txt
}

LogMsg()
{
    echo `date "+%a %b %d %T %Y"` : ${1}    # To add the timestamp to the log file
}

#
# Create the state.txt file so ICA knows we are running
#
LogMsg "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

rm -f ~/summary.log
touch ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    msg="Error: no ${CONSTANTS_FILE} file"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

#
# Make sure constants.sh contains the variables we expect
#
if [ "${NIC:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter NIC is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 20
fi

if [ "${TC_COVERED:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TC_COVERED is not defined in ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 30
fi

if [ "${TARGET_ADDR:-UNDEFINED}" = "UNDEFINED" ]; then
    msg="The test parameter TARGET_ADDR is not defined in       
 ${CONSTANTS_FILE}"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTABORTED
    exit 40
fi

#
# Echo TCs we cover
#
echo "Covers ${TC_COVERED}" > ~/summary.log

#
# Check that we have a hn device
#
numVMBusNics=`ifconfig | egrep "^hn" | wc -l`
if [ $numVMBusNics -gt 0 ]; then
    LogMsg "Number of VMBus NICs (hn) found = ${numVMBusNics}"
else
    msg="Error: No VMBus NICs found"
    LogMsg $msg
    echo $msg >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 50
fi
i=0
while [ $i -lt $numVMBusNics ]
do
	ifconfig hn${i} down
	if [ $? == 0 ];	then
		kill -9 `ps aux | grep dhclient | awk '{print $2}'`
		sleep 2
		ifconfig hn${i} up
	else
		msg="Error at ifconfig hn${i} down"
		LogMsg $msg
		echo $msg >> ~/summary.log
		exit 60
	fi
	if [ $? == 0 ]; 	then
		dhclient hn${i}
	else
		msg="Error at ifconfig hn${i} up"
		LogMsg $msg
		echo $msg >> ~/summary.log
		exit 70
	fi
	if [ $? == 0 ]; 	then
		msg="1st time Configuring network card hn${i} : Passed"
		echo $msg >> ~/summary.log
	else
		msg="Error at dhclient hn${i} "
		LogMsg $msg
		echo $msg >> ~/summary.log
		exit 80
	fi
	ip1=`ifconfig hn${i}|grep inet|cut -d " " -f 2`
	echo ${ip1}
	ifconfig hn${i} down
	if [ $? == 0 ];	then
		kill -9 `ps aux | grep dhclient | awk '{print $2}'`
		sleep 2
		ifconfig hn${i} up
	else
		msg="Error at ifconfig hn${i} down"
		LogMsg $msg
		echo $msg >> ~/summary.log
		exit 90
	fi
	if [ $? == 0 ]; 	then
		dhclient hn${i}
	else
		msg="Error at ifconfig hn${i} up"
		LogMsg $msg
		echo $msg >> ~/summary.log
		exit 100
	fi
	if [ $? == 0 ]; 	then
		msg="2nd time Configuring network card hn${i} : Passed"
		echo $msg >> ~/summary.log
	else
		msg="Error at dhclient hn${i} "
		LogMsg $msg
		echo $msg >> ~/summary.log
		exit 110
	fi
	ip2=`ifconfig hn${i}|grep inet|cut -d " " -f 2`
	echo ${ip2}
	if [ ${ip1} != ${ip2} ]; then
		LogMsg "IP address is changed"
	    echo "IP address is changed,           Test : Failed" >> ~/summary.log
		exit 120
	else
	    LogMsg "IP address is same"
		echo "IP address is same,              Test : Passed" >> ~/summary.log
	fi
	i=$[$i+1]
done
#
# Configure the NIC if it is on the internal or private network
# Warning: This function assums hn0 is the vmbus device we are working with
#
UpdateTestState $ICA_TESTCOMPLETED

exit 0


