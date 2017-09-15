#!/usr/bin/python

import sys
import os
import time
import shutil


def build_sw(sw_path,ovs_path):
	swpath = sw_path
	config_path = swpath + "dev/T4/firmware/t6-config-hashfilter.txt"
	swpath = swpath + "linux_t4_build"
	os.chdir(swpath)
	print (os.getcwd())
	#Build driver
	toolpath = sw_path + "linux_tools/cxgbtool"
	os.chdir(toolpath)
	print (os.getcwd())
	#Build cxgbtool
	ovspath = ovs_path
	os.chdir(ovspath)
	print (os.getcwd())
	#Build ovs
	#Copy hash filter Config
	shutil.copy(config_path,"/lib/firmware/cxgb4/t6-config.txt")


def 

build_sw("/root/sw/","/root/chelsio_ovs_2.7/openvswitch-2.7.0/")
