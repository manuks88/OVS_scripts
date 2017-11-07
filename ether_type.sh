#!/bin/bash

#Color
off='\033[0m'
error='\e[0;31m'
pass='\033[0;32m'
heading='\033[1;33m'
debug='\033[0;36m'

RED="\x1B[31m"
GREEN="\x1B[01;92m"
WHITE="\033[1;35m"
end="\x1B[0m"

ssh ironhide "killall -g nping" &> /dev/null
ssh bulkhead "killall -g nping" &> /dev/null

function check_hit
{
	sleep 2
	ovs-appctl dpctl/dump-flows
	cxgbtool enp7s0f4 filter show
	if [[ $(dmesg | grep -i "fatal") || $(dmesg | grep -i "error") ]]
	then
	{
		echo -e "Error seen."
		exit 1
	}
	fi
#	hit_count=$(cxgbtool enp7s0f4 filter show|grep -i switch|grep -o '[0-9][0-9]*'| awk -F ' ' '{print $2}')
	hit_count=$(cxgbtool enp7s0f4 filter show|grep -i switch|awk -F '/ffff' '{print $1}'| awk -F ' ' '{print $(NF-5)}')
	if [ $hit_count -ne 0 ]
	then
	{
		echo -e "${GREEN}Filter hit counts are incrementing.Count = $hit_count.${end}"
		tcpdump -i enp7s0f4 -c 100 -w int0.pcap &> /dev/null &
		tcpdump -i enp7s0f4d1 -c 100 -w int1.pcap &> /dev/null &
		sleep 2
		ovs-ofctl del-flows br0
		for i in `pgrep tcpdump`;do kill -9 $i;done
		int0_pack=$(tcpdump -r int0.pcap | wc -l)
		int1_pack=$(tcpdump -r int1.pcap | wc -l)
		if [[ $int0_pack -lt 10 && $int1_pack -lt 10 ]]
		then
		{
			echo -e "${GREEN}No packets in tcpdump.${end}"
		}
		fi
		sleep 10
	}
	else
	{
		echo -e "${RED}Filters are _NOT_ getting hit.${end}"
		exit 1
	}
	fi
}



#Dst MAC Match
echo -e "${heading}${WHITE}Test case 1${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,dl_dst=00:07:43:29:0f:d0,action=output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Dst MAC rewrite
echo -e "${heading}${WHITE}Test case 2${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,dl_dst=00:07:43:29:0f:d0,action=mod_dl_dst:00:07:43:28:E4:50,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Src MAC requite
echo -e "${heading}${WHITE}Test case 3${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,dl_src=00:07:43:29:05:78,action=mod_dl_src:00:07:43:28:E4:50,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv4
echo -e "${heading}${WHITE}Test case 4${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,action=output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv6
echo -e "${heading}${WHITE}Test case 5${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x86dd,action=output:1
ssh ironhide "nping -6 --tcp --source-ip 2000::58 --dest-ip 2000::66 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 -e enp7s0f4d1 &> /dev/null" &
check_hit

#Match based on IP Protocol : ARP : ARP_Type:ARP
echo -e "${heading}${WHITE}Test case 6${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x806,action=output:1
ssh ironhide "nping --arp --arp-type ARP --arp-sender-mac 00:07:43:29:05:78 --arp-sender-ip 10.1.1.58 --arp-target-mac 00:07:43:29:0f:d0 --arp-target-ip 10.1.1.66 -c 3000 --rate 1000 -S 10.1.1.58 --dest-ip 10.1.1.66 &> /dev/null"
check_hit

#Match based on IP Protocol : ARP : ARP_Type:ARP-reply
echo -e "${heading}${WHITE}Test case 7${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x806,action=output:1
ssh ironhide "nping --arp --arp-type ARP-reply --arp-sender-mac 00:07:43:29:05:78 --arp-sender-ip 10.1.1.58 --arp-target-mac 00:07:43:29:0f:d0 --arp-target-ip 10.1.1.66 -c 3000 --rate 1000 -S 10.1.1.58 --dest-ip 10.1.1.66 &> /dev/null"
check_hit

#Match based on IP Protocol : ARP : ARP_Type:RARP
echo -e "${heading}${WHITE}Test case 8${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x806,action=output:1
ssh ironhide "nping --arp --arp-type RARP --arp-sender-mac 00:07:43:29:05:78 --arp-sender-ip 10.1.1.58 --arp-target-mac 00:07:43:29:0f:d0 --arp-target-ip 10.1.1.66 -c 3000 --rate 1000 -S 10.1.1.58 --dest-ip 10.1.1.66 &> /dev/null"
check_hit

#Match based on IP Protocol : ARP : ARP_Type:RARP-reply
echo -e "${heading}${WHITE}Test case 9${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x806,action=output:1
ssh ironhide "nping --arp --arp-type RARP-reply --arp-sender-mac 00:07:43:29:05:78 --arp-sender-ip 10.1.1.58 --arp-target-mac 00:07:43:29:0f:d0 --arp-target-ip 10.1.1.66 -c 3000 --rate 1000 -S 10.1.1.58 --dest-ip 10.1.1.66 &> /dev/null"
check_hit

#Match IPv4 Src address, rewrite
echo -e "${heading}${WHITE}Test case 10${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_src=10.1.1.58,action=mod_nw_src:10.2.2.56,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 Dst address, rewrite
echo -e "${heading}${WHITE}Test case 11${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_dst=10.1.1.66,action=mod_nw_dst:10.2.2.56,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 Src port, rewrite
echo -e "${heading}${WHITE}Test case 12${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,tp_src=15000,action=mod_tp_src:25000,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 Dst port, rewrite
echo -e "${heading}${WHITE}Test case 13${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,tp_dst=15000,action=mod_tp_dst:25000,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP match, rewrite
echo -e "${heading}${WHITE}Test case 14${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,action=output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Src port, rewrite
echo -e "${heading}${WHITE}Test case 15${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,tp_src=15000,action=mod_tp_src=25000,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Dst port, rewrite
echo -e "${heading}${WHITE}Test case 16${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,tp_dst=15000,action=mod_tp_dst=25000,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Dst address, rewrite
echo -e "${heading}${WHITE}Test case 17${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,nw_dst=10.1.1.66,action=mod_nw_dst=10.2.2.66,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Src address, rewrite
echo -e "${heading}${WHITE}Test case 18${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,nw_src=10.1.1.58,action=mod_nw_src=10.2.2.58,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv4 Src NAT TCP
echo -e "${heading}${WHITE}Test case 19${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_nw_src=10.2.2.58,mod_tp_src=25000,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv4 Dst NAT TCP
echo -e "${heading}${WHITE}Test case 20${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_nw_dst=10.2.2.58,mod_tp_dst=25000,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv4 Frag TCP : first
echo -e "${heading}${WHITE}Test case 21${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,ip_frag=first,action=output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 --mf -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv4 Frag TCP : NO
echo -e "${heading}${WHITE}Test case 22${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,ip_frag=no,action=output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 --df -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv4 Frag UDP : first
echo -e "${heading}${WHITE}Test case 23${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,ip_frag=first,action=output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 --mf -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv4 Frag UDP : NO
echo -e "${heading}${WHITE}Test case 24${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,ip_frag=no,action=output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 --df -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv6 Src address rewrite
echo -e "${heading}${WHITE}Test case 25${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x86dd,action=set_field:2001::66-\>ipv6_src,output:1
ssh ironhide "nping --tcp -6 -S 2000::58 --dest-ip 2000::66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 -e enp7s0f4d1 &> /dev/null" &
check_hit

#IPv6 Dst address rewrite
echo -e "${heading}${WHITE}Test case 26${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x86dd,action=set_field:2001::66-\>ipv6_dst,output:1
ssh ironhide "nping --tcp -6 -S 2000::58 --dest-ip 2000::66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 -e enp7s0f4d1 &> /dev/null" &
check_hit

################################### Exact Match Rules ##########################################
#Dst MAC Match
echo -e "${heading}${WHITE}Test case 27${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,dl_dst=00:07:43:29:0f:d0,action=output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Dst MAC rewrite
echo -e "${heading}${WHITE}Test case 28${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,dl_dst=00:07:43:29:0f:d0,action=mod_dl_dst:00:07:43:28:E4:50,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Src MAC requite
echo -e "${heading}${WHITE}Test case 29${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,dl_src=00:07:43:29:05:78,action=mod_dl_src:00:07:43:28:E4:50,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv4
echo -e "${heading}${WHITE}Test case 30${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv6
echo -e "${heading}${WHITE}Test case 31${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x86dd,nw_proto=6,ipv6_src=2000::58,ipv6_dst=2000::66,tp_src=15000,tp_dst=15000,action=output:1
ssh ironhide "nping -6 --tcp --source-ip 2000::58 --dest-ip 2000::66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 -e enp7s0f4d1 &> /dev/null" &
check_hit

#Match IPv4 Src address, rewrite
echo -e "${heading}${WHITE}Test case 31${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_nw_src:10.2.2.56,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 Dst address, rewrite
echo -e "${heading}${WHITE}Test case 33${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_nw_dst:10.2.2.56,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 Src port, rewrite
echo -e "${heading}${WHITE}Test case 34${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_tp_src:25000,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 Dst port, rewrite
echo -e "${heading}${WHITE}Test case 35${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_tp_dst:25000,output:1
ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP match, rewrite
echo -e "${heading}${WHITE}Test case 36${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Src port, rewrite
echo -e "${heading}${WHITE}Test case 37${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_tp_src=25000,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Dst port, rewrite
echo -e "${heading}${WHITE}Test case 38${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_tp_dst=25000,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Dst address, rewrite
echo -e "${heading}${WHITE}Test case 39${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_nw_dst=10.2.2.66,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#Match IPv4 UDP Src address, rewrite
echo -e "${heading}${WHITE}Test case 40${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_proto=17,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=mod_nw_src=10.2.2.58,output:1
ssh ironhide "nping --udp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-mac 00:07:43:29:0f:d0 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 &> /dev/null"
check_hit

#IPv6 Src address rewrite
echo -e "${heading}${WHITE}Test case 41${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x86dd,nw_proto=6,ipv6_src=2000::58,ipv6_dst=2000::66,tp_src=15000,tp_dst=15000,action=set_field:3001::66-\>ipv6_src,output:1
ssh ironhide "nping --tcp -6 -S 2000::58 --dest-ip 2000::66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 -e enp7s0f4d1 &> /dev/null" &
check_hit

#IPv6 Dst address rewrite
echo -e "${heading}${WHITE}Test case 42${end}"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x86dd,nw_proto=6,ipv6_src=2000::58,ipv6_dst=2000::66,tp_src=15000,tp_dst=15000,action=set_field:3001::66-\>ipv6_dst,output:1
ssh ironhide "nping --tcp -6 -S 2000::58 --dest-ip 2000::66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 -e enp7s0f4d1 &> /dev/null" &
check_hit
