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
fi
clean=0
if [ "$1" = "-c" ] ; then
	clean=1
	shift
fi

if [ "$1" != '' ] ; then
	if [ -f "$1" ] ; then
		database="$1"
	else
		echo "Database=$database, not $1"
	fi
fi


list_interfaces > $tmp

sort -u $tmp |  while read id rest; do
	djedefre_log "Access for $id: $ip"
	ip=$(valfromid interfaces $id  ip)
	oldaccess=$(valfromid interfaces $id  access)
	djedefre_log "Access for $id: $ip (was: $oldaccess)"
	access=none
	if [ "$oldaccess" = "none" ] ; then
		oldaccess=''	#try again
	fi
	if [ "$oldaccess" = "" ] ; then
		if nmap -p 22 $ip | grep -q 22.tcp ; then
			echo -n '.'
			echo hop | timeout 6 ssh  -o PasswordAuthentication=no -o ConnectTimeout=4  $ip 'echo hop' 2>/dev/null  > $tmp2
			echo -n '.'
			echo hop | timeout 6 ssh  -o PasswordAuthentication=no -o ConnectTimeout=4  root@$ip 'echo doasroot' 2>/dev/null  >>$tmp2
			echo -n '.'
			echo hop | timeout 6 ssh  -o PasswordAuthentication=no -o ConnectTimeout=4  admin@$ip 'echo doasadmin' 2>/dev/null  >>$tmp2
			echo  '.'
			if grep -q hop $tmp2 ; then
				access=ssh
			elif grep -q "doasroot" $tmp2 ; then
				access='ssh(root)'
			elif grep -q doasadmin $tmp2  ; then
				access='ssh(admin)'
			else
				echo hop |timeout 4  ssh  -o PasswordAuthentication=no -o ConnectTimeout=4  $ip 'sh ip int br' 2>&1 >>$tmp2
				if  grep -q Addr  $tmp2; then
					access=ssh
				elif [ -f /usr/local/bin/dotelnet ] ; then
					timeout 4  dotelnet $ip sh ip int br |grep -v Credentials| sed 's/^/OUTPUT/' >$tmp2
					if grep -q OUTPUT $tmp2 ; then
						access=dotelnet
					fi
					
				fi
			fi
		fi
		echo "$ip $access"
		declare -A interface_data
		interface_data[ip]="$ip"
		interface_data[access]="$access"
		set_interface interface_data
		unset interface_data
	elif [ "$oldaccess" = "dotelnet" ] ; then
		timeout 4  dotelnet $ip sh ip int br |grep -v Credentials| sed 's/^/OUTPUT/' >$tmp2
		if grep -q OUTPUT $tmp2 ; then
			echo "Verified: $ip access dotelnet"
		else
			setfromid interfaces $id access none
			echo "please rerun for $ip; no telnet"
		fi
	elif [ "$oldaccess" = "ssh" ] ; then
		echo hop | timeout 6 ssh  -o PasswordAuthentication=no -o ConnectTimeout=4  $ip 'echo hop' 2>/dev/null  > $tmp2
		if grep -q hop $tmp2 ; then
			echo "Verified: $ip access ssh"
		else
			setfromid interfaces $id access none
			echo "please rerun for $ip; no ssh"
		fi
	elif [ "$oldaccess" = "ssh(root)" ] ; then
		echo hop | timeout 6 ssh  -o PasswordAuthentication=no -o ConnectTimeout=4  root@$ip 'echo hop' 2>/dev/null  > $tmp2
		if grep -q hop $tmp2 ; then
			echo "Verified: $ip access ssh(root)"
		else
			setfromid interfaces $id access none
			echo "please rerun for $ip, no ssh root"
		fi
	elif [ "$oldaccess" = "ssh(admin)" ] ; then
		echo hop | timeout 6 ssh  -o PasswordAuthentication=no -o ConnectTimeout=4  admin@$ip 'echo hop' 2>/dev/null  > $tmp2
		if grep -q hop $tmp2 ; then
			echo "Verified: $ip access ssh(admin)"
		else
			setfromid interfaces $id access none
			echo "please rerun for $ip; no ssh admin"
		fi
	
	fi
	echo "    $oldaccess $access"
done
rm -f $tmp $tmp2
