#!/bin/bash

python pool.py init
python pool.py add -p stress
python pool.py add -p stress --host test-host-1 -a 192.168.0.1 -v Linux-3.12 --cpu 4 --mem 16
python pool.py add -p stress --vm test-vm-2 -a 192.168.0.2 -v Windows --cpu 1 --mem 2 --host test-host-1
