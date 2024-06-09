#!/bin/bash

tmp=/tmp/scan_remote_server.$$
tmp2=/tmp/scan_remote_server.$$.2


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

sqlite3  -cmd ".timeout 1000" "$database" "SELECT ip FROM interfaces WHERE access LIKE 'ssh%'" > $tmp


for interface in $(cat $tmp) ; do
	echo "Interface $interface:"
	access=$(sqlite3  -cmd ".timeout 1000" "$database" "SELECT access FROM interfaces WHERE ip='$interface'")
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
		$sshcmd$interface ip -o addr |
			grep -v '127.0.0.1'  |
			sed  's/\// /g'      |
			sed 's/^/        /'
		$sshcmd$interface ip -o addr |
			grep -v '127.0.0.1'  |
			sed  's/\// /g'      |
			grep -v '^$'         |
			while read seq ifname type ip rcidr rest ; do
				echo "        read ip=$ip  rcidr=$rcidr"
				echo "        add interface  $ip $serverid"
				add_if $ip $serverid
				if [ "$type" = "inet" ] ; then
					if [ "$rcidr" != "" ] ; then
						nwaddr=$(ipcalc $ip/$rcidr | sed -n 's/\/.*//;s/^Network:\s*//p')
						sqlite3   -cmd ".timeout 1000" $database "UPDATE interfaces SET ifname='$ifname' WHERE ip='$interface'"
						echo "    add subnet $nwaddr $rcidr"
						add_subnet $nwaddr $rcidr
						echo "     $nwaddr $rcidr"
						sqlite3  -cmd ".timeout 1000"  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
					fi
				fi
				rcidr=''
			done
	elif $sshcmd$interface which ifconfig | grep -q ifconfig ; then
		echo "    ifconfig"
		$sshcmd$interface ifconfig               |
		  #sed 's/: / /;:a;N;$!ba;s/\n[ \t]/ /g'  |
		  #grep -v '127.0.0.1'                    |
		  #grep -v '^$'                           |
		  #while read ifname flags labm mtu inet ip nm mask rest ; do
		  awk '	/^[a-z]/	{ interface = $1 }
			/^[ \t]*inet /	{ ip[interface] = $2 ; mask[interface] = $4}
			/^[ \t]*ether /	{ mac[interface] = $2 }
			END		{ for (i in ip) { print i, ip[i], mask[i], mac[i] } }
		  ' |
		  grep -v 'lo' |
		  while read ifname ip mask mac ; do
			echo "    add interface  $ip $serverid"
			add_if $ip $serverid
			nwaddr=$(ipcalc $ip/$mask | sed -n 's/\/.*//;s/^Network:\s*//p')
			rcidr=$(ipcalc -b $ip/$mask | sed -n 's/Netmask:.*= //p')
			sqlite3  -cmd ".timeout 1000"  $database "UPDATE interfaces SET ifname='${ifname%:}' WHERE ip='$interface'"
			sqlite3  -cmd ".timeout 1000"  $database "UPDATE interfaces SET macid='$mac' WHERE ip='$interface'"
			echo "    add subnet $nwaddr $rcidr"
			add_subnet $nwaddr $rcidr
			echo "     $nwaddr $rcidr"
			sqlite3  -cmd ".timeout 1000"  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
		done
	fi

done


rm -f $tmp
rm -f $tmp2



