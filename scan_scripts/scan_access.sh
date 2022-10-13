#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_access.$$
tmp2=/tmp/scan_access2.$$

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


#CREATE TABLE interfaces (
#          id        integer primary key autoincrement,
#          macid     string,
#          ip        string,
#          hostname  string
#        , access);
#
sqlite3 -separator ' ' $database 'SELECT id,ip,access FROM interfaces'  > $tmp

sort -u $tmp |  while read id ip oldaccess ; do
	echo "Access for $ip"
	access=none
	if [ "$oldaccess" = "" ] ; then
		if nmap -p 22 $ip | grep -q 22.tcp ; then
			echo -n '.'
			echo hop | timeout 2 ssh  -o PasswordAuthentication=no -o ConnectTimeout=2  $ip 'echo hop' 2>/dev/null  > $tmp2
			echo -n '.'
			echo hop | timeout 2 ssh  -o PasswordAuthentication=no -o ConnectTimeout=2  root@$ip 'echo doasroot' 2>/dev/null  >>$tmp2
			echo -n '.'
			echo hop | timeout 2 ssh  -o PasswordAuthentication=no -o ConnectTimeout=2  admin@$ip 'echo doasadmin' 2>/dev/null  >>$tmp2
			echo  '.'
			if grep -q hop $tmp2 ; then
				access=ssh
			elif grep -q doasroot $tmp2 ; then
				access='ssh(root)'
			elif grep -q doasadmin $tmp2  ; then
				access='ssh(admin)'
			else
				echo hop |timeout 2  ssh  -o PasswordAuthentication=no -o ConnectTimeout=2  $ip 'sh ip int br' 2>&1 >>$tmp2
				if  grep -q Addr  $tmp2; then
					access=ssh
				fi
			fi
		fi
		sqlite3 $database "UPDATE interfaces SET access='$access' WHERE id=$id"
	fi
	echo "    $oldaccess $access"
done
rm -f $tmp $tmp2
