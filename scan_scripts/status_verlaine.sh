#!/bin/bash

if ping -c1 verlaine.home > /dev/null 2>/dev/null ; then
	exit 0
else
	exit 1
fi
