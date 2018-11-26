Configuring Test Target Machine
=========================

The test code works for both VM and bare-metal machines. If you're running against a VM, please place this code on a Windows machine (since it will try to use Hyper-V WMI interfaces.) that have an active network connection to the Hyper-V host.

The following software packages should be installed on the target machine (either VM or bare-metal):

* `open-ssh`
* `python`

Next, you'll need to allow `root` SSH login. If you're using `openssh`, which is the default SSH server on most Linux/FreeBSD builds, please search for `PermitRootLogin` in `sshd_config` (located in `/etc/ssh/`) and set it to "yes":

```
PermitRootLogin yes
```

Make sure the VM/bare-metal machines have CorpNet connection, and this test code can reach the machines using SSH.  

Configuring the Driver Machine
========================

We use a dedicated *driver machine* to run the test code. This driver machine will remotely manage all hosts and VMs via network. 

Please find a Windows machine, check out this code to a comforable location, and on an elevated command prompt, run the `setup-driver.cmd` script in `deploy` folder to configure the driver machine automatically.

Editing the machine pool database
==========================

The machine pool database is used to store Hyper-V hosts, VMs and bare-metal machine configurations so that the test code can allocate them automatically for different testing purpose. 

The database is stored in `pool\machines` as a SQLite database. To edit it, go to [this link](http://sqlitebrowser.org) and download SQLiteBrowser to open the database file.

To add some new machines, first create a new "pool" in table `pool`, give it a name, and enter the name of a Pyro4 nameserver. Below are two nameservers predefined that you can use directly, based on your geographical location:

* `ns1`, located in Shanghai
* `ns2`, located in Redmond

Then, add the Hyper-V hosts that host the VM in table `hosts`. The mandatory fields are `pool` and `name`.

Finally, add the VMs in table `vms`. If you're adding a bare-metal machine, use the same name in `name` and `hostname` to inform the framework that this is actually a bare-metal machine, other than a VM.

Below are the explanation of the fields for a VM:

* `pool` - The name of the pool.
* `name` - VM name, as seen in Hyper-V Manager.
* `hostname` - NETBIOS name of the Hyper-V host that hosts this VM.
* `ipaddr` - The IPv4 address that will be used in Networking tests. NOTE that this is NOT the control IP that should be connected to the CorpNet.
* `version` - Version of the VM OS.
* `cpu` - CPU core count.
* `mem` - Physical memory size.
* `desc` - Reserved.
* `ipaddr6` - IPv6 address used in Networking tests.
* `username` - Should be `root`, used to connect using SSH.
* `password` - SSH password for user as specified in `username`.
* `ctrl_ip` - The IP address that the framework will use to SSH to the VM. This should be an address in CorpNet. If left empty, the framework will try to get it using KVP channel.
* `perf_drive` - A drive name that will run IOZone. Usually this will be the name of your second hard drive in the VM. In FreeBSD, this could be `da1`, and in Linux, this could be `sdb`.

After filling all these info, hit "Write Changes" in the menu bar of SQLiteBrowser, and close the application.

Running Performance Tests
=====================

### IOZone Tests

Since IOZone can run on a single machine, create a machine pool with **only one VM** in the pool in the database, and configure the corresponding VM with the following configuration:

* 4 vCPU
* 4GB RAM
* 1 IDE drive that has the OS installed.
* 1 SCSI drive. Please place the VHD on a SSD hard drive, make it *fixed* size, and make sure it has a capacity of no less than *40GB*.

Next, open a `cmd` window with Administrator privilege on your machine where this test code is checked out (the driver machine), navigate to the `stress` folder (this folder), and type the following command:

```
python stress.py -c PerfIOZoneTest -m oneshot -l <name_of_your_pool>
```

Logs will be placed under `\root` in the VM with names like `iozone-0-p14k.log` and `iozonep14k.xls`, make sure you collect all of them.

### IPerf Tests

IPerf test and other networking tests requires **two machines** to perform a server-client transport scenario. Thus please add two VMs in your newly created pool in the database.

Along with 4 vCPU and 4GB of RAM, it is better to have *two* NICs for each VM, one connected to CorpNet so the test code can remotely control the VM, and another connected to a dedicated switch/adapter that will deliver actual networking test data. Also remember to specify `ipaddr` and `ipaddr6` in the database with the dedicated IP addresses for the NIC.

Finally in the elevated `cmd` window, type the following command:

```
python stress.py -c PerfIPerfv4Test,PerfIPerfv6Test -m oneshot -l <name_of_your_pool>
```

Running Stress Tests
================

Run `storvsc_LargeFileCopy` once immediately:

```
python stress.py -c StorVSCLargeFileCopyTest -m oneshot
```

Run FeatureTest every day for 7 days:

```
python stress.py -c FeatureTest -m repeat -i 86400 -d 604800
```

Run `utils_*` in a 15/15 minuite cycle for 1 day

```
python stress.py -c UtilsHeartBeatTest,UtilsKVPTest,UtilsTimeSyncTest -m repeat -i 60 -a 900 -b 900 -p vm_cycle -d 3600 -l kvp
```

