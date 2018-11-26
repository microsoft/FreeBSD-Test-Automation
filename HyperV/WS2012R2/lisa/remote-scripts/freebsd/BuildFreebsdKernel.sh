#!/bin/bash
#
# Build FreeBSD kernel
#

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

CONSTANTS_FILE="constants.sh"

SRCPATH="/usr/devsrc/"
LOGFILE="/root/KernelFreebsdBuild.log"

UpdateTestState()
{
    echo $1 > ~/state.txt
}

# Create the state.txt file so ICA knows we are running
echo "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

rm -f ~/summary.log
touch ~/summary.log

date > $LOGFILE

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
echo "Loading constants.sh"

if [ -e ~/${CONSTANTS_FILE} ]; then
    source ~/${CONSTANTS_FILE}
else
    echo "Error: no ~/${CONSTANTS_FILE} found"
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi


# Make sure all required variables are defined in constants.sh
if [ ${GIT_URL:-UNDEFINED} = "UNDEFINED" ]; then
    echo "Error: constants.sh did not define the variable GIT_URL"
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

if [ ${GIT_BRANCH}:-UNDEFINED} = "UNDEFINED" ]; then
    echo "Error: constants did not define the variable GIT_BRANCH"
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

if [ ${GIT_BRANCH} == "None" ]; then
    echo "Error: GIT_BRANCH is None!"
    UpdateTestState $ICA_TESTABORTED
    exit 1
fi

if [ ${GIT_COMMITID} != "None" ]; then
    echo "GIT_COMMITID = ${GIT_COMMITID}" >> ~/summary.log
fi

echo "GIT_URL = ${GIT_URL}"  >> ~/summary.log
echo "GIT_BRANCH = ${GIT_BRANCH}"  >> ~/summary.log


# Get source code
echo "Getting the FreeBSD kernel code" >> $LOGFILE
if [ ! -e ${SRCPATH} ]; then
    mkdir ${SRCPATH}
fi

if [ ! -e ${SRCPATH}freebsd ]; then
    git clone ${GIT_URL}
else
    cd ${SRCPATH}freebsd  && git checkout -f ${GIT_BRANCH}  &&  git pull origin ${GIT_BRANCH}
fi

if [ $? != 0 ]; then
    echo "Git clone or checkout ${GIT_BRANCH} Failed, but try again." >> $LOGFILE
	cd /root
	rm  -rf ${SRCPATH}freebsd
	cd ${SRCPATH} && git clone ${GIT_URL}   && cd ${SRCPATH}freebsd  && git checkout -f ${GIT_BRANCH}  &&  git pull origin ${GIT_BRANCH}
	if [ $? != 0 ]; then
		echo "Git clone or checkout ${GIT_BRANCH} : Failed" >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi
fi

if [ ${GIT_COMMITID} != "None" ]; then
    git checkout -f  ${GIT_COMMITID}
	if [ $? != 0 ]; then
		echo "Git checkout ${GIT_COMMITID} : Failed" >> ~/summary.log
		UpdateTestState $ICA_TESTFAILED
		exit 1
	fi
fi


# Build the tool chain firstly, but the process continue even it's failed
echo "Begin to build tool chain and it will take a very long time."  >> $LOGFILE
make -j `sysctl -n hw.ncpu` kernel-toolchain  >> $LOGFILE
if [ $? != 0 ]; then
	echo "Warning: Build tool chain failed." >> $LOGFILE
fi


# Build the kernel
echo "Building the FreeBSD kernel" >> $LOGFILE
make  -j `sysctl -n hw.ncpu` buildkernel  >> $LOGFILE
if [ $? != 0 ]; then
    echo "Build Kernel   : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 1
fi
echo "Build Kernel: Passed" >> ~/summary.log

# Install the kernel
echo "Installing the FreeBSD kernel" >> $LOGFILE
make installkernel  >> $LOGFILE
if [ $? != 0 ]; then
    echo "Install Kernel : Failed" >> ~/summary.log
    UpdateTestState $ICA_TESTFAILED
    exit 1
fi
echo "Install Kernel : Passed" >> ~/summary.log

#
# If we made it here, everything worked.  Let ICA know
# the test completed successfully
#
echo "BuildKernel test completed successfully"
UpdateTestState $ICA_TESTCOMPLETED

sync
sync

exit 0

