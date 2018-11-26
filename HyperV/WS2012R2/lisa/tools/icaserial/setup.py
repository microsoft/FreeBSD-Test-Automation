#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
This is the script to perform installation/uninstallation for icatest.

Author: Fuzhou Chen (fuzhouch@microsoft.com)
        Like Zhu    (likezh@microsoft.com)
"""

import os
import sys
from distutils.core import setup
import distutils.command.install

scripts = ['icadaemon', 'icalauncher', 'ica-ipv4', 'ica-tcstatus',
           'ica-ostype', 'ica-datetime', 'ica-shutdown']
bins = map(lambda x: os.path.join('bin', x), scripts)

# The following scripts are for environ setup in POSIX enviroment.
cfg_scripts = ['icadaemon_sysv', 'icadaemon_bsd']
cfgs = map(lambda x: os.path.join('cfg', x), cfg_scripts)
shared_data_path = os.path.join(sys.prefix, 'share', 'icadaemon')
sysv_script = cfgs[0]
bsd_script = cfgs[1]


class daemon_setup(distutils.command.install.install):
    """
    This is our own daemon_setup class to implement post installation
    steps. It executes standard installation method, then run our own
    customized steps to deploy service management script to correct
    place.
    """
    def run(self):
        distutils.command.install.install.run(self)
        self.__setup_daemon()
    def __setup_daemon(self):
        if os.name.lower() != 'posix':
            return # Unknown system, do nothing
        # We support both System V and FreeBSD. Most System V style
        # Linux systems use chkconfig.
        prog = 'chkconfig'
        fpath = None
        is_sysv = False
        for path in os.environ["PATH"].split(os.pathsep):
            fpath = os.path.join(path, prog)
            if os.path.exists(fpath) and os.access(fpath, os.X_OK):
                is_sysv = True
                break
        if is_sysv:
            os.system("cp -f %s /etc/init.d/icadaemon" % sysv_script)
            os.system("chown root /etc/init.d/icadaemon")
            os.system("chgrp root /etc/init.d/icadaemon")
            os.system("chmod 755 /etc/init.d/icadaemon")
            os.system("%s --add icadaemon" % fpath)
        else:
            os.system("cp -f %s /usr/local/etc/rc.d/icadaemon" % bsd_script)
            os.system("chown root /usr/local/etc/rc.d/icadaemon")
            os.system("chmod 755 /usr/local/etc/rc.d/icadaemon")
            with open("/etc/rc.conf", "a") as rc_conf:
                rc_conf.write('ica_daemon_enable="YES"\n')

setup(name = 'icatest',
      description = 'ICA/LISA automation test library and tools',
      author = 'Fuzhou Chen',
      author_email = 'fuzhouch@microsoft.com',
      version = '0.1',
      url='http://ostc',
      packages = ['icatest'],
      data_files = [(shared_data_path, cfgs)],
      scripts = bins,
      cmdclass = dict(install = daemon_setup))
