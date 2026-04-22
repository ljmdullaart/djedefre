#!/bin/bash

if wget -q -O /dev/null http://cranberry.home:3000/ ; then
	exit 0
else
	ssh cranberry.home "ps -ef | grep s[e]rver.pl | awk '{print \$2}' | xargs sudo kill -9 "
	sleep 1
	if wget -q -O /dev/null http://cranberry.home:3000/ ; then
		exit 0
	else
		sleep 1
		if wget -q -O /dev/null http://cranberry.home:3000/ ; then
			exit 0
		else
			exit 1
		fi
	fi
fi
