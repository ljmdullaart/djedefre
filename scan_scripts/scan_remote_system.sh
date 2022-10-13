#!/bin/bash

tmp=/tmp/scan_remote_server.$$


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

sqlite3 "$database" "SELECT ip FROM interfaces WHERE access LIKE 'ssh%'" > $tmp


for interface in $(cat $tmp) ; do
	echo "Interface $interface:"
	access=$(sqlite3 "$database" "SELECT access FROM interfaces WHERE ip='$interface'")
	if [[ "$access" == *"root"* ]] ; then
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 root@'
	elif [[ "$access" == *"admin"* ]] ; then
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 admin@'
	else
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 '
	fi
	if $sshcmd$interface which ip | grep -q ip ; then
		echo "    ip addr"
		$sshcmd$interface ip addr |
			grep -v '127.0.0.1' |
			sed -n 's/.*inet \(.*\)\/\(.*\) brd.*/\1 \2/p' | 
			while read ip cidr ; do
				add_if $ip $serverid
				nwaddr=$(ipcalc $ip/$cidr | sed -n 's/\/.*//;s/^Network:\s*//p')
				add_subnet $nwaddr $cidr
				echo "     $nwaddr $cidr"
			done
	elif $sshcmd$interface which ifconfig | grep -q ifconfig ; then
		echo "    ifconfig"
		$sshcmd$interface ifconfig |
		grep -v '127.0.0.1' |
		sed -n 's/.*inet \(.*\) netmask \(.*\) br.*/\1 \2/p' |
			while read ip mask ; do
				add_if $ip $serverid
				nwaddr=$(ipcalc $ip/$mask | sed -n 's/\/.*//;s/^Network:\s*//p')
				cidr=$(ipcalc -b $ip/$mask | sed -n 's/Netmask:.*= //')
				add_subnet $nwaddr $cidr
				echo "     $nwaddr $cidr"
			done
	fi

done


rm -f $tmp


