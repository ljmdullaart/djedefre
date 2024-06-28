#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp1=/tmp/scan_l2top1.$$
tmp2=/tmp/scan_l2top2.$$

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


grid=50

if [ "$1" != "" ] ; then
	grid=$1
fi



sqlite3 -separator ' '  $database "SELECT tbl,item FROM pages WHERE page='l2-top'" >$tmp1

sqlite3 -separator ' '  $database "SELECT id,xcoord,ycoord FROM server" > $tmp2
cat $tmp2 | while read id x y ; do
	if [ "$id" != "" ] ; then
		if [ "$x" = "" ] ; then x=100; fi
		if [ "$y" = "" ] ; then y=100; fi
		if  grep -q "server $id$" $tmp1  ; then
			:
		else
			echo -n '.'
			sqlite3 $database "INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ('l2-top','server',$id,$x,$y)"
		fi
	fi
done

sqlite3 -separator ' '  $database "SELECT id FROM switch" > $tmp2
cat $tmp2 | while read id ; do
	if  grep -q "switch $id$" $tmp1  ; then
		:
	else
		echo -n ','
		sqlite3 $database "INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ('l2-top','switch',$id,100,100)"
	fi
done



echo


rm -f $tmp1
rm -f $tmp2
