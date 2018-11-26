#!/usr/bin/env python

import sys

sys.path.append("../hypervlib")
import hyperv

sys.path.append("../runner")
import net_utils

print hyperv.get_kvp_intrinsic_exchange_items('FreeBSD10-TEST-1')
print net_utils.get_ip_for_vm('FreeBSD10-TEST-1', '.')

