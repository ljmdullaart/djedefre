#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_access.$$

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

if sqlite3 $database  'SELECT nwaddress FROM subnet' |grep Internet ; then
        echo "Internet is present"
elif ping -c1 8.8.8.8 > /dev/null 2>/dev/null ; then
        sqlite3 $database  "INSERT INTO subnet (nwaddress,name) VALUES ('Internet','Internet')"
	sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
else
        echo "No Internet."
	exit 0
fi

tmpfile=/tmp/scan_internet.$$
tmpfile2=/tmp/scan_internet2.$$

traceroute 8.8.8.8                |
	grep ms                   |
	sed -n 's/.*(//;s/).*//p' >>$tmpfile2

lastif=$( ip route get 8.8.8.8 | sed -n 's/.*src //;s/ .*//;1p')
lastid=$(sqlite3 $database "SELECT id FROM interfaces WHERE ip='$lastif'" )
if [ "$lastid" = "" ] ; then
	echo "Cannot determine the last host before Internet"
	exit 
fi

path="$lastif"
idpath=$(sqlite3 $database "SELECT host FROM interfaces WHERE ip='$lastif'" )

for ip in $(cat $tmpfile2) ; do
	next=$(sqlite3 $database "SELECT id FROM interfaces WHERE ip='$ip'" )
	echo -n "SCAN INTERNET  $ip-> $next ; "
	if [ "$next" != "" ] ; then
		nexthost=$(sqlite3 $database "SELECT host FROM interfaces WHERE ip='$ip'" )
		nextname=$(sqlite3 $database "SELECT name FROM server WHERE id=$nexthost")
		lastif=$ip
		lastid=$next
		path="$path:$nextname"
		idpath="$idpath:$nexthost"
	fi
	echo "lastif=$lastif"
done

rm -f $tmpfile
rm -f $tmpfile2

lasthost=$(sqlite3 $database "SELECT host FROM interfaces WHERE id='$lastid'")

echo  -n 'The last host is '
sqlite3 $database "SELECT * FROM server WHERE id=$lasthost"
echo "Path=$path"
echo "Idpath=$idpath"
if sqlite3 $database  "SELECT item FROM config WHERE attribute='run:param' AND item='idpath'" |grep idpath ; then
        sqlite3  $database "UPDATE config SET value='$idpath' WHERE attribute='run:param' AND item='idpath'"
else
        sqlite3 $database  "INSERT INTO config (attribute,item,value) VALUES ('run:param','idpath','$idpath')"
fi

inetnet=$(sqlite3 $database "SELECT id FROM subnet WHERE nwaddress='Internet'")
inetif=$(sqlite3 $database "SELECT id FROM interfaces WHERE ip='Internet'")
inethost=$(sqlite3 $database "SELECT host FROM interfaces WHERE ip='Internet'")

if [ "$inetif" = "" ] ; then
	sqlite3 $database  "INSERT INTO interfaces (host,subnet,ip,switch) VALUES ($lasthost,$inetnet,'Internet',-1)"
	sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
else
	sqlite3 $database "UPDATE interfaces SET host=$lasthost WHERE ip='Internet'"
	sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
fi

