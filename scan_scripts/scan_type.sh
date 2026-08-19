#!/bin/bash

tmp=/tmp/scan_typ.$$
tmp1=/tmp/scan_typ.$$.1
tmpnmap=/tmp/scan_typ.$$.2
avahi=/tmp/scan_typ.$$.avahi
iflstfile=/tmp/scan_typ.$$.iflstfile


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
		shift
	else
		echo "Database=$database, not $1"
	fi
fi




avahi-browse -a -r -t -p | cut -d';' -f4,5,6,7,8,10 > $avahi

if [ "$1" = "" ] ; then
	list_interfaces > $iflstfile

else
	echo $1 > $iflstfile
fi

sed 's/^/list_interfaces: /'  $iflstfile
cat $iflstfile |
	while read if_id if_ip rest ; do
		rm -f $tmp1
		echo '-----------------------------------------------'
		echo "Get type from $if_ip ($if_id)"
		if_host=$(valfromid interfaces $if_id host)
		echo "    host=$if_host"
		if [ "$if_host" != "" ] ; then
			oldtype=$(valfromid server $if_host type)
			if [ "$oldtype" = "server" ] ; then oldtype='' ; fi
			if [ "$oldtype" = "EMPTY" ] ; then oldtype='' ; fi
			if [ "$oldtype" = "NULL" ] ; then oldtype='' ; fi
			echo "    oldtype='$oldtype'"

			olddevtype=$(valfromid server $if_host devicetype)
			if [ "$olddevtype" = "EMPTY" ] ; then olddevtype='' ; fi
			if [ "$olddevtype" = "NULL" ] ; then olddevtype='' ; fi
			echo "    olddevtype='$olddevtype'"
			
			srv_name=$(valfromid server $if_host name)
			if_ip=$(valfromid interfaces $if_id ip)
			if [ "$oldtype" = "" ] || [ "$olddevtype" = "" ]  ; then 
				ntype=server
				ndevtype=server
				nmap $if_ip  > $tmpnmap
				sed 's/^/tmpnmap: /' $tmpnmap
				echo -n .
				cmd_on $if_id "show version" >> $tmp1 2>/dev/null
				echo -n .
				cmd_on $if_id "if [ -f /etc/banner ] ; then cat /etc/banner; fi" >> $tmp1 2>/dev/null
				echo -n .
				cmd_on $if_id "if [ -f /etc/motd ] ; then cat /etc/motd; fi" >> $tmp1 2>/dev/null
				echo -n .
				cmd_on $if_id "if [ -f /proc/sys/kernel/syno_hw_version ] ; then echo synology ; fi" >> $tmp1 2>/dev/null
				echo -n .
				cmd_on $if_id "if [ -f /etc/pf.os ] ; then echo 'ID=pfsense'; fi" >> $tmp1 2>/dev/null
				echo -n .
				cmd_on $if_id "if [ -f /etc/release ] ; then cat /etc/release ; fi" >> $tmp1 2>/dev/null
				echo .
				cmd_on $if_id "if [ -f /etc/os-release ] ; then cat /etc/os-release ; fi" >> $tmp1 2>/dev/null
				echo .
				cmd_on $if_id 'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName' >> $tmp1 2>/dev/null
				echo .
				grep "$if_ip;" $avahi | sed 's/^/avahi: /' 
				sed  's/^/tmp1: /' $tmp1
				if [ 1 = 2 ] ; then
					:
				elif curl -s --connect-timeout 3 $if_ip | grep -q "TP-LINK Technologies" ; then
					ntype=tplink
					ndevtype=network
				elif curl -s --connect-timeout 3 "http://$if_ip/api" | grep -q "P1 Meter" ; then
					ntype=meter
					ndevtype=appliance
				elif grep -i 'synology' $tmp1 ; then
					ntype=synology
					ndevtype=nas
				elif grep "$if_ip;" $avahi | grep -i laserjet ; then
					ntype=laserjet
					ndevtype=printer
				elif grep "$if_ip;" $avahi | grep -i 'pdl printer' ; then
					ntype=printer
					ndevtype=printer
				elif grep "$if_ip;" $avahi | grep -i 'unix printer' ; then
					ntype=printer
					ndevtype=printer
				elif grep "$if_ip;" $avahi | grep -i 'file sharing' ; then
					ndevtype=nas
					ntype=nas
					if grep "$if_ip;" $avahi | grep -i 'synology' ; then
						ntype=synology
					elif grep "$if_ip;" $avahi | grep -i 'qnap' ; then
						ntype=qnap
					fi
				elif grep "$if_ip;" $avahi | grep SAMBA ; then
					ndevtype=nas
					ntype=nas
					if grep "$if_ip;" $avahi | grep -i 'synology' ; then
						ntype=synology
					elif grep "$if_ip;" $avahi | grep -i 'qnap' ; then
						ntype=qnap
					fi
				elif grep "$if_ip;" $avahi | grep -i 'id=appliance' ; then
					ntype=appliance
					ndevtype=appliance
				elif nslookup $if_ip $if_ip > /dev/null 2>&1 ; then
					ntype=dns
					ndevtype=server
				elif  grep 'imap' $tmpnmap ; then
					ntype=mail 
					ndevtype=server
				elif grep  'Windows 11' $tmp1 ; then
					ntype=win11 
					ndevtype=server
				elif grep  'Windows 10' $tmp1 ; then
					ten=$(cmd_on $if_id reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ReleaseId)
					if [ "$ten" = "" ] ; then
						ntype=win11 
					else
						ntype=win10 
					fi
					ndevtype=server

				elif grep -i 'unifi' $tmp1 ; then
					ntype=unifi 
					ndevtype=network
				elif grep  'JFFSID=' $tmp1 ; then
					ntype=linux 
					ndevtype=server
				elif grep  'Windows 7' $tmp1 ; then
					ntype=win7 
					ndevtype=server
				elif grep  'ID=debian' $tmp1 ; then
					ntype=linux 
					ndevtype=server
				elif grep  'ID=linuxmint' $tmp1 ; then
					ntype=mint 
					ndevtype=server
				elif grep  'ID=raspbian' $tmp1 ; then
					ntype=raspberry 
					ndevtype=server
				elif grep  'ID=slackware' $tmp1 ; then
					ntype=slackware 
					ndevtype=server
				elif grep  'ID=ubuntu' $tmp1 ; then
					ntype=ubuntu 
					ndevtype=server
				elif grep  'ID=pfsense' $tmp1 ; then
					ntype=pfsense 
					ndevtype=network
				elif grep -i 'cisco ios' $tmp1 ; then
					ntype=cisco 
					ndevtype=network
				elif grep -iq 'os.*windows' $tmp1 ; then
					ntype=windows 
					ndevtype=pc
				elif curl -sq --connect-timeout 1  $if_ip | grep  tp-link ; then
					ntype=tplink
					ndevtype=network
				elif  grep '515.*print' $tmp1 ; then
					ntype=printer
					ndevtype=printer
				else 
					echo "Could not classify"
				fi
				echo "========> $ntype"
				if [ "$ntype" != "" ] ; then
					declare -A server_data
					server_data[id]="$if_host"
					server_data[name]="$srv_name"
					server_data[type]="$ntype"
					server_data[devicetype]="$ndevtype"
					set_server server_data
					unset server_data
				fi
	
			fi
		fi
	done


rm -f $tmp $tmp1 $tmpnmap $avahi $iflstfile

exit

