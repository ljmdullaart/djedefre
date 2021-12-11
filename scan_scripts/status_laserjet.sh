#!/bin/bash



if wget -qO /dev/null laserjet ; then
	exit 0
else
	exit 1
fi
