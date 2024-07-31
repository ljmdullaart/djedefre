#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_status.$$
NOW=$(date -Iseconds | sed 's/+.*//')
LOG=/tmp/status.check.log
date > $LOG

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


previnet=$(sqlite3 "$database"  -cmd ".timeout 1000"   "SELECT value FROM config WHERE attribute='run:param' AND item='inetup'")
if [ "$previnet" = "" ] ; then
	sleep 1
	previnet=$(sqlite3 "$database"  -cmd ".timeout 1000"   "SELECT value FROM config WHERE attribute='run:param' AND item='inetup'")
	if [ "$previnet" = "" ] ; then
		sleep 1
		previnet=$(sqlite3 "$database"  -cmd ".timeout 1000"   "SELECT value FROM config WHERE attribute='run:param' AND item='inetup'")
		if [ "$previnet" = "" ] ; then
			sqlite3 "$database"  -cmd ".timeout 1000"   "INSERT INTO config (attribute,item,value) VALUES ('run:param','inetup','unknown')"
		fi
	fi
fi
if ping -c1 8.8.8.8 > /dev/null 2>&1 ; then
	echo "Internet is up."
	if [ "$previnet" = "up" ] ; then
		:
	else 
		sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE config SET value='up' WHERE attribute='run:param' AND item='inetup'"
		sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
else
	echo "Internet is down."
	if [ "$previnet" = "up" ] ; then
		sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE config SET value='down' WHERE attribute='run:param' AND item='inetup'"
		sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
fi


sqlite3 "$database"  -cmd ".timeout 1000"   "SELECT id FROM server" >$tmp
for server_id in $(cat $tmp) ; do
	name=$(sqlite3 "$database"  -cmd ".timeout 1000"   "SELECT name FROM server WHERE id=$server_id")
	stat=$(sqlite3 "$database"  -cmd ".timeout 1000"   "SELECT status FROM server WHERE id=$server_id")
	
echo "$name($server_id)=$stat" >> $LOG
	if [ "$stat" = "excluded" ] ; then
		:
echo "	excluded"
	elif [ -f "$SCRIPTPATH/status_$name.sh" ] ; then
		echo "Script for $name" >> $LOG
		if bash "$SCRIPTPATH/status_$name.sh" ; then
			sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE server SET status='up' WHERE id=$server_id"
			sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE server SET last_up='$NOW' WHERE id=$server_id"
			echo "    $name up" >> $LOG
		else
			sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE server SET status='down' WHERE id=$server_id"
			echo "    $name down" >> $LOG
		fi
	else
		echo "Ping for $name" >> $LOG
		up=0
		for interface in $(sqlite3 "$database"  -cmd ".timeout 1000"   "SELECT ip FROM interfaces WHERE host=$server_id") ; do
			echo "    $interface"
			echo "    "
			if echo -n '1' && ping -c1 -W1 -q $interface  >/dev/null 2> /dev/null ; then
				echo " $interface ping is ok"
				up=1
			elif echo -n '2' && ping -c1 -W1 -q $interface  >/dev/null 2> /dev/null ; then
				echo " $interface ping is ok"
				up=1
			elif echo -n '3' && arping -c1 -w1 -q $interface  >/dev/null 2> /dev/null ; then
				echo " $interface arping is ok"
				up=1
			elif echo -n '4' && arping -c1 -w1 -q $interface  >/dev/null 2> /dev/null ; then
				echo " $interface arping is ok"
				up=1
			elif echo -n '6' && ping -c1 -W1 -q $interface  >/dev/null 2> /dev/null ; then
				echo " $interface ping is ok"
				up=1
			elif echo -n '7' && nmap -Pn $interface -p 2968 | grep -q open ; then
				echo " $interface nmap is ok"
				up=1
			fi
		done
		if [ $up = 1 ] ; then
			sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE server SET status='up' WHERE id=$server_id"
			sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE server SET last_up='$NOW' WHERE id=$server_id"
			echo "    $name up" >> $LOG
			if [ "$stat" != "up" ] ; then
				sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE config SET value='yes' WHERE  attribute='run:param' AND item='changed'"
			fi
		else
			sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE server SET status='down' WHERE id=$server_id"
			echo "    $name down" >> $LOG
			if [ "$stat" = "up" ] ; then
				sqlite3 "$database"  -cmd ".timeout 1000"   "UPDATE config SET value='yes' WHERE  attribute='run:param' AND item='changed'"
			fi
		fi
	fi
done

rm -f $tmp
