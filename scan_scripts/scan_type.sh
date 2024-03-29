#!/bin/bash

tmp=/tmp/scan_typ.$$
tmp1=/tmp/scan_typ.$$.1
tmp2=/tmp/scan_typ.$$.2


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

sqlite3  -separator ' ' "$database" "SELECT id,ip,access FROM interfaces" > $tmp

cat $tmp |
	while read id ip access ; do
		echo "Get type from $ip"
		if [[ "$access" == *"root"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 root@'
		elif [[ "$access" == *"admin"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 admin@'
		elif [[ "$access" == *"ssh"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 '
		else
			sshcmd='true '
		fi
		host=$(sqlite3 "$database" "SELECT host FROM interfaces WHERE id=$id")
		if [ "$host" != "" ] ; then
			oldtype=$(sqlite3 "$database" "SELECT type FROM server WHERE id=$host")
			if [ "$oldtype" = "server" ] ; then oldtype='' ; fi
			if [ "$oldtype" = "EMPTY" ] ; then oldtype='' ; fi
			if [ "$oldtype" = "NULL" ] ; then oldtype='' ; fi
			echo "    oldtype='$oldtype'"

			olddevtype=$(sqlite3 "$database" "SELECT devicetype FROM server WHERE id=$host")
			if [ "$olddevtype" = "EMPTY" ] ; then olddevtype='' ; fi
			if [ "$olddevtype" = "NULL" ] ; then olddevtype='' ; fi
			echo "    olddevtype='$olddevtype'"

			if [ "$oldtype" = "" ] || [ "$olddevtype" = "" ]  ; then 
				ntype=server
				ndevtype=server

				echo date>$tmp1
				if [ "$sshcmd" = 'true ' ] ; then 
					sudo nmap -O $ip >> $tmp1
				fi
				echo hop|
					$sshcmd$ip "show version" >> $tmp1 2>/dev/null
				echo hop|
					$sshcmd$ip "if [ -f /etc/banner ] ; then  grep -i unifi /etc/banner; fi" >> $tmp1 2>/dev/null
				echo hop|
					$sshcmd$ip "if [ -f /etc/pf.os ] ; then echo 'ID=pfsense'; fi" >> $tmp1 2>/dev/null
				echo hop|
					$sshcmd$ip "if [ -f /etc/os-release ] ; then cat /etc/os-release ; fi" >> $tmp1 2>/dev/null
				sed -n  's/^ID=/    /p' $tmp1
				if grep -q 'ID=debian' $tmp1 ; then
					ntype=linux 
					ndevtype=server
				elif grep -q 'ID=linuxmint' $tmp1 ; then
					ntype=mint 
					ndevtype=server
				elif grep -q 'ID=raspbian' $tmp1 ; then
					ntype=raspberry 
					ndevtype=server
				elif grep -q 'ID=slackware' $tmp1 ; then
					ntype=slackware 
					ndevtype=server
				elif grep -q 'ID=ubuntu' $tmp1 ; then
					ntype=ubuntu 
					ndevtype=server
				elif grep -q 'ID=pfsense' $tmp1 ; then
					ntype=pfsense 
					ndevtype=network
				elif grep -iq 'unifi' $tmp1 ; then
					ntype=unifi 
					ndevtype=network
				elif grep -iq 'cisco ios' $tmp1 ; then
					ntype=cisco 
					ndevtype=network
				elif grep -iq 'os.*windows' $tmp1 ; then
					ntype=windows 
					ndevtype=pc
				elif curl -sq --connect-timeout 1  $ip | grep -q tp-link ; then
					ntype=tplink
					ndevtype=network
				else 
					echo "Could not classify"
					sed 's/^/    /' $tmp1
				fi
				if [ "$ntype" != "" ] ; then
					sqlite3 "$database" "UPDATE server SET type='$ntype' WHERE id=$host"
					sqlite3 "$database" "UPDATE server SET devicetype='$ndevtype' WHERE id=$host"
					sqlite3 "$database" "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
				fi
	
			fi
		fi
	done

rm -f $tmp $tmp1
