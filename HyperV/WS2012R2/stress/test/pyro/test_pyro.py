import Pyro4

import paramiko
import time

host_name = "10.172.7.148"
name_server = "10.172.7.137"

# push server.py to remote host
def push_server():

    s = paramiko.client.SSHClient()
    s.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())
    s.connect(host_name, 22, username='root', password='1*admin')
    
    stdin, stdout, stderr = s.exec_command('uname -a')

    print stdout.readlines()

    sftp = s.open_sftp()
    sftp.put('server.py', '/root/server.py')
    sftp.put('hostip.py', '/root/hostip.py')

    return s

def call_remote_func():
    name = "zlike"
    ns = Pyro4.locateNS(host=name_server)
    uri = ns.lookup("example.greeting")
    greeting_maker=Pyro4.Proxy(uri)
    print greeting_maker.get_fortune(name)

def start_name_server():
    s = paramiko.client.SSHClient()
    s.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())
    s.connect(name_server, 22, username='root', password='1*admin')
    
    stdin, stdout, stderr = s.exec_command('pyro4-ns -n %s' % name_server)
    
if __name__=='__main__':
    # we're running as root

    start_name_server()

    ssh_client = push_server()
    ssh_client.exec_command('killall -9 python2.7')
    stdin, stdout, stderr = ssh_client.exec_command('python /root/server.py %s %s' % (host_name, name_server))

    time.sleep(1)

    call_remote_func()
    ssh_client.exec_command('killall -9 python2.7')
