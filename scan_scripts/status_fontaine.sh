#!/bin/bash

if ssh fontaine id > /dev/null; then
	exit 0
else
	exit 1
fi
