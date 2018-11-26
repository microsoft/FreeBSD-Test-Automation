import sys

sys.path.append('../runner/')
import runner

class TestDeco:
    @runner.init_vm
    def init_vm(self):
        pass
