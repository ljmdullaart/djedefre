#!/bin/bash

if ssh nameserver ps -ef | grep -q 'dhcpd' ; then
	if ssh nameserver ps -ef | grep -q 'named' ; then
		exit 0
	else
		exit 1
	fi
elif ssh nameserver ps -ef | grep -q 'dhcpd' ; then
	if ssh nameserver ps -ef | grep -q 'named' ; then
		exit 0
	else
		exit 1
	fi
else
	exit 1
fi
