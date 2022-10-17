#host!/bin/bash

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

for ip in $(cat $tmpfile2) ; do
	next=$(sqlite3 $database "SELECT id FROM interfaces WHERE ip='$ip'" )
	echo -n "SCAN INTERNET  $ip-> $next ; "
	if [ "$next" != "" ] ; then
		lastif=$ip
		lastid=$next
	fi
	echo "lastif=$lastif"
done

rm -f $tmpfile
rm -f $tmpfile2

lasthost=$(sqlite3 $database "SELECT host FROM interfaces WHERE id='$lastid'")

echo  -n 'The last host is '
sqlite3 $database "SELECT * FROM server WHERE id=$lasthost"

inetnet=$(sqlite3 $database "SELECT id FROM subnet WHERE nwaddress='Internet'")
inetif=$(sqlite3 $database "SELECT id FROM interfaces WHERE ip='Internet'")
inethost=$(sqlite3 $database "SELECT host FROM interfaces WHERE ip='Internet'")

if [ "$inetif" = "" ] ; then
	sqlite3 $database  "INSERT INTO interfaces (host,subnet,ip) VALUES ($lasthost,$inetnet,'Internet')"
elif [ "$inethost" != "$lasthost" ] ; then
	sqlite3 $database  "INSERT INTO interfaces (host,subnet,ip) VALUES ($lasthost,$inetnet,'Internet')"
else
	sqlite3 $database "UPDATE interfaces SET host=$lasthost WHERE ip='Internet'"
fi

