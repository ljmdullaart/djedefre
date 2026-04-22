#!/bin/bash

tmp=/tmp/clean_server.$$
tmp1=/tmp/clean_server.$$.1
tmp2=/tmp/clean_server.$$.2


SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

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
fi


echo  remove items from pages that no longer exist
SQL "SELECT item,tbl  FROM pages " > $tmp
while read id tbl ; do
	SQL "SELECT * FROM $tbl WHERE id=$id" > $tmp2
	if [ "$(wc -c < $tmp2)" -le 5 ]; then
		SQL "DELETE FROM pages WHERE tbl='$tbl' and item=$id"
		echo "Deleted $tbl $id"
	fi

done <$tmp

SQL "SELECT id  FROM pages WHERE xcoord <10" > $tmp
while read id ; do
	SQL "UPDATE pages SET xcoord=50 WHERE id=$id";
done <$tmp
SQL "SELECT id  FROM pages WHERE ycoord <10" > $tmp
while read id ; do
	SQL "UPDATE pages SET ycoord=50 WHERE id=$id";
done <$tmp


rm -f $tmp
rm -f $tmp1
rm -f $tmp2
