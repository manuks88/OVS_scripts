#!/bin/bash

if [[ $(dmesg | grep -i "parity") || $(dmesg | grep -i "chel") ]]
then
{
	echo "there"
}
else
{
	echo "no"
}
fi
