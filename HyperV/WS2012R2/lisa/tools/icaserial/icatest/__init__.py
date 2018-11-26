#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
The icatest module provides all supporting libraries (classes and
functions) used by ICA automation test scripts.
"""
import icatest.daemon
import icatest.errors

import os
import subprocess

# Now we determine platforms
try:
    cmdline = [ "/usr/bin/env", "uname", "-s" ]
    task = subprocess.Popen(cmdline, \
                            stdout = subprocess.PIPE, \
                            stderr = subprocess.PIPE)
    task_return_code = task.wait()
    task_output = task.stdout.read().decode('utf-8')
    task_error  = task.stderr.read().decode('utf-8')
    osname = task_output.split("\n")[0].lower()
except OSError:
    msg = "ERROR: Can't find /usr/bin/env or uname, cannot detect OS"
    code = icatest.errors.ERROR_BAD_ENVIRONMENT
    icatest.daemon.write_log(icatest.daemon.STDERR_FD, code, msg)
    raise ICAException(code, msg)

if osname == "freebsd":
    import icatest.freebsd as platform_lib
elif osname == "linux":
    import icatest.linux as platform_lib
else:
    msg = "Unsupported OS from uname -s: %s" % osname
    code = icatest.errors.ERROR_BAD_ENVIRONMENT
    icatest.daemon.write_log(icatest.daemon.STDERR_FD, None, code, msg)
    raise ICAException(code, msg)
