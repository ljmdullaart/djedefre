#!/bin/bash

tmp=/tmp/scan_subnet.$$
tmp1=/tmp/scan_subnet1.$$


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

if [ "$2" = "" ] ; then
	sqlite3  -separator ' ' -cmd ".timeout 1000"  "$database" "SELECT id,nwaddress,cidr FROM subnet" > $tmp1
else
	sqlite3  -separator ' ' -cmd ".timeout 1000"  "$database" "SELECT id,nwaddress,cidr FROM subnet WHERE id=$2" > $tmp1
fi
echo Scan subnets
sed 's/^/    /' $tmp1
echo '-------------------'
grep -v Internet $tmp1 | while read id ip cidr ; do

		echo  "    $ip / $cidr"
		if [ "$cidr" != '' ] ; then
			if [ $cidr -gt 22 ] ; then
				sudo fping -g $ip/$cidr 2>&1 | sed -n 's/ is alive//p'>> $tmp
			fi
		fi
	done
	echo


sort -u $tmp | while read if id; do
	ifid=$(sqlite3  -separator ' ' -cmd ".timeout 1000"  "$database" "SELECT id FROM interfaces WHERE ip='$if'")
	if [ "$ifid" = "" ] ; then
		sqlite3  -separator ' '  $database "INSERT INTO interfaces (ip) VALUES ('$if')"
	fi
	sqlite3 -cmd ".timeout 1000"  "$database" "UPDATE interfaces SET subnet='$id' WHERE ip='$if'"
	host=$(sqlite3  -separator ' ' -cmd ".timeout 1000"  "$database" "SELECT host FROM interfaces WHERE ip='$if'")
	if [ "$host" = "" ] ; then
		add_server $if
		sqlite3 -cmd ".timeout 1000"  "$database" "UPDATE interfaces SET host=$db_retval  WHERE ip='$if'"
		sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
	
done

if_net;

rm -f $tmp
rm -f $tmp1
