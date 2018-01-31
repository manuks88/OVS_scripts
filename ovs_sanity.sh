#!/bin/bash

rm -rf sanity_ovs.log
dmesg -c > /dev/null

#Color
off='\033[0m'
error='\e[0;31m'
pass='\033[0;32m'
heading='\033[1;33m'
debug='\033[0;36m'

RED="\x1B[31m"
GREEN="\x1B[01;92m"
WHITE="\033[1;37m"
PURPLE="\033[1;35m"
end="\x1B[0m"

ssh duke1 "killall -g nping" &> /dev/null
ssh heather "killall -g nping" &> /dev/null

function check_hit
{
	sleep 2
        ovs-appctl dpctl/dump-flows
        if [[ $(dmesg | grep -i "fatal") || $(dmesg | grep -i "error") || $(dmesg | grep -i "Unsupported action") ]]
        then
        {
		dmesg >> sanity_ovs.log
                echo -e "${RED}Error seen.${end}" | tee -a sanity_ovs.log
        }
        fi
#	filter_count=$(cxgbtool ens2f4 filter show|grep -i switch|awk -F '/ffff' '{print $1}'| awk -F ' ' '{print $(NF-5)}')
#	filter_count=$(cxgbtool ens2f4 filter show | grep -i switch | tr -s " " "\n" | grep -B 4 "ffff"|sed -n '1p')
	hit_count=$(ovs-ofctl dump-flows br0 | tr "," "\n" | grep -i packet | cut -d "=" -f2)
	if [ $hit_count -ne 0 ]
#	if [[ "$hit_count" -ne "0" && "$filter_count" -ne "0" ]]
        then
        {
#		echo -e "${GREEN}OVS & filter hit counts are incrementing.Count = $hit_count,$filter_count.${end}"
		cxgbtool ens2f4 filter show | grep -i switch
		echo -e "${GREEN}OVS hit counts are incrementing.Count = $hit_count.${end}"
                tcpdump -i ens2f4 -c 100 -w int0.pcap &> /dev/null &
		port0_dump=`echo $!`
                tcpdump -i ens2f4d1 -c 100 -w int1.pcap &> /dev/null &
		port1_dump=`echo $!`
		sleep 2
                ovs-ofctl del-flows br0
		kill -9 $port0_dump
		kill -9 $port1_dump
                int0_pack=$(tcpdump -r int0.pcap | wc -l)
                int1_pack=$(tcpdump -r int1.pcap | wc -l)
                if [[ "$int0_pack" -lt "10" && "$int1_pack" -lt "10" ]]
                then
                {
                        echo -e "${GREEN}No packets in tcpdump\nPort0 : $int0_pack Port1 : $int1_pack.${end}"
                }
		else
		{
			echo -e "${RED}Packets are seen in tcpdump.${end}" | tee -a sanity_ovs.log
			echo -e "\n" >> sanity_ovs.log
		}
                fi
		sleep 14
		dmesg -c
		ssh duke1 "killall -g nping"
        }
        else
        {
                echo -e "${RED}Offload _NOT_ working.${end}" | tee -a sanity_ovs.log
		echo -e "\n" >> sanity_ovs.log
		ssh duke1 "killall -g nping" &> /dev/null
		exit 1
        }
        fi
	printf '=%.0s' {1..144}
	echo -e "\n"
	
}

#Dst MAC Match
echo -e "${heading}${WHITE}Test case 1,Dst MAC Match${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,dl_dst=00:07:43:3c:b0:50,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Dst MAC rewrite
echo -e "${heading}${WHITE}Test case 2,Dst MAC rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,dl_dst=00:07:43:3c:b0:50,action=mod_dl_dst:00:07:43:28:E4:50,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Src MAC rewrite
echo -e "${heading}${WHITE}Test case 3,Src MAC rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,dl_src=00:07:43:04:b2:c8,action=mod_dl_src:00:07:43:28:E4:50,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv4
echo -e "${heading}${WHITE}Test case 4,Match based on IP Protocol : IPv4${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv6
echo -e "${heading}${WHITE}Test case 5,Match based on IP Protocol : IPv6${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x86dd,action=output:2
ssh duke1 "nping -6 --tcp --source-ip 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 -e enp2s0f4d1 &> /dev/null" &
check_hit

#Match based on IP Protocol : ARP : ARP_Type:ARP
echo -e "${heading}${WHITE}Test case 6,Match based on IP Protocol : ARP : ARP_Type:ARP${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x806,action=output:2
ssh duke1 "nping --arp --arp-type ARP --arp-sender-mac 00:07:43:04:b2:c8 --arp-sender-ip 10.1.1.121 --arp-target-mac 00:07:43:3c:b0:50 --arp-target-ip 10.1.1.233 -c 5000 --rate 1000 -S 10.1.1.121 --dest-ip 10.1.1.233 &> /dev/null" &
check_hit

#Match based on IP Protocol : ARP : ARP_Type:ARP-reply
echo -e "${heading}${WHITE}Test case 7,Match based on IP Protocol : ARP : ARP_Type:ARP-reply${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x806,action=output:2
ssh duke1 "nping --arp --arp-type ARP-reply --arp-sender-mac 00:07:43:04:b2:c8 --arp-sender-ip 10.1.1.121 --arp-target-mac 00:07:43:3c:b0:50 --arp-target-ip 10.1.1.233 -c 5000 --rate 1000 -S 10.1.1.121 --dest-ip 10.1.1.233 &> /dev/null" &
check_hit

#Match based on IP Protocol : ARP : ARP_Type:RARP
echo -e "${heading}${WHITE}Test case 8,Match based on IP Protocol : ARP : ARP_Type:RARP${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x806,action=output:2
ssh duke1 "nping --arp --arp-type RARP --arp-sender-mac 00:07:43:04:b2:c8 --arp-sender-ip 10.1.1.121 --arp-target-mac 00:07:43:3c:b0:50 --arp-target-ip 10.1.1.233 -c 5000 --rate 1000 -S 10.1.1.121 --dest-ip 10.1.1.233 &> /dev/null" &
check_hit

#Match based on IP Protocol : ARP : ARP_Type:RARP-reply
echo -e "${heading}${WHITE}Test case 9,Match based on IP Protocol : ARP : ARP_Type:RARP-reply${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x806,action=output:2
ssh duke1 "nping --arp --arp-type RARP-reply --arp-sender-mac 00:07:43:04:b2:c8 --arp-sender-ip 10.1.1.121 --arp-target-mac 00:07:43:3c:b0:50 --arp-target-ip 10.1.1.233 -c 5000 --rate 1000 -S 10.1.1.121 --dest-ip 10.1.1.233 &> /dev/null" &
check_hit

#Match IPv4 Src address, rewrite
echo -e "${heading}${WHITE}Test case 10,Match IPv4, Src address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_src=10.1.1.121,action=mod_nw_src:10.2.2.121,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 Dst address, rewrite
echo -e "${heading}${WHITE}Test case 11,Match IPv4, Dst address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_dst=10.1.1.233,action=mod_nw_dst:10.2.2.121,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4, Src port rewrite
echo -e "${heading}${WHITE}Test case 12,Match IPv4, Src port rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,tp_src=15000,action=mod_tp_src:25000,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 ,Dst port rewrite
echo -e "${heading}${WHITE}Test case 13,Match IPv4,Dst port rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,tp_dst=15000,action=mod_tp_dst:25000,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP proto match
echo -e "${heading}${WHITE}Test case 14,Match IPv4 UDP proto match${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,action=output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Src port, rewrite
echo -e "${heading}${WHITE}Test case 15,Match IPv4 UDP, Src port rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,tp_src=15000,action=mod_tp_src=25000,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Dst port, rewrite
echo -e "${heading}${WHITE}Test case 16,Match IPv4 UDP, Dst port rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,tp_dst=15000,action=mod_tp_dst=25000,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Dst address, rewrite
echo -e "${heading}${WHITE}Test case 17,Match IPv4 UDP, Dst address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_dst=10.1.1.233,action=mod_nw_dst=10.2.2.66,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Src address, rewrite
echo -e "${heading}${WHITE}Test case 18,Match IPv4 UDP, Src address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_src=10.1.1.121,action=mod_nw_src=10.2.2.58,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#IPv4 Src NAT TCP
echo -e "${heading}${WHITE}Test case 19,IPv4 Src NAT TCP${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_nw_src=10.2.2.58,mod_tp_src=25000,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &

#IPv4 Dst NAT TCP
echo -e "${heading}${WHITE}Test case 20,IPv4 Dst NAT TCP${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_nw_dst=10.2.2.58,mod_tp_dst=25000,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#IPv4 Frag TCP : first
echo -e "${heading}${WHITE}Test case 21,IPv4 Frag TCP : first${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,ip_frag=first,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 --mf -c 5000 --rate 1000 &> /dev/null" &
check_hit

#IPv4 Frag TCP : NO
echo -e "${heading}${WHITE}Test case 22,IPv4 Frag TCP : NO${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,ip_frag=no,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 --df -c 5000 --rate 1000 &> /dev/null" &
check_hit

#IPv4 Frag UDP : first
echo -e "${heading}${WHITE}Test case 23,IPv4 Frag UDP : first${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,ip_frag=first,action=output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 --mf -c 5000 --rate 1000 &> /dev/null" &
check_hit

#IPv4 Frag UDP : NO
echo -e "${heading}${WHITE}Test case 24,IPv4 Frag UDP : NO${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,ip_frag=no,action=output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 --df -c 5000 --rate 1000 &> /dev/null" &
check_hit

#IPv6 Src address rewrite
echo -e "${heading}${WHITE}Test case 25,IPv6 Src address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x86dd,action=set_field:2001::66-\>ipv6_src,output:2
ssh duke1 "nping --tcp -6 -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 -e enp2s0f4d1 &> /dev/null" &
check_hit

#IPv6 Dst address rewrite
echo -e "${heading}${WHITE}Test case 26,IPv6 Dst address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x86dd,action=set_field:2001::66-\>ipv6_dst,output:2
ssh duke1 "nping --tcp -6 -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 -e enp2s0f4d1 &> /dev/null" &
check_hit

################################### Exact Match Rules ##########################################
#Dst MAC Match
echo -e "${heading}${WHITE}Test case 27,Dst MAC Match${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,dl_dst=00:07:43:3c:b0:50,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Dst MAC rewrite
echo -e "${heading}${WHITE}Test case 28,Dst MAC rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,dl_dst=00:07:43:3c:b0:50,action=mod_dl_dst:00:07:43:aa:bb:cc,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Src MAC rewrite
echo -e "${heading}${WHITE}Test case 29,Src MAC rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,dl_src=00:07:43:04:b2:c8,action=mod_dl_src:00:07:43:cc:aa:bb,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv4
echo -e "${heading}${WHITE}Test case 30,Match based on IP Protocol : IPv4${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0 
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match based on IP Protocol : IPv6
echo -e "${heading}${WHITE}Test case 31,Match based on IP Protocol : IPv6${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x86dd,nw_proto=6,ipv6_src=2000::121,ipv6_dst=2000::233,tp_src=15000,tp_dst=15000,action=output:2
ssh duke1 "nping -6 --tcp --source-ip 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 -e enp2s0f4d1 &> /dev/null" &
check_hit

#Match IPv4 Src address, rewrite
echo -e "${heading}${WHITE}Test case 32,Match IPv4 Src address, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_nw_src:10.2.2.121,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 Dst address, rewrite
echo -e "${heading}${WHITE}Test case 33,Match IPv4 Dst address, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_nw_dst:10.2.2.121,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 Src port, rewrite
echo -e "${heading}${WHITE}Test case 34,Match IPv4 Src port, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_tp_src:25000,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 Dst port, rewrite
echo -e "${heading}${WHITE}Test case 35,Match IPv4 Dst port, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_tp_dst:25000,output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP match, rewrite
echo -e "${heading}${WHITE}Test case 36,Match IPv4 UDP match, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Src port, rewrite
echo -e "${heading}${WHITE}Test case 37,Match IPv4 UDP Src port, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_tp_src=25000,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Dst port, rewrite
echo -e "${heading}${WHITE}Test case 38,Match IPv4 UDP Dst port, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_tp_dst=25000,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Dst address, rewrite
echo -e "${heading}${WHITE}Test case 39,Match IPv4 UDP Dst address, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_nw_dst=10.2.2.66,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Match IPv4 UDP Src address, rewrite
echo -e "${heading}${WHITE}Test case 40,Match IPv4 UDP Src address, rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,action=mod_nw_src=10.2.2.58,output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --dest-port 15000 --source-port 15000 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#IPv6 Src address rewrite
echo -e "${heading}${WHITE}Test case 41,IPv6 Src address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x86dd,nw_proto=6,ipv6_src=2000::121,ipv6_dst=2000::233,tp_src=15000,tp_dst=15000,action=set_field:3001::66-\>ipv6_src,output:2
ssh duke1 "nping --tcp -6 -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 -e enp2s0f4d1 &> /dev/null" &
check_hit

#IPv6 Dst address rewrite
echo -e "${heading}${WHITE}Test case 42,IPv6 Dst address rewrite${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x86dd,nw_proto=6,ipv6_src=2000::121,ipv6_dst=2000::233,tp_src=15000,tp_dst=15000,action=set_field:3001::66-\>ipv6_dst,output:2
ssh duke1 "nping --tcp -6 -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 -e enp2s0f4d1 &> /dev/null" &
check_hit

#Src MAC Match
echo -e "${heading}${WHITE}Test case 43,Src MAC Match${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,dl_src=00:07:43:04:b2:c8,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Src MAC Match,Exact Match
echo -e "${heading}${WHITE}Test case 44,Src MAC Match Exact Match${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=6,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,dl_src=00:07:43:04:b2:c8,action=output:2
ssh duke1 "nping --tcp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Src MAC Match,UDP
echo -e "${heading}${WHITE}Test case 45,Src MAC Match UDP${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,dl_src=00:07:43:04:b2:c8,action=output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit

#Src MAC Match,Exact UDP Match
echo -e "${heading}${WHITE}Test case 46,Src MAC Match Exact Match UDP${end}" | tee -a sanity_ovs.log
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,nw_proto=17,nw_src=10.1.1.121,nw_dst=10.1.1.233,tp_src=15000,tp_dst=15000,dl_src=00:07:43:04:b2:c8,action=output:2
ssh duke1 "nping --udp -S 10.1.1.121 --dest-ip 10.1.1.233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 5000 --rate 1000 &> /dev/null" &
check_hit
