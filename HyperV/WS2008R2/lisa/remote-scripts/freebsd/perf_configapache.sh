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


########################################################################
#
# Description:
#    This test script installs and configures Apache for
#    use with the WCAT web load utility.  Currently, the
#    following distributions have been tested:
#					FreeBSD
#
#    Test cases can be passed test parameters.  This script does
#    not have any mandatory test parameters.  The following
#    test parameters may be passed.
#
#    Test Parameters
#        APACHE_PACKAGE           Name of the apache package to install.
#                                 For Ubuntu it is "apache2"
#
#        INSTALL_MONO=TRUE        Installs the Mono packages if this
#                                 test parameter is present.  The value
#                                 of this test parameter is not checked,
#                                 only if it exists.
#
#        MONO_PACKAGE1            Name of the first Mono package to install.
#
#        MONO_PACKAGE2            Name of the second Mono package to install.
#
#
#
########################################################################


#
# Constants/Globals
#
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occured during the test

CONSTANTS_FILE="~/constants.sh"
SUMMARY_LOG=~/summary.log

APACHE_PACKAGE="apache2"
MONO_PACKAGE1="libapache2-mod-mono"
MONO_PACKAGE2="mono-apache-server2"
WF_PROXY_ZIP="/root/wfproxy.zip"
UNZIP_PACKAGE="unzip"
DOC_ROOT="/var/www"


########################################################################
#
# Local functions
#
########################################################################

LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the timestamp to the log message
    echo "${1}" >> ~/wcat.log
}


UpdateTestState()
{
    echo "${1}" > ~/state.txt
}


UpdateSummary()
{
    echo "${1}" >> ~/summary.log
}


BSDRelease()
{
	RELEASE=`uname -s`

	case $RELEASE in
		FreeBSD)
			echo "FreeBSD";;
	esac
}

#######################################################################
#
# FreeBSDInstallApache()
#
# Description:
#    Perform FreeBSD specific steps to install Apache and the
#    wcat content.
#
#######################################################################

FreeBSDInstallApache()
{
		LogMsg "FreeBSD detected"

    APACHE_PACKAGE=apache24

    DOC_ROOT="/usr/local/www/apache24/data"
    NEW_ROOT="/home/www"

    #
    # Install apache if it is not already installed
    #
    LogMsg "FreeBSD - Checking if Apache is installed"

    httpd=`pkg info | grep "${APACHE_PACKAGE}"`
    if [ ! "${httpd}" ]; then
        LogMsg "${APACHE_PACKAGE} is not installed.  Installing"
        pkg install -y "${APACHE_PACKAGE}"
        if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to install apache package '${APACHE_PACKAGE}'"
            UpdateTestState $ICA_TESTFAILED
            exit 1
        fi

				#
				# Config apache to start automatially on boot
				#
        echo "apache24_enable=\"YES\"" >> /etc/rc.conf
    fi

		#
		# unzip on FreeBSD is problematic with our zip, install 7zip instead
		#
		p7zip=`pkg info | grep p7zip`
		if [ ! "${p7zip}" ]; then
			LogMsg "p7zip not installed. Installing"
			pkg install -y p7zip
			if [ $? -ne 0]; then
				LogMsg "Error: Unable to install p7zip"
				UpdateTestState $ICA_TESTFAILED
				exit 1
			fi
		fi

    #
    # Make sure the default web content directory was created
    #
    LogMsg "FreeBSD - Verify web content directory was created"

    if [ ! -e ${DOC_ROOT} ]; then
        LogMsg "Error: The httpd content directory '${DOC_ROOT}' was not created"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    #
    # Create a new directory for web content.  Note: This is needed
    # since the partition hosting the original content is not
    # large enough to hold the WCAT test content.
    #
    LogMsg "FreeBSD - Check if new web content directory exists"

    if [ ! -e "${NEW_ROOT}" ]; then
        LogMsg "FreeBSD - Creating new content directory '${NEW_ROOT}'"
        mkdir -p "${NEW_ROOT}"
        if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to create new content directory '${NEW_ROOT}'"
            UpdateTestState $ICA_TESTFAILED
            exit 1
        fi
    fi

    #
    # Update the /usr/local/etc/apache24/httpd.conf file to point to new root
    #
    LogMsg "FreeBSD - Update apache DocumentRoot to new content directory"

    sed -i "~" -e "s~/usr/local/www/apache24/data~/home/www~g" /usr/local/etc/apache24/httpd.conf
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to update DocumentRoot in httpd.conf"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    #
    # Verify the content .zip file exists
    #
    LogMsg "FreeBSD - Verify the web content zip file exists"

    if [ ! -e "${WF_PROXY_ZIP}" ]; then
        LogMsg "Error: The content zip filee '${WF_PROXY_ZIP}' does not exist"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    #
    # Unzip the content
    #
    LogMsg "FreeBSD - Unzip the web content"

		if [ ! -e "${NEW_ROOT}/wf_proxy" ]; then
			cp ${WF_PROXY_ZIP} ${NEW_ROOT}/
			cd "${NEW_ROOT}"

			LogMsg "FreeBSD - Directory '${NEW_ROOT}/wf_proxy' does not exist.  Unzipping content"
        7za x "${WF_PROXY_ZIP}" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            LogMsg "Error: Unable to unzip content archive"
            UpdateTestState $ICA_TESTFAILED
            exit 1
					fi
    fi

    #
    # Move the hot and cold content to the correct locations
    #
    LogMsg "FreeBSD - Move the cold content to the correct location"

    mv "${NEW_ROOT}/wf_proxy/root/cold" "${NEW_ROOT}/wf_proxy/cold"
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to move cold content to correct location"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    LogMsg "FreeBSD - move the hot content to the correct location"

    mkdir -p "${NEW_ROOT}/wf_mscom"
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to create directory to move hot content"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    mv "${NEW_ROOT}/wf_proxy/root/hot" "${NEW_ROOT}/wf_mscom/hot"
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to move hot content"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    LogMsg "FreeBSD - move the aspx content to the correct location"

    mv "${NEW_ROOT}/wf_proxy/root/aspx" "${NEW_ROOT}/wf_mscom/aspx"
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to move aspx content"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    #
    # Fix permissions
    #
    LogMsg "FreeBSD - Fixing permisssions"
    chmod -R a+xr "${NEW_ROOT}/wf_proxy"


    #
    # Restart httpd
    #
    LogMsg "FreeBSD - Restarting httpd"

		service apache24 restart
    if [ $? -ne 0 ]; then
        "Error: Unable to restart apache24"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

    #
    # Verify we can access a page
    #
    LogMsg "FreeBSD - Test access to a wf proxy page"

    wget "http://localhost/wf_proxy/cold/0/1.htm"
    if [ $? -ne 0 ]; then
        LogMsg "Error: Unable to read page from Apache"
        UpdateTestState $ICA_TESTFAILED
        exit 1
    fi

}

########################################################################
#
# Main script body
#
########################################################################

#
# Let the automation engine know this script is running
#
UpdateTestState $ICA_TESTRUNNING
LogMsg "Updating test case state to running"

rm -f $SUMMARY_LOG
touch $SUMMARY_LOG

#
# Source the constants.sh file to pick up definitions
# from the ICA automation
#
#if [ -e ${CONSTANTS_FILE} ]; then
#    source ${CONSTANTS_FILE}
#else
#    LogMsg "Warn : The file '${CONSTANTS_FILE}' does not exist"
#fi


distro=$(BSDRelease)
case $distro in
    "FreeBSD")
    		FreeBSDInstallApache
    ;;
    *)
        LogMsg "Distro '${distro}' not supported"
        UpdateTestState "TestAborted"
        UpdateSummary " Distro '${distro}' not supported"
        exit 1
    ;; 
esac

#
# Verify we can read a page of our content
#
LogMsg "Read a page of content from Apache"

cd ~
wget http://localhost/wf_proxy/cold/1/12.htm
if [ $? -ne 0 ]; then
    LogMsg "Error: Unable to access http://localhost/wf_proxy/cold/1/12.htm"
    UpdateTestState $ICA_TESTFAILED
    exit 110
fi

rm -f ./12.htm
UpdateTestState $ICA_TESTCOMPLETED

LogMsg "Test completed successfully"

exit 0

