#!/bin/bash

# $1: IP address of nginx server
# $2: Port of server

echo $1 > /tmp/vrss.log
echo $2 >> /tmp/vrss.log

echo "Repeat 128 times: curl  -o /dev/null  http://$1:$2"  >> /tmp/vrss.log
for ((i=0; i<128; i++))
do
    curl  -o /dev/null  http://$1:$2
    sleep 1
done

