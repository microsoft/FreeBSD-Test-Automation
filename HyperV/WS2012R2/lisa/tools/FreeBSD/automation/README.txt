This script is written with csh. 
The follonging functions have been completed for image preparation automation.

Nov. 24, 2014

==============================================================
Install required software by running command "pkg install XXX"
==============================================================
· unix2dos 
· python
· git 
· subversion
· gcc

i. pkg install gcc
ii. ln -s  /usr/local/bin/gcc47 /usr/bin/gcc
ln -s  /usr/local/bin/gcc48 /usr/bin/gcc  (it depends)

==============================================================
Enable ssh remote logon
==============================================================
a. Edit /etc/ssh/sshd_config  and change
    #PermitRootLogin no 
To
    PermitRootLogin yes

b. Copy the public key (lisa_id_rsa.pub to ~/.ssh/authorized_keys) (the configuration is freebsd to freebsd direct access but no check)
mkdir ~/.ssh
touch ~/.ssh/id_rsa
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
touch ~/.ssh/authorized_keys
(copy file ssh/lisa_id_rsa.pub to ~/.ssh by winscp tool)
cat ~/.ssh/lisa_id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

==============================================================
Bash support
==============================================================
pkg install bash
create a soft link/symbolic link for /usr/local/bin/bash to /bin/bash
# ln -s /usr/local/bin/bash /bin/bash


==============================================================
Config /etc/rc.conf 
==============================================================
ifconfig_hn0="SYNCDHCP"
ifconfig_hn0_ipv6="inet6 accept_rtadv"

firewall_enable="NO"
sendmail_enable="NONE"
sendmail_msp_queue_enable="NO"
sendmail_outbound_enable="NO"
sendmail_submit_enabled="NO"

To ping arp server:
eg: ping -c 3 -t 10  10.156.76.53  

==============================================================
Config /boot/loader.conf 
==============================================================
autoboot_delay="2"

