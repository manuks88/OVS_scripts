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
#       hit_count=$(cxgbtool enp7s0f4 filter show|grep -i switch|grep -o '[0-9][0-9]*'| awk -F ' ' '{print $2}')
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
                sleep 12
        }
        else
        {
                echo -e "${RED}Filters are _NOT_ getting hit.${end}"
                exit 1
        }
        fi
}

#Tos wildcard
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
	echo -e "${heading}${WHITE}Wildcard TOS : $i${end}"
	ovs-ofctl del-flows br0
	ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_tos=$i,action=output:1
	ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 --tos $i &> /dev/null" &
	check_hit
}
#Tos exact match
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
	echo -e "${heading}${WHITE}Exact TOS : $i${end}"
	ovs-ofctl del-flows br0
	ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_tos=$i,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,action=output:1
	ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 --tos $i &> /dev/null" &
	check_hit
}
#Tos wildcard with frag = first
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}Wildcard TOS first frag : $i${end}"
        ovs-ofctl del-flows br0
        ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_tos=$i,ip_frag=first,action=output:1
        ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 --tos $i --mf &> /dev/null" &
        check_hit
}
#Tos wildcard with frag = no
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}Wildcard TOS no frag : $i${end}"
        ovs-ofctl del-flows br0
        ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_tos=$i,ip_frag=no,action=output:1
        ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 --tos $i --df &> /dev/null" &
        check_hit
}
##Tos exact match with frag = first
#for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
#{
#        echo -e "${heading}${WHITE}Exact TOS first frag : $i${end}"
#        ovs-ofctl del-flows br0
#        ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_tos=$i,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,ip_frag=first,action=output:1
#        ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 --tos $i --mf &> /dev/null" &
#        check_hit
#}
#Tos exact match with frag = no
for i in 0 32 40 56 72 88 96 112 136 144 152 160 184 192
{
        echo -e "${heading}${WHITE}Exact TOS no frag : $i${end}"
        ovs-ofctl del-flows br0
        ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,nw_tos=$i,nw_proto=6,nw_src=10.1.1.58,nw_dst=10.1.1.66,tp_src=15000,tp_dst=15000,ip_frag=no,action=output:1
        ssh ironhide "nping --tcp -S 10.1.1.58 --dest-ip 10.1.1.66 --dest-port 15000 --source-port 15000 --dest-mac 00:07:43:29:0f:d0 --source-mac 00:07:43:29:05:78 -c 3000 --rate 1000 --tos $i --df &> /dev/null" &
        check_hit
}
