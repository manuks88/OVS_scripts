#!/bin/bash

echo -e "Delete Flows..."
ovs-ofctl del-flows br0
ovs-ofctl del-flows br1
sleep 1
echo -e "Delete interfaces..."
ovs-vsctl del-port br0 enp7s0f4d1 -- del-port br0 enp7s0f4 -- del-port br0 enp7s0f4d1.8
ovs-vsctl del-port br1 enp7s0f4d1 -- del-port br1 enp7s0f4 -- del-port br1 enp7s0f4d1.8
sleep 1
echo -e "Delete Bridge..."
ovs-vsctl del-br br0
ovs-vsctl del-br br1
sleep 2
echo -e "Stopping service..."
for i in {1..5}
{
        pkill -9 ovs
        sleep 1.5
}
sleep 2
echo -e "Exiting service..."
ovs-appctl exit

