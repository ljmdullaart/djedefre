#!/bin/bash

if nslookup phi phi > /dev/null 2>/dev/null ; then
	exit 0
else
	exit 1
fi
