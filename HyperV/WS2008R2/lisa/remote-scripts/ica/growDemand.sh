#!/bin/bash
#
# Grow memory demand (stress) by consuming memory in 256MB
# allocations.
#
# Syntax
#    ./growDemand.sh sizeInGB timeout
#
#    sizeInGB = The amount of memory to allocate in GB.
#
#    timeout  = How long each instance of stress should run
#               in seconds.
#
#####################################################################

#
# The interval, in seconds, between each invocation of stress
#
INTERVAL=2

#
# Default to 2GB if no size is not specified
# 
if [ $1 ]; then
    sizeGB=$1
else
    sizeGB=2
fi

#
# Default to 120 seconds if timeout is not specified
#
if [ $2 ]; then
    timeout=$2
else
    timeout=120
fi

#
# Compute the number of 256MB allocations required
#
count=$((sizeGB * 4))

echo "sizeMB  = ${sizeGB}"
echo "count   = ${count}"
echo "timeout = ${timeout}"

while [ $count -gt 0 ]
do
    #stress --vm 1 --vm-bytes 256M -t $timeout &
    stressapptest -M 256 -s $timeout &
    echo "Created instance of stressapptest (${count})"
    sleep $INTERVAL
    count=$(( count - 1 ))
done

#
# Sleep so the script does not exist which could result in the
# ssh session being closed.  This would result in all the
# instances of stressapptest being terminated.
#
sleep $timeout

exit 0

