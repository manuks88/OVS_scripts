#!/bin/bash

/root/scripts/unload.sh 2> /dev/null
dmesg -c > /dev/null

modprobe cxgb4 use_ddr_filters=1
modprobe openvswitch
ifconfig enp5s0f4 0 down
ifconfig enp5s0f4d1 0 down
ifconfig enp6s0f4 0 down
ifconfig enp6s0f4d1 0 down
ifconfig enp7s0f4 up promisc  
ifconfig enp7s0f4d1 up promisc
