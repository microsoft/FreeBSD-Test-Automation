#!/bin/bash
########################################################################
#
# Synopsis
#     This tests Network Time Protocol sync.
#
# Description
#     This script was created to automate the testing of a FreeBSD
#     Integration services. It enables Network Time Protocol and 
#     checks if the time is in sync.
#    
#     
#     A typical xml entry looks like this:
# 
#         <test>
#             <testName>TimeSyncNTP</testName>
#             <testScript>CORE_TimeSync_NTP.sh</testScript>
#             <files>remote-scripts/freebsd/CORE_TimeSync_NTP.sh</files>
#             <timeout>300</timeout>
#             <onError>Continue</onError>
#         </test>
#
########################################################################


ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test
maxdelay=5.0                        # max offset in seconds.
zerodelay=0.0                       # zero

CONSTANTS_FILE="constants.sh"


UpdateTestState()
{
    echo $1 > ~/state.txt
}

#######################################################################
# Adds a timestamp to the log file
#######################################################################
function LogMsg() {
    echo $(date "+%a %b %d %T %Y") : ${1}
}

####################################################################### 
# 
# Main script body 
# 
#######################################################################

cd ~

# Create the state.txt file so LISA knows we are running
UpdateTestState $ICA_TESTRUNNING

# Cleanup any old summary.log files
if [ -e ~/summary.log ]; then
    rm -rf ~/summary.log
fi

LogMsg "This script tests NTP time syncronization"
#
# Create the state.txt file so ICA knows we are running
#
echo "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING


echo "Covers CORE-04" > ~/summary.log

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    echo "Info: no ${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 5
fi

# Turn off timesync
sysctl hw.hvtimesync.ignore_sync=1
sysctl hw.hvtimesync.sample_thresh=-1

grep "^[ ]*ntpd_enable"  /etc/rc.conf
if [ $? -ne 0 ]; then
    cat <<EOF>> /etc/rc.conf 
ntpd_enable="YES"
EOF
sh /etc/rc
fi

sleep 2

# Try to restart NTP. If it fails we try to install it.
service ntpd restart
if [ $? -ne 0 ]; then
	service ntpd onerestart
	if [ $? -ne 0 ]; then
		echo "NTPD not installed. Trying to install ..."
		echo "y" | pkg install ntp
		if [[ $? -ne 0 ]] ; then
				LogMsg "ERROR: Unable to install ntpd. Aborting"
				UpdateTestState $ICA_TESTABORTED
				exit 10
		fi
		rehash
		ntpdate pool.ntp.org
		if [[ $? -ne 0 ]] ; then
			LogMsg "ERROR: Unable to set ntpdate. Aborting"
			UpdateTestState $ICA_TESTABORTED
			exit 10
		fi
		service ntpd start
		if [[ $? -ne 0 ]] ; then
			LogMsg "ERROR: Unable to start ntpd. Aborting"
			UpdateTestState $ICA_TESTABORTED
			exit 10
		fi
		echo "NTPD installed succesfully!"
	fi
fi

service ntpd stop
ntpdate pool.ntp.org
service ntpd start

# We wait 120 seconds for the ntp server to sync
sleep 120

# Variables for while loop. stopTest is the time until the test will run
isOver=false
secondsToRun=1800
stopTest=$(( $(date +%s) + secondsToRun )) 

while [ $isOver == false ]; do
    # 'ntpq -c rl' returns the offset between the ntp server and internal clock
    delay=$(ntpq -c rl | grep offset= | awk -F "=" '{print $3}' | awk '{print $1}' | tr -d '-')
    delay=$(echo $delay | sed s'/.$//')

    # Transform from milliseconds to seconds
    delay=$(echo $delay 1000 | awk '{ print $1/$2 }')

    # Using awk for float comparison
    check=$(echo "$delay $maxdelay" | awk '{if ($1 < $2) print 0; else print 1}')

    # Also check if delay is 0.0
    checkzero=$(echo "$delay $zerodelay" | awk '{if ($1 == $2) print 0; else print 1}')

    # Check delay for changes; if it matches the requirements, the loop will end
    if [[ $checkzero -ne 0 ]] && \
       [[ $check -eq 0 ]]; then
        isOver=true
    fi

    # The loop will run for 30 mins if delay doesn't match the requirements
    if  [[ $(date +%s) -gt $stopTest ]]; then
        isOver=true
        if [[ $checkzero -eq 0 ]]; then
            # If delay is 0, something is wrong, so we abort.
            LogMsg "ERROR: Delay cannot be 0.000; Please check NTP sync manually."
            UpdateTestState $ICA_TESTABORTED
            exit 10
        elif [[ 0 -ne $check ]] ; then    
            LogMsg "ERROR: NTP Time out of sync. Test Failed"
            LogMsg "NTP offset is $delay seconds."
            UpdateTestState $ICA_TESTFAILED
            exit 10
        fi
    fi
    
    sleep 30
done

# If we reached this point, time is synced.
LogMsg "NTP offset is $delay seconds."
LogMsg "SUCCESS: NTP time synced!"

UpdateTestState $ICA_TESTCOMPLETED
exit 0


