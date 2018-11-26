#!/bin/csh

#Note: This script is csh, not bash.
#      This script is only for FreeBSD10.0 or higher version.

set LogFile=/root/sync_build_install.log       
set DefaultSrcPath = /usr/head
set branch  =  "dev"     #Default git branch is dev
@ RetryTimes = 0 
@ TotalTimes = 6         #The total retry times for git pull 

date > $LogFile

#Provide help information 
if( $#argv >= 1 ) then
	if( "$argv[1]" == "--h" || "$argv[1]" == "--help" ) then
		echo "Usage:"
		echo "./sync_build_install.sh [-branch <branchName>]"
		echo "Default branch: $branch"
		exit 0
	endif
endif

#Parse input parameters
@ i = 1
while( $i <= $#argv )
    if( "$argv[$i]" == "-branch" ) then
        @ i = $i + 1
        if( $i >  $#argv ) then
            echo "Error: Please specify a branch name" | tee -a $LogFile
            exit 1
        else
            set branch  = $argv[$i] 
			break
        endif
    endif
    @ i = $i + 1
end

echo "The branch name is $branch"   >> $LogFile

#Sync code, build and install kernel

cd  $DefaultSrcPath
if( $? != 0 ) then
	echo "Error: $DefaultSrcPath doesn't exist."  >> $LogFile
	exit 1
endif  

echo "Switch to dev branch first" >> $LogFile 
git checkout dev >> $LogFile 
if( $? != 0 ) then
	echo "Error: git checkout dev failed."  >> $LogFile
	exit 1
endif  

while( $RetryTimes < $TotalTimes )
	sleep 10	
	git pull >>& $LogFile 
	if( $? == 0 ) then
		break
	endif   
	
	echo "Warnning: retry to git pull"     >> $LogFile
	@ RetryTimes = $RetryTimes + 1
end 

if( $RetryTimes >= $TotalTimes ) then
	echo "Error: git pull failed."  >> $LogFile
	exit 1
endif

echo "Switch to $branch branch" >> $LogFile 
git checkout $branch >> $LogFile 
if( $? != 0 ) then
	echo "Error: git checkout $branch failed."  >> $LogFile
	exit 1
endif  

git pull >>& $LogFile 
if( $? != 0 ) then
	echo "Error: git pull failed."  >> $LogFile
	exit 1
endif  

echo "Git pull successfully."       >> $LogFile

uname -p | grep "i386"
if( $? == 0 ) then
	echo "The processor is i386."     >> $LogFile
	make buildkernel KERNCONF=GENERIC TARGET=i386 TARGET_ARCH=i386 -j4 NOCLEAN=YES
	if( $? != 0 ) then
	    echo "Error: Build kernel failed." >> $LogFile
		exit  1
	endif
else
	echo "The processor is amd64."    >> $LogFile 
	make -j4 buildkernel KERNCONF=GENERIC NOCLEAN=YES
	if( $? != 0 ) then
	    echo "Error: Build kernel failed." >> $LogFile
		exit  1
	endif
endif

echo "Build kernel successfully."  >> $LogFile

make installkernel KERNCONF=GENERIC
if( $? != 0 ) then
	echo "Error: Install kernel failed."  >> $LogFile
	exit 1
endif   

echo "Install kernel successfully."  >> $LogFile

#Add new preparation steps from here


echo "Reboot VM after syncing, building and installing kernel successfully."  >>  $LogFile
reboot



