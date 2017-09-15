#!/bin/bash

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
sleep 2
ovs-vsctl add-port br0 enp7s0f4d1
sleep 2
ovs-vsctl show
