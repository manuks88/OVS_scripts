#!/bin/bash

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

ssh duke1 "killall -g nping -e enp2s0f4d1" &> /dev/null
ssh heather "killall -g nping -e enp2s0f4d1" &> /dev/null

function check_hit
{
	/root/iproute2/tc/tc -s filter show dev ens2f4 ingress
	tcpdump -i ens2f4 -c 100 -w int0.pcap &> /dev/null &
	port0_dump=`echo $!`
	tcpdump -i ens2f4d1 -c 100 -w int1.pcap &> /dev/null &
	port1_dump=`echo $!`
	sleep 2
	kill -9 $port0_dump
	kill -9 $port1_dump
        int0_pack=$(tcpdump -r int0.pcap | wc -l)
        int1_pack=$(tcpdump -r int1.pcap | wc -l)
	if [[ $int0_pack -lt 10 && $int1_pack -lt 10 ]]
	then
	{
		/root/iproute2/tc/tc -s filter show dev ens2f4 ingress|grep -i sent|tr -d '\011'|awk -F 'bytes' '{print $(NF-1)}'
	        echo -e "${GREEN}No packets in tcpdump.${end}"
	}
	else
	{
		/root/iproute2/tc/tc -s filter show dev ens2f4 ingress|grep -i sent|tr -d '\011'|awk -F 'bytes' '{print $(NF-1)}'
		echo -e "${RED}Filters are _NOT_ getting hit.${end}"
                exit 1
        }
        fi
	sleep 3
}

#Tos WildCard
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}Wildcard TOS : $i${end}"
        /root/iproute2/tc/tc -s filter del dev ens2f4 ingress
	if [[ $i != "0" ]]
	then
	{
		tos_val="0x"
		tos_val+=`printf "%x\n" $i`
	}
	else
	{
		tos_val="0x0"
	}
	fi
	echo $tos_val
        /root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw ip_proto tcp ip_tos $tos_val action mirred egress redirect dev ens2f4d1
	ssh duke1 "nping -e enp2s0f4d1 --tcp -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 --tos $i &> /dev/null" &
	sleep 1
	check_hit
}

#Tos ExactMatch
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}ExactMatch TOS : $i${end}"
        /root/iproute2/tc/tc -s filter del dev ens2f4 ingress
	if [[ $i != "0" ]]
	then
	{
		tos_val="0x"
		tos_val+=`echo "obase=16; $i" | bc`
	}
	else
	{
		tos_val="0x0"
	}
	fi
	echo $tos_val
        /root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw src_ip 2000::121 dst_ip 2000::233 ip_proto tcp src_port 15000 dst_port 15000 ip_tos $tos_val action mirred egress redirect dev ens2f4d1
	ssh duke1 "nping -e enp2s0f4d1 --tcp -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 --tos $i &> /dev/null" &
	sleep 1
	check_hit
}

#Tos WildCard + Frag=Yes
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}Wildcard + Frag TOS : $i${end}"
        /root/iproute2/tc/tc -s filter del dev ens2f4 ingress
	if [[ $i != "0" ]]
	then
	{
		tos_val="0x"
		tos_val+=`printf "%x\n" $i`
	}
	else
	{
		tos_val="0x0"
	}
	fi
	echo $tos_val
        /root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw ip_proto tcp ip_tos $tos_val ip_flags frag action mirred egress redirect dev ens2f4d1
	ssh duke1 "nping -e enp2s0f4d1 --tcp -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 --tos $i --mf &> /dev/null" &
	sleep 1
	check_hit
}

#Tos WildCard + Frag=No
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}Wildcard + No Frag TOS : $i${end}"
        /root/iproute2/tc/tc -s filter del dev ens2f4 ingress
	if [[ $i != "0" ]]
	then
	{
		tos_val="0x"
		tos_val+=`printf "%x\n" $i`
	}
	else
	{
		tos_val="0x0"
	}
	fi
	echo $tos_val
        /root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw ip_proto tcp ip_tos $tos_val ip_flags nofrag action mirred egress redirect dev ens2f4d1
	ssh duke1 "nping -e enp2s0f4d1 --tcp -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 --tos $i --df &> /dev/null" &
	sleep 1
	check_hit
}

#Tos ExactMatch + Frag=Yes , this combo does not work. Even with SW it does not work.

#Tos ExactMatch + Frag=No
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}ExactMatch + NoFrag TOS : $i${end}"
        /root/iproute2/tc/tc -s filter del dev ens2f4 ingress
	if [[ $i != "0" ]]
	then
	{
		tos_val="0x"
		tos_val+=`echo "obase=16; $i" | bc`
	}
	else
	{
		tos_val="0x0"
	}
	fi
	echo $tos_val
        /root/iproute2/tc/tc filter add dev ens2f4 parent ffff: protocol ipv4 pref 5 flower skip_sw src_ip 2000::121 dst_ip 2000::233 ip_proto tcp src_port 15000 dst_port 15000 ip_tos $tos_val ip_flags nofrag action mirred egress redirect dev ens2f4d1
	ssh duke1 "nping -e enp2s0f4d1 --tcp -S 2000::121 --dest-ip 2000::233 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:3c:b0:50 --source-mac 00:07:43:04:b2:c8 -c 3000 --rate 1000 --tos $i --df &> /dev/null" &
	sleep 1
	check_hit
}
