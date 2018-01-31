#!/bin/bash


#Color
off='\033[0m'
error='\e[0;31m'
pass='\033[0;32m'
heading='\033[1;33m'
debug='\033[0;36m'

RED="\x1B[31m"
GREEN="\x1B[01;92m"
PURPLE="\033[1;35m"
WHITE="\033[1;37m"
end="\x1B[0m"

ssh duke1 "killall -g nping" &> /dev/null
ssh heather "killall -g nping" &> /dev/null

function check_hit
{
	sleep 1
        /root/iproute2/tc/tc -s filter show dev ens2f4 ingress
        tcpdump -i ens2f4 -c 100 -w int0.pcap &> /dev/null &
        tcpdump -i ens2f4d1 -c 100 -w int1.pcap &> /dev/null &
        sleep 2
        for i in `pgrep tcpdump`;do kill -9 $i;done
        int0_pack=$(tcpdump -r int0.pcap | wc -l)
        int1_pack=$(tcpdump -r int1.pcap | wc -l)
        if [[ $int0_pack -lt 10 && $int1_pack -lt 10 ]]
        then
        {
                echo -e "${GREEN}No packets in tcpdump.${end}"
        }
        else
        {
                echo -e "${RED}Filters are _NOT_ getting hit.${end}"
                exit 1
        }
        fi
}

#Create VLAN interface on peer
ssh duke1 "ip link delete enp2s0f4d1.60"
ssh duke1 "ip link add link enp2s0f4d1 name enp2s0f4d1.60 type vlan id 60"
ssh duke1 "ifconfig enp2s0f4d1.60 192.168.0.121/24 up"
ssh duke1 "arp -s 192.168.0.233 00:07:43:3c:b0:50"

#VLAN Match, Wildcard
echo -e "${heading}${WHITE}Wildcard VLAN match ${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_ethtype 802.1q vlan_id 60 action mirred egress redirect dev ens2f4d1
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#VLAN Pop, Wildcard, Works with vlan filter combo
echo -e "${heading}${WHITE}Wildcard VLAN Pop ${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw action mirred egress redirect dev ens2f4d1 action vlan pop
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#VLAN Modify, Wildcard, Works with vlan filter combo
echo -e "${heading}${WHITE}Wildcard VLAN Modify ${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw  action mirred egress redirect dev ens2f4d1 action vlan modify id 80
ssh heather "tcpdump -vv -e -i enp2s0f4 \( vlan 80 \) -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#VLAN Priority,Match 0 - 7, Works without vlan in filter combo
echo -e "${heading}${WHITE}Wildcard VLAN Prio Match ${end}"
echo -e "${GREEN}Priority 0${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 0 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:0"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${GREEN}Priority 1${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 1 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:1"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${GREEN}Priority 2${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 2 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:2"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${GREEN}Priority 3${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 3 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:3"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${GREEN}Priority 4${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 4 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:4"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${GREEN}Priority 5${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 5 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:5"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${GREEN}Priority 6${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 6 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:6"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${GREEN}Priority 7${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 7 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:7"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

echo -e "${heading}${WHITE}Priority Modify to 7${end}"
/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 0 action vlan modify id 60 priority 7 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:0"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 1 action vlan modify id 60 priority 7 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:1"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 2 action vlan modify id 60 priority 7 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:2"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 3 action vlan modify id 60 priority 7 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:3"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 4 action vlan modify id 60 priority 7 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:4"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 6 action vlan modify id 60 priority 7 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:6"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol 802.1q pref 5 flower skip_sw vlan_prio 7 action vlan modify id 60 priority 2 action mirred egress redirect dev ens2f4d1
ssh duke1 "ip link set enp2s0f4d1.60 type vlan egress 0:7"
ssh heather "tcpdump -vv -e -i enp2s0f4 -c 2" &
ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
check_hit

##VLAN Pop, ExactMatch
#echo -e "${heading}${WHITE}ExactMatch VLAN Pop ${end}"
#/root/iproute2/tc/tc -s filter del dev ens2f4 ingress
#/root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw  src_ip 192.16.0.121 dst_ip 192.168.0.233 ip_proto tcp src_port 15000 dst_port 15000 action mirred egress redirect dev ens2f4d1 action vlan pop
#ssh duke1 "nping --tcp -S 192.168.0.121 --dest-ip 192.168.0.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 &> /dev/null" &
#check_hit
