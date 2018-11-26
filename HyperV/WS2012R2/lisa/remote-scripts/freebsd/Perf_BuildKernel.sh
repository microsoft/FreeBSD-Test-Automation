#!/bin/bash

########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0  
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################

#######################################################################
#
# Description:
#     This script was created to automate the testing of a Linux
#     kernel source tree.  It does this by performing the following
#     steps:
#	1. Make sure we were given a kernel source tarball
#	2. Configure and build the new kernel
#
# The outputs are directed into files named:
# Perf_BuildKernel_make.log, 
# Perf_BuildKernel_makemodulesinstall.log, 
# Perf_BuildKernel_makeinstall.log
#
# This test script requires the below test parameters:
#   TARBALL=linux-3.14.tar.xz
#   KERNELVERSION=linux-3.14
#
# A typical XML test definition for this test case would look
# similar to the following:
#          <test>
#             <testName>TimeBuildKernel</testName>     
#             <testScript>Perf_BuildKernel.sh</testScript>
#             <files>remote-scripts/ica/Perf_BuildKernel.sh</files>
#             <files>Tools/linux-3.14.tar.xz</files>
#             <testParams>
#                 <param>TARBALL=linux-3.14.tar.xz</param>
#                 <param>KERNELVERSION=linux-3.14</param>
#             </testParams>
#             <uploadFiles>
#                 <file>Perf_BuildKernel_make.log</file>
#                 <file>Perf_BuildKernel_makemodulesinstall.log</file> 
#                 <file>Perf_BuildKernel_makeinstall.log</file>
#             </uploadFiles>
#             <timeout>10800</timeout>
#             <OnError>Abort</OnError>
#          </test>
#
#######################################################################



DEBUG_LEVEL=3
CONFIG_FILE=GENERIC

START_DIR=$(pwd)
cd ~

#
# Source the constants.sh file so we know what files to operate on.
#

source ./constants.sh

dbgprint()
{
    if [ $1 -le $DEBUG_LEVEL ]; then
        echo "$2"
    fi
}

UpdateTestState()
{
    echo $1 > ~/state.txt
}

UpdateSummary()
{
    echo $1 >> ~/summary.log
}

#
# Create the state.txt file so the ICA script knows
# we are running
#
UpdateTestState "TestRunning"
if [ -e ~/state.txt ]; then
    dbgprint 0 "State.txt file is created "
    dbgprint 0 "Content of state is : " ; echo `cat state.txt`
fi

#
# Write some useful info to the log file
#
dbgprint 1 "buildKernel.sh - Script to automate building of the kernel"
dbgprint 3 ""
dbgprint 3 "Global values"
dbgprint 3 "  DEBUG_LEVEL = ${DEBUG_LEVEL}"
dbgprint 3 "  KERNELVERSION = ${KERNELVERSION}"
dbgprint 3 "  CONFIG_FILE = ${CONFIG_FILE}"
dbgprint 3 ""

#
# Delete old kernel source tree if it exists.
# This should not be needed, but check to make sure
# 
# adding check for summary.log
if [ -e ~/summary.log ]; then
    dbgprint 1 "Cleaning up previous copies of summary.log"
    rm -rf ~/summary.log
fi

#
# By default FreeBSD kernel source is located at /usr/src
#
system_arch=$(sysctl -a hw.machine_arch | cut -d ':' -f 2 | tr -d ' ')
if [ ! -e /usr/src/sys/$system_arch/conf/GENERIC ]; then
		dbgprint 0 "Error: /usr/src/sys/$system_arch/conf/GENERIC not found."
		dbgprint 0 "Do you have FreeBSD source code installed?"
		exit 100
fi

cd /usr/src

#
# Start the testing
#
proc_count=$(sysctl -a kern.smp.cpus | cut -d ':' -f 2 | tr -d ' ')
dbgprint 1 "Build kernel with $proc_count CPU(s)"

UpdateSummary "KernelRelease=$(uname -r)"
UpdateSummary "ProcessorCount=$proc_count"

UpdateSummary "$(uname -a)"

#
# Build the kernel
#
dbgprint 1 "Building the kernel."
    
if [ $proc_count -eq 1 ]; then
    (time make buildkernel KERNCONF=${CONFIG_FILE}) >/root/Perf_BuildKernel_make.log 2>&1
else
    (time make -j $proc_count buildkernel KERNCONF=${CONFIG_FILE}) >/root/Perf_BuildKernel_make.log 2>&1
fi

sts=$?
if [ 0 -ne ${sts} ]; then
    dbgprint 1 "Kernel make failed: ${sts}"
    dbgprint 1 "Aborting test."
    UpdateTestState "TestAborted"
    UpdateSummary "make: Failed"
    exit 110
else
    UpdateSummary "make: Success"
fi

#
# Install the kernel
#
dbgprint 1 "Installing the kernel."
if [ $proc_count -eq 1 ]; then
    (time make installkernel KERNCONFIG=${CONFIG_FILE}) >/root/Perf_BuildKernel_makeinstall.log 2>&1
else
    (time make -j $proc_count installkernel KERNCONFIG=${CONFIG_FILE}) >/root/Perf_BuildKernel_makeinstall.log 2>&1
fi

sts=$?
if [ 0 -ne ${sts} ]; then
    echo "kernel build failed: ${sts}"
    UpdateTestState "TestAborted"
    UpdateSummary "make installkernel: Failed"
    exit 130
else
    UpdateSummary "make installkernel: Success"
fi

#
# Save the current Kernel version for comparision with the version
# of the new kernel after the reboot.
#
cd ~
dbgprint 3 "Saving version number of current kernel in oldKernelVersion.txt"
uname -r > ~/oldKernelVersion.txt

#
# Let the caller know everything worked
#
dbgprint 1 "Exiting with state: TestCompleted."
UpdateTestState "TestCompleted"

exit 0
