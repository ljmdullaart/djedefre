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

current_seconds=$(date +%s)

echo  remove hosts that are more than 3 months down
list_server | while read srv_id ; do
	last_up=$(valfromid server $srv_id last_up)
	if [ "$last_up" = "" ] ; then
		del_server $srv_id
	else
		past_seconds=$(date -d "${last_up/T/ }" +%s)
		days_ago=$(( (current_seconds - past_seconds) / 86400 ))
		if [ $days_ago -gt 60 ] ; then
			del_server $srv_id
		fi
	fi
done


echo  remove servers without interfaces

list_server | while read srv_id ; do
	ifaces=$(valfromid interfaces $srv_id id)
	if [ "$ifaces" = "" ]; then
		del_server $srv_id
	fi
done

rm -f $tmp
rm -f $tmp1
rm -f $tmp2
