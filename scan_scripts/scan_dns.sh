#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_dbconsist.$$

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


readarray -t interfaces < <(sqlite3 -separator ' ' $database 'SELECT id,ip FROM interfaces'          )
readarray -t subnets    < <(sqlite3 -separator ' ' $database 'SELECT id,nwaddress,cidr FROM subnet'  )
readarray -t servers    < <(sqlite3 -separator ' ' $database 'SELECT id,name FROM server'  )


for interface in "${interfaces[@]}" ; do
	read ifid ip < <(echo $interface)
	if host $ip > /dev/null 2>/dev/null ; then
		hostname=$(host $ip | sed 's/.* //')
		sqlite3  $database "UPDATE interfaces SET hostname='$hostname' WHERE id=$ifid"
		sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
done

for server in "${servers[@]}" ; do
	read srvid name < <(echo $interface)
	if [[ $name =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		if host $name > /dev/null 2>/dev/null ; then
			hostname=$(host $name | sed 's/.* //')
			sqlite3  $database "UPDATE server SET name='$hostname' WHERE id=$srvid"
			sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
		fi
	fi
done

	




rm -f $tmp
