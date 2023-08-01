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
sqlite3 "$database" "SELECT id FROM server" >$tmp
for server_id in $(cat $tmp) ; do
	name=$(sqlite3 "$database" "SELECT name FROM server WHERE id=$server_id")
	if [ -f "$SCRIPTPATH/status_$name.sh" ] ; then
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
			if arping -c1 -q $interface ; then
				up=1
			fi
			if ping -c1 -W1 -q $interface ; then
				up=1
			fi
			if nmap -Pn $interface -p 2968 | grep open ; then
				up=1
			fi
		done
		if [ $up = 1 ] ; then
			sqlite3 "$database" "UPDATE server SET status='up' WHERE id=$server_id"
			sqlite3 "$database" "UPDATE server SET last_up='$NOW' WHERE id=$server_id"
			echo "    $name up" >> status.check.log
		else
			sqlite3 "$database" "UPDATE server SET status='down' WHERE id=$server_id"
			echo "    $name down" >> status.check.log
		fi
	fi
done

rm -f $tmp
