#!/bin/bash

ifconfig enp7s0f4d1 10.1.1.56/24

ovs-appctl exit
for i in {1..5}
{
	pkill -9 ovs
}
rm -rf /usr/local/etc/ovs-vswitchd.conf
rm -rf /usr/local/var/run/openvswitch/db.sock
rm -rf /usr/local/etc/openvswitch/conf.db
touch /usr/local/etc/ovs-vswitchd.conf
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /root/chelsio_ovs_2.7/openvswitch-2.7.0/vswitchd/vswitch.ovsschema
ovsdb-server /usr/local/etc/openvswitch/conf.db --remote=punix:/usr/local/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert --pidfile --detach --log-file
ovs-vsctl --no-wait init
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock
ovs-vswitchd --pidfile --detach
sleep 2
ovs-vsctl add-br br0
sleep 2
ifconfig br0 up
ovs-vsctl add-port br0 enp7s0f4
sleep 5
ovs-vsctl add-port br0 enp7s0f4d1 -- set interface enp7s0f4d1 type=vxlan options:local_ip=10.1.1.56 options:remote_ip=10.1.1.58 options:key=flow
sleep 2
ifconfig br0 192.168.0.56/24

ethtool -K enp7s0f4d1 gro off
ethtool -K br0 gro off
ethtool -K vxlan_sys_4789 gro off
ovs-vsctl show
