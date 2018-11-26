# saved as greeting.py
import Pyro4
import sys

class GreetingMaker(object):
    def get_fortune(self, name):
        return "Hello, {0}. Here is your fortune message:\n" \
               "Tomorrow's lucky number is 12345678.".format(name)

host_ip = sys.argv[1]
name_server = sys.argv[2]

greeting_maker=GreetingMaker()

# to run as a remote server, set PYRO_HOST env variable, or:
#import hostip
Pyro4.config.HOST = host_ip

daemon=Pyro4.Daemon()                 # make a Pyro daemon
ns=Pyro4.locateNS(host=name_server)                   # find the name server
uri=daemon.register(greeting_maker)   # register the greeting object as a Pyro object
ns.register("example.greeting", uri)  # register the object with a name in the name server

print "Ready, uri = ", uri
daemon.requestLoop()                  # start the event loop of the server to wait for calls
