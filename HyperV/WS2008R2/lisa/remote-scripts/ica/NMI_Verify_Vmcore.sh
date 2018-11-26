#!/bin/bash

################################################################
# NMI_Verify_Vmcore.sh
#
#Description : This script will verify if the generated vmcore 
# is in appropriate format and can be readble using crash utility
# 
################################################################

cd /var/crash/
echo "Crash folder found, Processing..."
cd "` ls -ltc | awk '/^d/{print $NF; exit}' `"
if [ $? -ne 0 ]; then
	echo "Error: Crash folder not found"
	exit 1
fi
crash vmlinux-$(uname -r).gz vmcore -i /root/crashcommand > crash.log
if [ $? -ne 0 ]; then
	echo "Error: vmcore file not generated or failed to read. Please also check if the appropriate kernel-debug packages are installed"
else
	cat crash.log
	echo "vmcore file generated and read successfully"
fi
