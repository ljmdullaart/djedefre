#!/bin/bash

tmp=/tmp/scan_server.$$
tmp1=/tmp/scan_server.$$.1
tmp2=/tmp/scan_server.$$.2


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

sqlite3  -separator ' ' "$database" "DELETE FROM interfaces WHERE ip like '255.255%'"
sqlite3  -separator ' ' "$database" "DELETE FROM interfaces WHERE ip like '127.%'"

sqlite3  -separator ' ' "$database" "SELECT id,ip,host,access FROM interfaces" > $tmp

grep ssh $tmp |
	while read id ip host access ; do
		echo "Scan server for $ip"
		if [[ "$access" == *"root"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 root@'
		elif [[ "$access" == *"admin"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 admin@'
		else
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 '
		fi
		echo hop| $sshcmd$ip ip addr 2>&1 | sed -n 's/\/.*//;s/.*inet //p' > $tmp2
		echo hop| $sshcmd$ip ifconfig 2>&1 |sed -n 's/.*inet \(.*\) netmask \(.*\) br.*/\1 \2/p' >>$tmp2
		echo hop| $sshcmd$ip ifconfig 2>&1 |sed -n 's/.*inet addr://;s/ .*Mask:.*//p' >>$tmp2
		cat $tmp2
		if grep "[0-9]" $tmp2 ; then
			hostname=$(sqlite3 "$database" "SELECT name FROM server WHERE id=$host")
			rm -f $tmp1
			for ifl in $(sqlite3 "$database" "SELECT ip FROM interfaces WHERE host=$host") ; do
				if grep  "$ifl" $tmp2 ; then
					true
				else
					sqlite3 "$database" "DELETE FROM interfaces WHERE ip='$ifl'"
				fi
			done
		fi		

	done

rm -f $tmp
rm -f $tmp1
rm -f $tmp2
