#!/bin/bash


if [ -f /usr/local/bin/djedefre.common ] ; then
	. /usr/local/bin/djedefre.common
fi
if [ -f /opt/djedefre/bin/djedefre.common ] ; then
	. /opt/djedefre/bin/djedefre.common
fi
if [ -f djedefre.common.sh ] ; then
	. djedefre.common.sh
fi

date > status.check.log
for server_id in $(sqlite3 "$database" "SELECT id FROM server") ; do
	name=$(sqlite3 "$database" "SELECT name FROM server WHERE id=$server_id")
	if [ -f "status_$name.sh" ] ; then
		echo "Script for $name" >> status.check.log
		if bash "status_$name.sh" ; then
			sqlite3 "$database" "UPDATE server SET status='up' WHERE id=$server_id"
			echo "    $name up" >> status.check.log
		else
			sqlite3 "$database" "UPDATE server SET status='down' WHERE id=$server_id"
			echo "    $name down" >> status.check.log
		fi
	else
		echo "Ping for $name" >> status.check.log
		up=0
		for interface in $(sqlite3 "$database" "SELECT ip FROM interfaces WHERE host=$server_id") ; do
			if ping -c1 -W1 -q $interface ; then
				up=1
			fi
		done
		if [ $up = 1 ] ; then
			sqlite3 "$database" "UPDATE server SET status='up' WHERE id=$server_id"
			echo "    $name up" >> status.check.log
		else
			sqlite3 "$database" "UPDATE server SET status='down' WHERE id=$server_id"
			echo "    $name down" >> status.check.log
		fi
	fi
done

