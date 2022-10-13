#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_access.$$

if [ -f $SCRIPTPATH/djedefre.common.sh ] ; then
	. $SCRIPTPATH/djedefre.common.sh
fi

if [ "$1" = "-h" ] ; then
	echo 'HELP!!'
	exit 0
elif [ "$1" != '' ] ; then
	if [ -f "$1" ] ; then
		database="$1"
	else
		echo "Database=$database, not $1"
	fi
	shift
fi


grid=25

if [ "$1" != "" ] ; then
	grid=$1
fi

typeset -i halfgrid
halfgrid=$grid/2

typeset -i x
typeset -i y

tmp=/tmp/place_on_grid.$$

sqlite3 -separator ' '  $database "SELECT id,name  FROM server " >$tmp

sed 's/^\([0-9]*\) \([a-z][^\.]*\).*/\1 \2/' $tmp |
	while read id name ; do
		sqlite3 $database "UPDATE server SET name='$name' WHERE id=$id"
	done

rm -f $tmp
