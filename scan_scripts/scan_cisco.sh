#!/bin/bash


tmp=/tmp/scan_cisco.$$
tmp1=/tmp/scan_cisco.$$.1
tmp2=/tmp/scan_cisco.$$.2
tmp3=/tmp/scan_cisco.$$.3

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

SQL="sqlite3  -separator ' '  $database "

sqlite3  -separator ' '  $database "SELECT id FROM server WHERE type='cisco'" > $tmp
for host in $(cat $tmp) ; do
	echo "CISCO host $host"
	sqlite3  -separator ' '  $database "SELECT ip FROM interfaces WHERE host=$host" > $tmp1
	for ip in $(cat $tmp1) ; do
		echo "    interface $ip"
		ssh -x -o PasswordAuthentication=no -o ConnectTimeout=4  $ip sh proto | dos2unix | sed -n -e 's/ is up.*//p' -e 's/.*address is//p' | paste - - | grep "$ip" >$tmp3
		cat $tmp3 | while read ifname ipnet ; do
			ipcalc -b  "$ipnet" > $tmp2
			ifip=$(sed -n 's/^Address:[ 	]*//p' $tmp2)
			existing=$(sqlite3  -separator ' ' "$database" "SELECT ip FROM interfaces WHERE ip='$ifip'")
			echo "--> host=$host ip=$ip ifname=$ifname ipnet=$ipnet"
			if [ "$existing" = "" ] ; then
				echo "        -> new interface: $ifip on $host"
				sqlite3  $database "INSERT INTO interfaces (ip,host) VALUES ('$ifip',$host)"
				sqlite3  -separator ' '  $database "UPDATE interfaces SET ifname='$ifname' WHERE  ip='$ifip'"
				sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
			else
				echo "        -> Claiming interface: $ifip on $host"
				sqlite3  -separator ' '  $database "UPDATE interfaces SET host=$host WHERE  ip='$ifip'"
				sqlite3  -separator ' '  $database "UPDATE interfaces SET ifname='$ifname' WHERE  ip='$ifip'"
			fi
			for net in $(sed -n 's/\/.*//;s/^Network:[ 	]*//p' $tmp2) ; do
				existing=$(sqlite3  -separator ' ' "$database" "SELECT id FROM subnet WHERE nwaddress='$net'")
				if [ "$existing" = "" ] ; then
					cidr=$(sed -n "s/^Network:.*$net\///p" $tmp2 | head -1) ;
					echo "existing:$existing      net:$net     cidr:$cidr"
					sqlite3  -separator ' '  $database "INSERT INTO subnet (nwaddress,cidr) VALUES ('$net',$cidr)"
					sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
					cidr=''
				else 
					echo "        Existing subnet $existing for $net"
				fi
			done
			ifname=''
		done
		ssh -x -o PasswordAuthentication=no -o ConnectTimeout=4 $ip sh arp | dos2unix > $tmp3
		for newif in $(sed -n 's/Internet r* \([^ ]*\).*/\1/p' $tmp3) ; do
			echo "Found interface $newif"
			add_if $newif
		done
		ssh -x -o PasswordAuthentication=no -o ConnectTimeout=4  $ip sh arp | dos2unix | awk '/Internet/ { print $2,$4 }' >$tmp3
		sed 's/\(.*\) \(..\)\(..\).\(..\)\(..\).\(..\)\(..\)/\1 \2:\3:\4:\5:\6:\7/' $tmp3 |
		while read ifip ifmac ; do
			sqlite3  -separator ' '  $database "UPDATE interfaces SET macid='$ifmac' WHERE ip='$ifip'"
		done
		
	done
done

sqlite3  -separator ' '  $database "SELECT name FROM server WHERE type='cisco'" > $tmp
for h in $(cat $tmp) ; do
	echo "Check name for $h"
	if [[ $h =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		name=$(ssh $h sh version | sed -n 's/ uptime i.*//p')
		echo "    $name"
		sqlite3  -separator ' '  $database "UPDATE server SET name='$name' WHERE name='$h'"
		sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
done

rm -f $tmp $tmp1 $tmp2 $tmp3
