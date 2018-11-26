import sys

sys.path.append("../hypervlib")

import hyperv

hyperv.revert_to_snapshot("ICABase", "FreeBSD10_X64")
