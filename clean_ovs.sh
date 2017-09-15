#!/bin/bash

if [ $# -ne 1 ]
then
{
	echo -e "Enter repo location."
	exit 1
}
fi

cd $1
make uninstall && make clean && make distclean
cd
module_ver=$(modinfo openvswitch|grep -i "version:"|head -1|awk -F ' ' '{print $2}')
modinfo openvswitch &> /dev/null
if [ $? -eq 0 ]
then
{
	if [ $module_ver == "2.7.0" ]
	then
	{
		module_loc=$(modinfo openvswitch|head -1|awk -F ' ' '{print $2}')
		rm -rf $module_loc
		echo "Module removed"
	}
	fi
}
fi
