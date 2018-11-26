#!/bin/bash
#
#

REPOSITORY_DIR="/lisa"
ARCHIVES_DIR="${REPOSITORY_DIR}/public/archives"
FREEBSD_DIR="${REPOSITORY_DIR}/freebsd"
CUTOFF_DAYS=20


now=`date "+%Y%m%d-%H%M%S"`
LOG_FILE="${now}.log"
EMAIL_FILE="emailMsg.txt"
withErrors=0

#
# Functions
#

LogMsg()
{
    dateTime=`date "+%D %T"`
    echo "${dateTime} : $1" >> ${REPOSITORY_DIR}/logs/${LOG_FILE}
    echo "$2"
}

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    LogMsg "Warn : no ${CONSTANTS_FILE} found"
fi
USERNAME=$USERNAME
PASSWORD=$PASS
echo $USERNAME
#
#
#
