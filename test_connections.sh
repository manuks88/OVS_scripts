#!/bin/bash

ovs-ofctl del-flows br0

port1="15000"
for i in {1..256}
do
{
	ovs-ofctl add-flow br0 dl_type=0x800,in_port=2,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=$port1,action=output:1
	port1=$(( port1+1 ))
}
done

port2="25000"
for i in {1..256}
do
{
	ovs-ofctl add-flow br0 dl_type=0x800,in_port=1,nw_proto=6,nw_src=10.1.1.66,nw_dst=10.1.1.58,tp_src=$port2,action=output:2
	port2=$(( port2+1 ))
}
done
