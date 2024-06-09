#!/bin/bash

if wget -q -O /dev/null laserjet ; then
	exit 0
else
	sleep 1
	if wget -q -O /dev/null laserjet ; then
		exit 0
	else
		sleep 1
		if wget -q -O /dev/null laserjet ; then
			exit 0
		else
			exit 1
		fi
	fi
fi
