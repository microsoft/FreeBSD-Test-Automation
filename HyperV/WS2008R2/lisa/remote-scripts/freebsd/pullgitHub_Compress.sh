#!/bin/bash
#
#
#   Creates freebsd-current.tar.bz2 file
#
#

REPOSITORY_DIR="/lisa"
ARCHIVES_DIR="${REPOSITORY_DIR}/public/archives"
FREEBSD_DIR="${REPOSITORY_DIR}/freebsd"

now=`date "+%Y%m%d-%H%M%S"`
LOG_FILE="${now}.log"
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
#
#
echo "Updating the FreeBSDonHyper-V project"

#
# Make sure the working directory exists
#
if [ ! -e ${FREEBSD_DIR} ]; then
    echo "Error: The freebsd directory does not exist."
    echo "        Cannot perform a git pull"
fi

echo "cd ${FREEBSD_DIR}"
cd ${FREEBSD_DIR}

#
# Update the github project via a pull
#

echo "git pull"
git pull

if [ $? -ne 0 ]; then
    echo "Error: git pull command failed"
    exit 10
fi

#
# track the branch we are interested in
#
#echo "Tracking hyperv-dev-8.2"
#
#git branch --track hyperv-dev-8.2 origin/hyperv-dev-8.2
#if [ $? -ne 0 ]; then
#    echo "Error: unable to track hyperv-dev-8.2"
#    exit 25
#fi

echo "Checking out hyperv-dev-8.2"

git checkout hyperv-dev-8.2
if [ $? -ne 0 ]; then
    echo "Error: unable to checkout hyperv-dev-8.2"
    exit 27
fi

#
# Create a tarball of the git tree, including todays date in the name
#
echo "Creating tarball"
cd ..

today=`date "+%F"`
echo "tar -cjf ${ARCHIVES_DIR}/freebsd-${today}.tar.bz2 freebsd"

tar -cjf ${ARCHIVES_DIR}/freebsd-${today}.tar.bz2 freebsd
if [ $? -ne 0 ]; then
    echo "Error: Unable to create tarball of todays FreeBSDonHyper-V project"
    exit 30
#
#Delete existing freebsd-current.tar.bz2 file if new tar created succesfully
#
else
    if [ -f ${ARCHIVES_DIR}/freebsd-current.tar.bz2 ]; then
    echo "Delete old freebsd-current.tar.bz2 file"
    rm -rf ${ARCHIVES_DIR}/freebsd-current.tar.bz2
    fi
fi


#
# Create a link named freebsd-current.tar that points to today's tarball
#
#echo "Creating link"
#cd ${ARCHIVES_DIR}
#rm -f freebsd-current.tar
#ln -s ./freebsd-${today}.tar ./freebsd-current.tar

#
# Make a copy of the file to avoid some of the symlink issues when
# mounting and using an NFS export.
#
cp ${ARCHIVES_DIR}/freebsd-${today}.tar.bz2 ${ARCHIVES_DIR}/freebsd-current.tar.bz2
if [ $? -ne 0 ]; then
    echo "Error: Unable to rename tarball of todays FreeBSDonHyper-V project to freebsd-current"
    exit 40
else
    chmod 644 ${ARCHIVES_DIR}/freebsd-current.tar.bz2
#
#Delete freebsd-${today}.tar.bz2 file
#    
	if [ -f ${ARCHIVES_DIR}/freebsd-${today}.tar.bz2 ]; then
    echo "Delete freebsd-${today}.tar.bz2 file"
    rm -rf ${ARCHIVES_DIR}/freebsd-${today}.tar.bz2
    fi
fi

exit 0

