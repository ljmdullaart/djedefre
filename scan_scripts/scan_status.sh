#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
database="$SCRIPTPATH/../database/djedefre.db"
tmp=/tmp/scan_status.$$
NOW=$(date -Iseconds | sed 's/+.*//')
epochsec=$(date +%s)
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


previnet=$(get_dbconfig 'run:param' 'inetup')
if [ "$previnet" = "" ] ; then
	sleep 1
	previnet=$(get_dbconfig 'run:param' 'inetup')
	if [ "$previnet" = "" ] ; then
		set_dbconfig 'run:param' 'inetup' 'unknown'
	fi
fi

if ping -c1 8.8.8.8 > /dev/null 2>&1 ; then
	echo "Internet is up."
	set_dbconfig 'run:param' 'inetup' 'up'
	if [ "$previnet" = "up" ] ; then
		:
	else 
		set_dbconfig 'run:param' 'changed' 'yes'
	fi
else
	echo "Internet is down."
	set_dbconfig 'run:param' 'inetup' 'down'
	if [ "$previnet" = "up" ] ; then
		set_dbconfig 'run:param' 'changed' 'yes'
	fi
fi


list_server >$tmp
for server_id in $(cat $tmp) ; do
	name=$(valfromid server $server_id name)
	stat=$(valfromid server $server_id status)
	if [ "$stat" != "excluded" ] ; then
	
		echo "$name($server_id)=$stat" >> $LOG
		if [ -f "$SCRIPTPATH/status_$name.sh" ] ; then
			echo "Script for $name" >> $LOG
			if bash "$SCRIPTPATH/status_$name.sh" ; then
				setfromid server $server_id status up
				setfromid server $server_id last_up "$NOW"
				echo "    $name up" >> $LOG
			else
				setfromid server $server_id status down
				echo "    $name down" >> $LOG

			fi
		else
			echo "Ping for $name" >> $LOG
			up=0
			for if_id in $(idfromval interfaces host $server_id) ; do
				interface=$(valfromid interfaces $if_id ip)
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
				setfromid server $server_id status up
				setfromid server $server_id last_up "$NOW"
				echo "    $name up" >> $LOG
			else
				setfromid server $server_id status down
				echo "    $name down" >> $LOG
			fi
		fi
	fi
done

rm -f $tmp
