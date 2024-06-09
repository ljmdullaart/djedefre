#!/bin/bash

tmp=/tmp/scan_server.$$
tmp1=/tmp/scan_server.$$.1
tmp2=/tmp/scan_server.$$.2


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

sqlite3  -separator ' ' -cmd ".timeout 1000" "$database" "SELECT id,ip,access FROM interfaces" > $tmp

grep ssh $tmp |
	while read id ip access ; do
		echo "Scan server for $ip"
		if [[ "$access" == *"root"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 root@'
		elif [[ "$access" == *"admin"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 admin@'
		else
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 '
		fi
		echo hop| $sshcmd$ip ip addr 2>&1 | sed -n 's/\/.*//;s/.*inet //p' > $tmp2
		echo hop| $sshcmd$ip ifconfig 2>&1 |sed -n 's/.*inet \(.*\) netmask \(.*\) br.*/\1 \2/p' >>$tmp2
		echo hop| $sshcmd$ip ifconfig 2>&1 |sed -n 's/.*inet addr://;s/ .*Mask:.*//p' >>$tmp2
		lhost=$(echo hop| $sshcmd$ip hostname -s)
		srvid=''
		srvname=$(grep -v 127.0.0.1  $tmp2 | sed 's/ .*//' | sort -un | tail -1)
		rm -f $tmp1
		for ifip in $(grep -v 127.0.0.1  $tmp2 | sed 's/ .*//') ; do
			nslookup $ifip 2>&1 | grep -v NXDOMAIN | sed -n "s/.$//;s/.*= /$ifip /p" >> $tmp1
			newhost=$(nslookup $ifip 2>&1 | grep -v NXDOMAIN | sed -n "s/.$//;s/.*= //p")
			newsrvid=$(sqlite3 -cmd ".timeout 1000" "$database" "SELECT host FROM interfaces WHERE ip='$ifip'")
			if [[ "$srvname" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
				if [ "$newhost" != "" ] ; then
					srvname="$newhost"
				fi
			else
				if [[ "$newhost" == $lhost.* ]] ; then
					srvname="$newhost"
				fi
			fi

			if [ "$srvid" = "" ] ; then
				if [ "$newsrvid" != "" ] ; then
					srvid="$newsrvid"
				fi
			fi
		done
		if [ "$srvid" = "" ] ; then
			if [ "$srvname" != "" ] ; then
				add_server $srvname
				sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
				srvid=$db_retval
			fi
		fi
		if [ "$srvid" != "" ] ; then
			for interface in $(cat $tmp2) ; do
				add_if $interface $srvid
				sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
			done
		fi

	done

# all not-assigned interfaces become server as well

sqlite3 -cmd ".timeout 1000" "$database" "SELECT ip FROM interfaces WHERE host IS NULL" > $tmp

cat $tmp | while read ifip ; do
	newhost=$(nslookup $ifip 2>&1 | grep -v NXDOMAIN | sed -n "s/.$//;s/.*= //p")
	if [ "$newhost" = "" ] ; then
		newhost=$ifip
	fi
	add_server $newhost
	srvid=$db_retval
	add_if $ifip $srvid
	sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
done

# Try to name the hosts
sqlite3 -cmd ".timeout 1000" "$database" "SELECT name FROM server" > $tmp
cat $tmp | while read srvname ; do 
	if [[ "$srvname" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
		newname=$(host $srvname |  sed 's/.* //;s/\..*//;s/.*NXDOMAIN.*//')
		if [ "$newname" != "" ] ; then
			sqlite3 -cmd ".timeout 1000" "$database" "UPDATE server SET name='$newname' WHERE name='$srvname'"
			sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
		fi
	fi
done

# clean the hosts table
sqlite3 -cmd ".timeout 1000" "$database" "SELECT id from server " > $tmp
cat $tmp | while read srvid ; do 
	ifs=$(sqlite3 -cmd ".timeout 1000" "$database" "SELECT ip FROM interfaces WHERE host=$srvid")
	if [ "$ifs" = "" ] ; then
		sqlite3 -cmd ".timeout 1000" "$database" "DELETE FROM server WHERE id=$srvid"
		sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
	fi
done

rm -f $tmp
rm -f $tmp2
rm -f $tmp1
