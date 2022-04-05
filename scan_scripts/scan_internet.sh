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

if sqlite3 $database  'SELECT nwaddress FROM subnet' |grep Internet ; then
        echo "Internet is present"
elif ping -c1 8.8.8.8 > /dev/null 2>/dev/null ; then
        sqlite3 $database  "INSERT INTO subnet (nwaddress,name) VALUES ('Internet','Internet')"
else
        echo "No Internet."
fi

tmpfile=/tmp/scan_internet.$$
tmpfile2=/tmp/scan_internet2.$$

ifconfig | sed -n 's/ net.*//;s/.*inet //p' | grep -v 127.0 > $tmpfile2
traceroute 8.8.8.8                |
	grep -v traceroute        |
	sed -n 's/.*(//;s/).*//p' >>$tmpfile2
cat $tmpfile2                     |
	while read ip ; do
		sqlite3 $database "select id from interfaces where ip='$ip'" 
	done>$tmpfile

lastif=$(grep -v '^\s*$' $tmpfile | tail -1)
rm -f $tmpfile
rm -f $tmpfile2

lasthost=$(sqlite3 $database "select host from interfaces where id=$lastif")

qinetif=$(sqlite3 "$database" "SELECT COUNT(ALL)  FROM interfaces WHERE  ip='Internet'")
qinet=$(sqlite3 "$database" "SELECT COUNT(ALL)  FROM subnet WHERE nwaddress='Internet'")

if [ "$qinet" = "0" ] ; then
	echo "No Internet";
elif [ "$qinetif" = 0 ] ; then
	sqlite3 $database "INSERT INTO interfaces (ip,host) VALUES ('Internet','$lasthost')";
fi


