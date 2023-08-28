#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_status.$$
NOW=$(date -Iseconds | sed 's/+.*//')

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

date > status.check.log

previnet=$(sqlite3 "$database" "SELECT value FROM config WHERE attribute='run:param' AND item='inetup'")
if [ "$previnet" = "" ] ; then
	sqlite3 "$database" "INSERT INTO config (attribute,item,value) VALUES ('run:param','inetup','unknown')"
fi
if ping -c1 8.8.8.8 > /dev/null 2>&1 ; then
	if [ "$previnet" = "up" ] ; then
		:
	else 
		sqlite3 "$database" "UPDATE config SET value='up' WHERE attribute='run:param' AND item='inetup'"
		sqlite3 "$database" "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
else
	if [ "$previnet" = "up" ] ; then
		sqlite3 "$database" "UPDATE config SET value='down' WHERE attribute='run:param' AND item='inetup'"
		sqlite3 "$database" "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
fi


sqlite3 "$database" "SELECT id FROM server" >$tmp
for server_id in $(cat $tmp) ; do
	name=$(sqlite3 "$database" "SELECT name FROM server WHERE id=$server_id")
	stat=$(sqlite3 "$database" "SELECT status FROM server WHERE id=$server_id")
	
echo "$name($server_id)=$stat"
	if [ "$stat" = "excluded" ] ; then
		:
echo "	excluded"
	elif [ -f "$SCRIPTPATH/status_$name.sh" ] ; then
		echo "Script for $name" >> status.check.log
		if bash "$SCRIPTPATH/status_$name.sh" ; then
			sqlite3 "$database" "UPDATE server SET status='up' WHERE id=$server_id"
			sqlite3 "$database" "UPDATE server SET last_up='$NOW' WHERE id=$server_id"
			echo "    $name up" >> status.check.log
		else
			sqlite3 "$database" "UPDATE server SET status='down' WHERE id=$server_id"
			echo "    $name down" >> status.check.log
		fi
	else
		echo "Ping for $name" >> status.check.log
		up=0
		for interface in $(sqlite3 "$database" "SELECT ip FROM interfaces WHERE host=$server_id") ; do
			if ping -c1 -W1 -q $interface  >/dev/null 2> /dev/null ; then
				up=1
			elif ping -c1 -W1 -q $interface  >/dev/null 2> /dev/null ; then
				up=1
			elif arping -c1 -q $interface  >/dev/null 2> /dev/null ; then
				up=1
			elif arping -c1 -q $interface  >/dev/null 2> /dev/null ; then
				up=1
			elif wget -qO-  $interface  >/dev/null 2> /dev/null ; then
				up=1
			elif ping -c1 -W1 -q $interface  >/dev/null 2> /dev/null ; then
				up=1
			elif nmap -Pn $interface -p 2968 | grep -q open ; then
				up=1
			fi
		done
		if [ $up = 1 ] ; then
			sqlite3 "$database" "UPDATE server SET status='up' WHERE id=$server_id"
			sqlite3 "$database" "UPDATE server SET last_up='$NOW' WHERE id=$server_id"
			echo "    $name up" >> status.check.log
			if [ "$stat" != "up" ] ; then
				sqlite3 "$database" "UPDATE config SET value='yes' WHERE  attribute='run:param' AND item='changed'"
			fi
		else
			sqlite3 "$database" "UPDATE server SET status='down' WHERE id=$server_id"
			echo "    $name down" >> status.check.log
			if [ "$stat" = "up" ] ; then
				sqlite3 "$database" "UPDATE config SET value='yes' WHERE  attribute='run:param' AND item='changed'"
			fi
		fi
	fi
done

rm -f $tmp
