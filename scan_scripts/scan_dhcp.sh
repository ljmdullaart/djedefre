#!/bin/bash

######################################
# If no DHCP server is found, use thie following:
DHCPSERVER=nameserver

tmp1=/tmp/scan_dhcp1.$$
tmp2=/tmp/scan_dhcp2.$$
tmp3=/tmp/scan_dhcp3.$$

touch $tmp1
touch $tmp2
touch $tmp3

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

echo '-------------------'

dhcpserver=$(grep "dhcp-server-identifier" /var/lib/dhcp/dhclient*.leases | tail -n 1 | sed 's/.* \([0-9.]*\);/\1/')
dhcpip="$dhcpserver"
if [ "$dhcpserver" = "" ] ; then
	dhcpserver="$DHCPSERVER"
	dhcpip=$(host $dhcpserver | sed 's/.* //')
fi

dhcpid=$(idfromval interfaces ip "$dhcpip")

if [ "$dhcpid" = "" ] ; then
	echo "No DHCP server found"
	rm -f  $tmp1 $tmp2 $tmp3
	exit 
fi


cmd_on "$dhcpid" "test -f /var/log/daemon.log && sudo grep DHCPAC /var/log/daemon.log " | sed 's/.*DHCPACK on //' >>$tmp3
echo "Got log from $dhcpid"

exit

sort -u $tmp3 | while read if to mac rest ; do
	echo "ip=$if mac=$mac"
	ifid=$(idfromval interfaces ip "$if")
	if [ "$ifid" = "" ] ; then
		sqlite3  -separator ' '  $database "INSERT INTO interfaces (ip) VALUES ('$if')"
		sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
		echo "    added $if"
	else
		echo "    $if = $ifid"
	fi
	ifid=$(sqlite3  -separator ' ' -cmd ".timeout 1000" "$database" "SELECT id FROM interfaces WHERE ip='$if'")
	host=$(sqlite3  -separator ' ' -cmd ".timeout 1000" "$database" "SELECT host FROM interfaces WHERE ip='$if'")
	if [ "$host" = "" ] ; then
		echo "    Added new host"
		add_server $if
		sqlite3 -cmd ".timeout 1000" "$database" "UPDATE interfaces SET host=$db_retval  WHERE ip='$if'"
		sqlite3  -cmd ".timeout 1000" $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
	
done

if_net

rm -f $tmp1
rm -f $tmp2
rm -f $tmp3
