#!/bin/csh

#Note: This script is csh, not bash.
#      This script is only for FreeBSD10.0 or higher version.
set currentPath = `pwd`   
set logFile = $currentPath/checkgitupdate.log       
set tempLogFile = $currentPath/checkgitupdate_tmp.log       
set pythonScript = $currentPath/runbistests.py
set defaultSrcPath = /usr/head
set branch  =  "dev"                 #Default git branch is dev
          
date > $logFile

#Give help information 
if( $#argv >= 1 ) then
	if( "$argv[1]" == "--h" || "$argv[1]" == "--help" ) then
		echo "Usage:"
		echo "./checkgitupdate.sh [-branch <branchName>]"
		echo "Set branchName as git branch otherwise using the default branch: $branch"
		exit 0
	endif
endif

#Parse input parameters
@ i = 1
while( $i <= $#argv )
    if( "$argv[$i]" == "-branch" ) then
        @ i = $i + 1
        if( $i >  $#argv ) then
            echo "Please provide a branch name" 
            exit 1
        else
            set branch  = $argv[$i] 
        endif
    endif
       @ i = $i + 1
end

echo "The branch name is $branch"   >> $logFile

#The python script must exist
if( ! -e $pythonScript ) then
	echo "Error: $pythonScript  doesn't exist."  >> $logFile
	exit 1
endif

cd  $defaultSrcPath
if( $? != 0 ) then
	echo "Error: $defaultSrcPath doesn't exist."  >> $logFile
	exit 1
endif 

echo "Git switches to $branch branch" >> $logFile 
git checkout $branch >> $logFile 
if( $? != 0 ) then
	echo "Error: Git checkout $branch failed."  >> $logFile
	exit 1
endif  

#Execute the python script when the git repository is updated
while( 1 )
	date > $tempLogFile
	
	git pull >>& $logFile
	git pull >>& $tempLogFile
	if( $? != 0 ) then
		echo "Error: Git pull failed"  >> $logFile
		echo "Now begin to sleep 30 seconds"   >> $logFile
		sleep 30
		continue
	endif 
	
	#To avoid concurrent execution
	sleep 5 

	cat $tempLogFile | grep "Already up-to-date"
	if( $? != 0 ) then
		#Git repository is updated, so call python script
		echo "Call python script to trigger BIS tests"  >> $logFile
		python $pythonScript
	endif 
	
	echo "Now begin to sleep 300 seconds"  >> $logFile
	sleep 300
end 


