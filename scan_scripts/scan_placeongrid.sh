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

sqlite3 -separator ' '  $database "SELECT id,xcoord,ycoord  FROM server " >$tmp

cat $tmp |
	while read id x y ; do
		x=$x+$halfgrid
		y=$y+$halfgrid
		x=$x/$grid
		y=$y/$grid
		x=$x*$grid
		y=$y*$grid
		sqlite3 $database "UPDATE server SET xcoord=$x WHERE id=$id"
		sqlite3 $database "UPDATE server SET ycoord=$y WHERE id=$id"
	done

sqlite3 -separator ' '  $database "SELECT id,xcoord,ycoord  FROM subnet " >$tmp

cat $tmp |
	while read id x y ; do
		x=$x+$halfgrid
		y=$y+$halfgrid
		x=$x/$grid
		y=$y/$grid
		x=$x*$grid
		y=$y*$grid
		sqlite3 $database "UPDATE subnet SET xcoord=$x WHERE id=$id"
		sqlite3 $database "UPDATE subnet SET ycoord=$y WHERE id=$id"
	done
rm -f $tmp
