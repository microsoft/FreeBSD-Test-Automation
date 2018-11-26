#!/bin/csh

#Note: This script is csh, not bash.
#      This script is only for FreeBSD10.0 and higher version.

set PublicKeyFileName=lisa_id_rsa.pub 

@ ErrorCount = 0       #To record how many errors occurs 
set LogFile=/root/AutoTestPrepare.log     
set NFS_SERVER=10.156.76.149        #If the nfs service ip changed, please update this value.
set NFS_EXPORT=/usr/lisa/public
set SSH_Path=/root/.ssh
set app
set applications = ("bash gcc unix2dos git python subversion")
set ARP_SERVER=10.156.76.53        #If the arp service ip changed, please update this value.

date > $LogFile

#To install bash, gcc, unix2dos, git, python, subversion
#You can add other applications in this script in the future
foreach  app ($applications) 
pkg info $app 
if ( $? == 0 ) then
    echo "$app  had installed before" >> $LogFile
else
    echo "Start to install $app ..."
    pkg install $app  <<HERE
y
HERE
    if ( $? == 0 ) then 
        echo "$app install successful!"    >> $LogFile
    else
        echo "Error:$app install failed!"  >> $LogFile
        @ ErrorCount = $ErrorCount + 1
    endif
endif
end

pkg info gcc
if ( $? == 0 ) then
    if ( -e /bin/gcc ) then 
        echo "/bin/gcc file exists!" >> $LogFile 
    else
        ln -s /usr/local/bin/gcc48 /bin/gcc
        if ( $? == 0 ) then 
            echo "ln -s /usr/local/bin/gcc48 /bin/gcc successful!"    >> $LogFile
        else
            echo "Error:ln -s /usr/local/bin/gcc48 /bin/gcc failed!"  >> $LogFile
            @ ErrorCount = $ErrorCount + 1
        endif
    endif
endif
    

pkg info bash  
if ( $? == 0 ) then
    if ( -e /bin/bash ) then 
        echo "/bin/bash file exists!" >> $LogFile 
    else
        ln -s /usr/local/bin/bash  /bin/bash
        if ( $? == 0 ) then 
            echo "ln -s /usr/local/bin/bash  /bin/bash successful!"    >> $LogFile
        else
            echo "Error:ln -s /usr/local/bin/bash  /bin/bash failed!"  >> $LogFile
            @ ErrorCount = $ErrorCount + 1
        endif
    endif
endif

#Edit /etc/ssh/sshd_config and change "#PermitRootLogin no" to "PermitRootLogin yes"
sed -i .bak 's/^[#| ]*PermitRootLogin[ ]*no/PermitRootLogin  yes/g' /etc/ssh/sshd_config

#To restart ssh daemon
/etc/rc.d/sshd  restart
if( $? != 0 ) then
    echo "Error:Restart ssh daemon failed!"  >> $LogFile
    @ ErrorCount = $ErrorCount + 1
endif


#To copy the public key enable freebsd to freebsd direct access.
#Here public key is stored on NFS_SERVER under NFS_EXPORT. 
mount -t nfs  -o nfsv4 ${NFS_SERVER}:${NFS_EXPORT} /mnt &
sleep 5
if( ! -e  /mnt/$PublicKeyFileName ) then 
    kill -9 `ps aux | grep mount | awk '{print $2}'`
    sleep 3   #Make sure kill "mount" process
    #Try to nfs cmd  again
    mount -t nfs  ${NFS_SERVER}:${NFS_EXPORT} /mnt &
    sleep 5
    if( ! -e /mnt/$PublicKeyFileName ) then 
        kill -9 `ps aux | grep mount | awk '{print $2}'`
        @ ErrorCount = $ErrorCount + 1
        echo "Error:mount cmd failed or no $PublicKeyFileName exists on ${NFS_SERVER}"  >> $LogFile
    endif
endif

if( -e /mnt/$PublicKeyFileName ) then
    cp /mnt/$PublicKeyFileName  /root/
    if( $? == 0 ) then 
        echo "cp /mnt/$PublicKeyFileName  /root/$PublicKeyFileName successful."   >> $LogFile 
    else
        echo "Error:cp /mnt/$PublicKeyFileName  /root/$PublicKeyFileName failed"  >> $LogFile 
        @ ErrorCount = $ErrorCount + 1
    endif
    umount /mnt
endif    


if( -e $SSH_Path ) then
    rm -rf $SSH_Path 
    if( $? != 0 ) then
        echo "Error:rm /SSH_Path failed!"  >> $LogFile
        @ ErrorCount = $ErrorCount + 1
    endif
endif

#To create the .ssh and configure the files in it
if( ! -e $SSH_Path ) then
    mkdir $SSH_Path
    touch $SSH_Path/id_rsa
    chmod 700 $SSH_Path
    chmod 600 $SSH_Path/id_rsa
    touch $SSH_Path/authorized_keys
    cat /root/$PublicKeyFileName  >> $SSH_Path/authorized_keys
    chmod 600 $SSH_Path/authorized_keys
endif

#To config the hn0 as dynamic network
grep "^[ ]*ifconfig_hn0_ipv6" /etc/rc.conf
if( $? != 0 ) then
    echo 'ifconfig_hn0="SYNCDHCP"'  >> /etc/rc.conf
    echo 'ifconfig_hn0_ipv6="inet6 accept_rtadv"' >> /etc/rc.conf
endif

#To make boot up faster, add the following config in /etc/rc.conf
grep "^[ ]*firewall_enable"  /etc/rc.conf
if( $? != 0 ) then 
    cat <<EOF>> /etc/rc.conf 
firewall_enable="NO"
sendmail_enable="NONE"
sendmail_msp_queue_enable="NO"
sendmail_outbound_enable="NO"
sendmail_submit_enabled="NO"
EOF
endif

#Change the delay time for booting
grep "^[ ]*autoboot_delay"  /boot/loader.conf
if( $? != 0 ) then
    echo 'autoboot_delay="2"'   >> /boot/loader.conf
endif

#To get IP address using arp -a command, but it needs ping arp server first.
grep "^[ ]*ping[ ]*-c[ ]*3[ ]*-t[ ]*10[ ]*${ARP_SERVER}"  /etc/rc.conf
if( $? != 0 ) then 
    cat <<EOFB>> /etc/rc.conf
#ping arp server
ping -c 3 -t 10  ${ARP_SERVER}
EOFB
endif

#Add new preparation steps from here


if( $ErrorCount == 0 ) then
    echo "Preparation completes successfully!"          >> $LogFile
else 
    echo "Preparation ends with $ErrorCount errors."    >>  $LogFile
endif

