#!/bin/bash

if ssh pi ps -ef | grep -q 'cit[s]erver' ; then
	exit 0
else
	exit 1
fi
