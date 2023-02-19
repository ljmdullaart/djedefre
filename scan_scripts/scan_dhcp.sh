#!/bin/bash

DHCPSERVER=nameserver

DHCPIP=$(host $DHCPSERVER | sed 's/.* //')
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

DHCPACCESS=$(sqlite3  -separator ' '  $database "SELECT  access  FROM interfaces WHERE ip='$DHCPIP' AND access LIKE '%ssh%'")
	



if [[ "$DCCPACCESS" == *"root"* ]] ; then
    sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 root@'
elif [[ "$DCCPACCESS" == *"admin"* ]] ; then
    sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 admin@'
else
    sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 '
fi
echo hop| $sshcmd$DHCPIP "test -f /var/log/daemon.log && sudo grep DHCPAC /var/log/daemon.log " | sed 's/.*DHCPACK on //' >>$tmp3
echo "Got log from $DHCPIP"
#192.168.178.208 to 7c:b2:7d:86:e1:c9 (verlaine) via wlan0


sort -u $tmp3 | while read if to mac rest ; do
	echo "ip=$if mac=$mac"
	ifid=$(sqlite3  -separator ' ' "$database" "SELECT id FROM interfaces WHERE ip='$if'")
	if [ "$ifid" = "" ] ; then
		sqlite3  -separator ' '  $database "INSERT INTO interfaces (ip) VALUES ('$if')"
		echo "    added $if"
	else
		echo "    $if = $ifid"
	fi
	ifid=$(sqlite3  -separator ' ' "$database" "SELECT id FROM interfaces WHERE ip='$if'")
	host=$(sqlite3  -separator ' ' "$database" "SELECT host FROM interfaces WHERE ip='$if'")
	if [ "$host" = "" ] ; then
		echo "    Added new host"
		add_server $if
		sqlite3 "$database" "UPDATE interfaces SET host=$db_retval  WHERE ip='$if'"
	fi
	
done

if_net

rm -f $tmp1
rm -f $tmp2
rm -f $tmp3
