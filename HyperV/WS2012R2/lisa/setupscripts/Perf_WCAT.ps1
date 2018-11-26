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


<#
.synopsis
    Run the WCAT web workload generator and target a Linux VM.

.Description
    Configure a Linux VM with Apache, add content to the Linux/Apache
    VM, and then run the WCAT workload generator against the Linxu VM.

    This PowerShell test script will run a Bash script on the VM that
    will install Apache, and then add web content files.  The content
    is provided in a .zip file identified by the WF_PROXY_ZIP test
    parameter.  This work is performed on the Linux VM by a Bash script
    identified by the CONFIG_APACHE_SCRIPT test parameter.

    Once the Linux VM is configured, this script will install WCAT on 
    the localhost.  The .ubr files will be copied to the WCAT directory.
    The .ubr files are copied from the directory specified by the
    TEST_CONTENT_DIR test parameter.  A check will be done to verify
    the .ubr files specified in the SCENARIO_FILE and  SETTINGS_FILE
    do exist.
    
    The WCAT web workload generator will be started using the specified
    .ubr files, and will target the VM specified with the TARGET_IP test
    parameter.

    WCAT creates a log.xml file.  Once the WCAT test completes, the
    wcutil utility will be run to process the log.xml file and the 
    test results data will be copied the test run log directory.

    A typical test case definition for this test script would look similar to
    the following:
        <test>
            <testName>Perf_Wcat</testName>
            <testScript>setupScripts\Perf_wcat.ps1</testScript>
            <files>remote-scripts\ica\perf_configapache.sh,tools\wfproxy.zip</files>
            <timeout>7200</timeout>
            <onError>Continue</onError>
            <noReboot>True</noReboot>
            <testparams>
                <param>TC_COVERED=PERF-WCAT</param>
                <param>TARGET_IP=10.200.51.224</param>
                <param>SCENARIO_FILE=static.cold.ubr</param>
                <param>SETTINGS_FILE=wcat.settings.ubr</param>
                <param>CONFIG_APACHE_SCRIPT=perf_configapache.sh</param>
                <param>TEST_CONTENT_DIR=\\redmond\winplaceholder\TestContent\Server\IAT\OSTC\LIS\WCAT</param>
                <param>WORKLOAD_CLIENT=localhost</param>
                <param>WF_PROXY_ZIP=wfproxy.zip</param>
                <param>APACHE_PACKAGE=apache2</param>
            </testparams>
        </test>

.Parameter vmName
    Name of the test VM.

.Parameter hvServer
    Name of the Hyper-V server hosting the test VM.

.Parameter testParams
    Test parameters are a way of passing variables into the test case script.

.Example:
    .\setupscripts\Perf_WCAT.ps1 SLES11SP3X64 localhost "TC_COVERED=PERF-WCAT;TARGET_IP=192.168.1.10;SCENARIO_FILE=static.cold.ubr;SETTINGS_FILE=wcat.settings.ubr;CONFIG_APACHE_SCRIPT=perf_ubuntuconfigapache.sh;TEST_CONTENT_DIR=.\TestData\Perf_wcat.xml;WORKLOAD_CLIENT=localhost;WF_PROXY_ZIP=wfproxy.zip;APACHE_PACKAGE=apache2;rootDir=E:\lisablue\WS2012R2\lisa;TestLogDir=C:\lisa\TestResults\Perf_Wcat-20140417-112654;TestName=Perf_Wcat;scriptMode=TestCase;ipv4=192.168.1.10;sshKey=rhel5_id_rsa.ppk;"
#>


param( [String] $vmName, [String] $hvServer, [String] $testParams )


#
# Global settings
#
$systemDrive    = $env:systemdrive
$wcatDir        = "${systemDrive}\Program Files\wcat"


#######################################################################
#
# Main body of script
#
#######################################################################

$retVal = $False    # Assume failure

#
# Verify command line options
#
"Info : Verify command line arguments"

if (-not $vmName)
{
    "Error: no VMName was specified"
    return $False
}

if (-not $hvServer)
{
    "Error: No hvServer was specified"
    return $False
}

if (-not $testParams)
{
    "Error: No test parameters specified"
    return $False
}

#
# Parse the test parameters
#
"Info : Parsing the test parameters"

$rootDir = $null
$tcCovered = "Undefined"
$sshKey = $null
$targetIP  = $nullb

$scenarioFile = $null
$settingsFile = $null
$configApacheScript = $null
$testContentDir = $null
$workloadClient = $null

$testLogDir = $null

########################################## Debug ###############################
#$testParams =  "SCENARIO_FILE=static.cold.ubr;"
#$testParams += "SETTINGS_FILE=wcat.settings.ubr;"
#$testParams += "TARGET_IP=10.200.51.224;"
#$testParams += "sshKey=rhel5_id_rsa.ppk;"
#$testParams += "rootDir=C:\Users\nmeier;"
#$testParams += "config_apache_script=perf_configapache.sh;"
#$testParams += "TEST_CONTENT_DIR=\\redmond\winplaceholder\TestContent\Server\IAT\OSTC\LIS\WCAT;"
#$testParams += "WORKLOAD_CLIENT=localhost;"
#$testParams += "TestLogDir=D:\Public"
######################################### end Debug ############################
$testParams

$params = $testParams.Split(";")
foreach ($p in $params)
{
    $fields = $p.Split("=")
    switch ($fields[0].Trim())
    {      
    "rootdir"              { $rootDir            = $fields[1].Trim() }
    "TC_COVERED"           { $tcCovered          = $fields[1].Trim() }
    "TARGET_IP"            { $targetIP           = $fields[1].Trim() }
    "SSHKEY"               { $sshKey             = $fields[1].Trim() }
    "SCENARIO_FILE"        { $scenarioFile       = $fields[1].Trim() }
    "SETTINGS_FILE"        { $settingsFile       = $fields[1].Trim() }
    "CONFIG_APACHE_SCRIPT" { $configApacheScript = $fields[1].Trim() }
    "TEST_CONTENT_DIR"     { $testContentDir     = $fields[1].Trim() }
    "WORKLOAD_CLIENT"      { $workloadClient     = $fields[1].Trim() }
    "TestLogDir"           { $testLogDir         = $fields[1].Trim() }
    default                {}       
    }
}

if (-not $rootDir)
{
    "ERROR : no rootdir was specified"
    return $False
}
else
{
    cd $rootDir
}

$testContentDir = [System.IO.Path]::Combine($rootDir, $testContentDir)
if (-not $targetIP)
{
    "INFO : TARGET_IP is not defined in the XML file. Try to get it by KVP..."
    #
    # Source the other files we need
    #
    . $rootDir\utilFunctions.ps1 | out-null
    $targetIP = GetIPv4 $vmName $hvServer
}

#
# Verify required parameters were provided
#
"Info : Verify required parameters were provided"

if (-not $targetIP)
{
    "Error: test parameter TARGET_IP was not provided; also failed to get IPv4 by KVP."
    return $False
}

if (-not $sshKey)
{
    "Error: test parameter SSHKEY was not provided"
    return $False
}

if (-not $scenarioFile )
{
    "Error: test parameter SCENARIO_FILE was not provided"
    return $False
}

if (-not $settingsFile )
{
    "Error: test parameter SETTINGS_FILE was not provided"
    return $False
}

if (-not $configApacheScript )
{
    "Error: test parameter CONFIG_APACHE_SCRIPT was not provided"
    return $False
}

if (-not $testContentDir)
{
    "Error: test parameter TEST_CONTENT_DIR was not provided"
    return $False
}

if (-not (Test-Path $testContentDir))
{
    "Error: The TEST_CONTENT_DIR '${testContentDir}' does not exist"
    return $False
}

if (-not $workloadClient)
{
    "Error: test parameter WORKLOAD_CLIENT was not provided"
    return $False
}

if (-not $testLogDir)
{
    "Error: test parameter TestLogDir was not provided"
    "       Note - Lisa adds this parameter automatically"
    return $False
}

$summaryLog  = ".\${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue

echo "Covers : ${tcCovered}" >> $summaryLog

#
# Configure Apache on the target VM
#
"Info : set the x bit on the ${configApacheScript} script"
bin\plink.exe -i ssh\${sshKey} root@${targetIP} "chmod 755 /root/${configApacheScript}"
if (-not $?)
{
    "Error: Unable to set x bit on /root/${configApacheScript}"
    return $False
}

"Info : Run /root/${configApacheScript} on test VM"
bin\plink.exe -i ssh\${sshKey} root@${targetIP} "/root/${configApacheScript} >& /dev/null"

if (-not $?)
{
    "Error: unable to run perf_configapache.sh on target VM"
    return $False
}

#
# Verify we can access a web page on the target VM
#
"Info : Test access to web content on target VM"

$wc = New-Object System.Net.Webclient
if (-not $wc)
{
    "Error: Unable to create Webclient object"
    return $False
}

$testURL = "http://${targetIP}/wf_proxy/cold/1/1.htm"
$destFile = "${PWD}\testfile.htm"

$wc.DownloadFile($testURL, $destFile)
if (-not (Test-Path $destFile))
{
    "Error: Test file not downloaded"
    return $False
}

del $destFile -ErrorAction SilentlyContinue

#
# If WCAT is not installed, install it
#
"Info : Check if WCAT is installed"

if ( -not (Test-Path "${wcatDir}" ))
{
    "Info : Installing WCAT"

    mkdir "${wcatDir}"
    if (-not $?)
    {
        "Error: Unable to create directory to host wcat files"
        return $False
    }

    copy "${testContentDir}\Install\*" "${wcatDir}"
    if (-not $?)
    {
        "Error: Unable to copy wcat files to '${wcatDir}'"
        return $False
    }

    "Info : Verify wcat is installed at: ${wcatDir}"

    if ( -not (Test-Path "${wcatDir}\wcat.wsf" ))
    {
        "Error: WCAT did not installed"
        return $False
    }
}

#
# Install the UBR files
#
"Info : Copying the .ubr files"

if (-not (Test-Path "${wcatDir}\UBR"))
{
    mkdir "${wcatDir}\UBR"
    if (-not $?)
    {
        "Error: Unable to create the UBR directory"
        return $False
    }
}

copy "${testContentDir}\UBR\*.ubr" "${wcatDir}\UBR\"
if (-not $?)
{
    "Error: Unable to copy .ubr files to UBR directory"
    return $False
}

#
# Set the default script host
#
"Info : Setting up the default script host"

cd "${wcatDir}"
cscript //H:Cscript
if (-not $?)
{
    "Error: Unable to set default script host"
    return $False
}

#
# If wcat is not install on the workload generator client, install it
# Note: Currently, this script assumes there is only one workload client.
#       Installing wcat on the workload generator may result in a reboot.
#       This is due to some registery changes.
#
"Info:  Install wcat client on localhost"

if (-not (Test-Path "\\${workloadClient}\admin$\wcat"))
{
    #
    # WCAT is not installed on the work load client, so install it
    #
    .\wcat.wsf -update -s ${workloadClient}
    if (-not $?)
    {
        "Error: Unable to install wcat on workload client '${workloadClient}'"
        return $False
    }
}

#
# Verify the specified .ubr files exist
#
"Info : Verify the user specified .ubr files exists"

if (-not (Test-Path "${wcatDir}\UBR\${scenarioFile}"))
{
    "Error: The scenario file '${scenarioFile}' does not exist"
    return $False
}

if (-not (Test-Path "${wcatDir}\UBR\${settingsFile}"))
{
    "Error: The settings file '${settingsFile}' does not exist"
    return $False
}

#
# Run wcat
#
"Info : Delete any old log files"

del .\log.xml -ErrorAction SilentlyContinue
del .\report.* -ErrorAction SilentlyContinue

"Info : Run wcat"
echo ".\wcat.wsf -terminate -run -clients localhost -t .\UBR\${scenarioFile} -f .\UBR\${settingsFile} -s ${targetIP}"

.\wcat.wsf -terminate -run -clients localhost -t .\UBR\${scenarioFile} -f .\UBR\${settingsFile} -s ${targetIP}
if (-not $?)
{
    "Error: wcat failed"
}
else
{
    $retVal = $True
}

#
# Run wcutil to parse the log file
#
"Info : Processing log.xml"

#
# Create a name for the log file that includes the test content type
# Values are either "hot" or "cold"
#
$wcatLogfile = "${testLogDir}\${vmName}_"
$contentType = "cold"
if ( $scenarioFile -match "hot" )
{
    $contentType = "hot"
}
$wcatLogfile += "${contentType}_wcat.log"

"Info : test metrics will be stored in the file '${wcatLogfile}'"

.\wcutil.exe .\log.xml > "${wcatLogfile}"

return $retVal
