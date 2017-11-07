#!/bin/bash

if [ $# -ne 2 ]
then
{
	echo -e "Enter driver and ovs repo."
	exit 1
}
fi

cd $1
hg pull -u && hg update -C
cd linux_t4_build
make nic install
cd ../linux_tools/cxgbtool/
make install
cd
#yes | cp $1/dev/T4/firmware/t6-config-hashfilter.txt /lib/firmware/cxgb4/t6-config.txt
#yes | cp $1/dev/T4/firmware/t5-config-hashfilter.txt /lib/firmware/cxgb4/t5-config.txt

cd $2
hg pull -u && hg update -C
export CXGB_SRC=$1/linux_t4_build
./boot.sh
./configure --with-linux=/lib/modules/`uname -r`/build/
make -j3 && make modules_install install
cd
