#!/bin/bash

tmp=/tmp/scan_l2.$$
tmp1=/tmp/scan_l2.$$.1
tmp2=/tmp/scan_l2.$$.2


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

sqlite3  -separator ' ' "$database" "SELECT name FROM switch" > $tmp

for switch in $(cat $tmp) ; do
	if ssh $switch mca-dump > $tmp1 2>/dev/null ; then
		if grep "model_display" $tmp1  | grep -q 'US' ; then
			cat  $tmp1 |
			   jq -r '.port_table[] | "\(.port_idx) \(.mac_table[].mac)"' |
			   sed "s/^/$switch /"
			echo "UPDATE switch SET switch='switch' WHERE name='$switch'" |
			   sqlite3  -separator ' ' "$database"
		fi
		if grep "model_display" $tmp1  | grep -q 'UAP' ; then
			cat  $tmp1  |
			   jq '.vap_table[]' | sed -n 's/",//;s/.*"mac": "//p' |
			   cat -n  |
			   sed "s/^/$switch /"
			echo "UPDATE switch SET switch='accesspoint' WHERE name='$switch'" |
			   sqlite3  -separator ' ' "$database"
		fi
	fi
done | sed 's/\t/ /g' | sort -u  > $tmp2

cat $tmp2 | while read switch port mac devtype ; do
	ifid=$(echo "SELECT id FROM interfaces WHERE macid='$mac'"  | sqlite3  -separator ' ' "$database" | head -1)
	hostid=$(echo "SELECT host FROM interfaces WHERE macid='$mac'"  | sqlite3  -separator ' ' "$database" | head -1)
	if [ "$hostid" != '' ] ; then
		hostname=$(echo "SELECT name FROM server WHERE id=$hostid"  | sqlite3  -separator ' ' "$database" | head -1)
	else
		hostname=unknown
	fi
	switchid=$(echo "SELECT id FROM switch WHERE name='$switch'" | sqlite3  -separator ' ' "$database")
	switchname=$(echo "SELECT name FROM switch WHERE name='$switch'" | sqlite3  -separator ' ' "$database")
	qport=$(grep "$switch *$port " $tmp2 | wc -l)
	if [ $qport -eq  1 ] ; then
		if [ "$ifid" != '' ] ; then
			echo "DELETE FROM l2connect WHERE to_tbl='interfaces' AND to_id=$ifid" | sqlite3 "$database"
			echo "INSERT INTO l2connect 
				(from_tbl,from_id,from_port,to_tbl,to_id,to_port)
				VALUES ('switch',$switchid,$port,'interfaces',$ifid,0)
			" | sqlite3 "$database"
		fi
	else
		echo "Switch $switchname port $port connected to $hostname"
	fi
done | sort -u

rm -f $tmp $tmp1 $tmp2
