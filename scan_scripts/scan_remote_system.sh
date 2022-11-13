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
	cidr=''
	if $sshcmd$interface which ip | grep -q ip ; then
		echo "    ip addr"
		$sshcmd$interface ip addr |
			grep -v '127.0.0.1' |
			sed -n 's/.*inet \(.*\)\/\(.*\) brd.*/\1 \2/p' | 
			sed 's/^/    /'
		$sshcmd$interface ip addr |
			grep -v '127.0.0.1' |
			sed -n 's/.*inet \(.*\)\/\(.*\) brd.*/\1 \2/p' | 
			while read ip rcidr ; do
				echo "    read ip=$ip  rcidr=$rcidr"
				echo "    add interface  $ip $serverid"
				add_if $ip $serverid
				if [ "$rcidr" != "" ] ; then
					nwaddr=$(ipcalc $ip/$rcidr | sed -n 's/\/.*//;s/^Network:\s*//p')
					echo "    add subnet $nwaddr $rcidr"
					add_subnet $nwaddr $rcidr
					echo "     $nwaddr $rcidr"
				fi
				rcidr=''
			done
	elif $sshcmd$interface which ifconfig | grep -q ifconfig ; then
		echo "    ifconfig"
		$sshcmd$interface ifconfig |
		grep -v '127.0.0.1' |
		sed -n 's/.*inet \(.*\) netmask \(.*\) br.*/\1 \2/p' |
			while read ip mask ; do
				echo "    add interface  $ip $serverid"
				add_if $ip $serverid
				nwaddr=$(ipcalc $ip/$mask | sed -n 's/\/.*//;s/^Network:\s*//p')
				rcidr=$(ipcalc -b $ip/$mask | sed -n 's/Netmask:.*= //')
				echo "    add subnet $nwaddr $rcidr"
				add_subnet $nwaddr $rcidr
				echo "     $nwaddr $rcidr"
			done
	fi

done


rm -f $tmp


