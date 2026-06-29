#!/bin/bash


tmp=/tmp/scan_cisco.$$
tmp1=/tmp/scan_cisco.$$.1
tmp2=/tmp/scan_cisco.$$.2
tmp3=/tmp/scan_cisco.$$.3
tmp4=/tmp/scan_cisco.$$.4

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


SQL "SELECT id FROM server WHERE type='cisco'" > $tmp


cat $tmp

for host in $(cat $tmp) ; do
	echo "CISCO host $host"
	SQL "SELECT id FROM interfaces WHERE host=$host" > $tmp1
	for interface in $(cat $tmp1) ; do
		cmd_on $interface show arp> $tmp3
		mv $tmp3 $tmp2
		sed "s/^/$interface arp: /" $tmp2
		cmd_on $interface show ip interface brief> $tmp3
		awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/{print $2}' $tmp3 | sed "s/^/$interface: /" 
		for ip in $(awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/{print $2}' $tmp3) ; do
			#Internet  10.128.64.1             -   ca02.2987.0006  ARPA   FastEthernet0/1
			mac=$(awk "/$ip/"'{
				str=tolower($4);
				gsub(/\./, "", str);
				print gensub(/(..)(..)(..)(..)(..)(..)/, "\\1:\\2:\\3:\\4:\\5:\\6", "g", str)}
			' $tmp2)
			if [ "$ip" != "" ] && [ "$macid" != '' ] ; then
				SQL "UPDATE interfaces SET macid='$mac' WHERE ip='$ip'"
			fi
			name=$(awk "/$ip/{print \$6}" $tmp2)
			echo " host=$host interface=$interface $ip $mac name=$name"
			existid=$(SQL "SELECT id FROM interfaces WHERE ip='$ip'")
			if  [ "$existid" = "" ] ; then
				SQL "INSERT INTO interfaces (ip) VALUES ('$ip')"
				existid=$(SQL "SELECT id FROM interfaces WHERE ip='$ip'")
			fi
			if  [ "$existid" != "" ] ; then
				SQL "UPDATE interfaces SET ifname='$name' WHERE id=$existid"
				SQL "UPDATE interfaces SET macid='$mac' WHERE id=$existid"
				SQL "UPDATE interfaces SET host=$host WHERE id=$existid"
			fi
		done
		cmd_on $interface sh ip route con > $tmp3
		sed "s/^/   $interface: /" $tmp3
		awk '/^C.*directly connected/{print $2}' $tmp3 | while IFS=/ read ip cidr ; do
			echo "    $ip / $cidr"
			add_subnet $ip $cidr "scan_cisco_$ip"
		done
	done

done



rm -f $tmp $tmp1 $tmp2 $tmp3 $tmp4
