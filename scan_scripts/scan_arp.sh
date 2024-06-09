#!/bin/bash

tmp=/tmp/scan_arp.$$
tmp1=/tmp/scan_arp.$$.1
tmp2=/tmp/scan_arp.$$.2


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

cat /proc/net/arp |
awk '{print $1 " " $4}' |
egrep -v '00:00:00:00:00:00|IP' >> $tmp1

sqlite3  -separator ' '  -cmd ".timeout 1000" "$database" "SELECT id,ip,access FROM interfaces" > $tmp

grep ssh $tmp |
	while read id ip access ; do
		echo "Get arp from $ip"
		if [[ "$access" == *"root"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 root@'
		elif [[ "$access" == *"admin"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 admin@'
		else
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 '
		fi
		if echo hop | $sshcmd$ip which ip 2>/dev/null | grep -q ip ; then
			echo hop | $sshcmd$ip 2>/dev/null  ip addr | awk '
				/inet /{ inet=$2 }
				/link.ether/ { link=$2}
				/^[0-9]/ { printf "%s %s\n", inet, link }
				END { printf "%s %s\n", inet, link }
			' | sed -n 's/\/[0-9]*//p' |sort -u | grep -v 127.0.0.1 |
			while read myip mymac ; do
				if [[ $myip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
					sqlite3   -cmd ".timeout 1000" "$database" "UPDATE interfaces SET macid='$mymac' WHERE ip='$myip'"
				fi
			done
		fi
		echo hop|
			$sshcmd$ip 2>/dev/null  "if [ -f /proc/net/arp ] ; then cat /proc/net/arp; fi" |
			egrep -v '00:00:00:00:00:00|IP'  |
			awk '{print $1 " " $4 }'>> $tmp1
	done

sort -u $tmp1 | while read ip macid; do
	if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		if [ "$macid" != "" ] ; then
			host=$(sqlite3  -separator ' '  -cmd ".timeout 1000" "$database" "SELECT host FROM interfaces WHERE ip='$ip'")
			sqlite3   -cmd ".timeout 1000" "$database" "UPDATE interfaces SET macid='$macid' WHERE ip='$ip'"
			echo "SET macid='$macid' WHERE ip='$ip'"
		fi
	fi

done


	
	

#sqlite3  "$database" "DELETE FROM interfaces WHERE subnet IS NULL"


rm -f $tmp $tmp1 $tmp2
