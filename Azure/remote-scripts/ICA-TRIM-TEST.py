#!/usr/bin/env python
from azuremodules import *

import argparse

parser = argparse.ArgumentParser()

parser.add_argument('-f', '--filesystem', help='file system type', required=True)
args = parser.parse_args()
filesystem = args.filesystem

def RunTest():
    RunLog.info("File system is "+filesystem)
    
    if("UFS" in filesystem):
      Run("gpart create -s GPT /dev/da2")
      Run("gpart add -t freebsd-ufs /dev/da2")
      Run("newfs -t /dev/da2p1")
      Run("mkdir /mnt/datadisk")
      Run("mount /dev/da2p1 /mnt/datadisk")

    else:
      Run("service zfs onestart")
      Run("echo 'zfs_enable=\"YES\"' >> /etc/rc.conf")
      Run("sysctl vfs.zfs.trim.enabled=1")
      Run("zpool create Test /dev/da2")
    
RunTest()