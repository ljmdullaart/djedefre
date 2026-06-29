#!/bin/bash

tmpip=/tmp/scan_subnet.$$
tmpnets=/tmp/scan_subnet1.$$
tmpint=/tmp/scan_subnet2.$$

NOW=$(date -Iseconds | sed 's/+.*//')


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

list_subnet > $tmpnets


djedefre_log "Scan subnets"
sed 's/^/    /' $tmpnets
djedefre_log '-------------------'
egrep -v 'Internet|id' $tmpnets | cut -d' ' -f1-3  | while read id ip cidr ; do
		ip_scope=$(valfromid subnet $id scope)
		if [ "$ip_scope" = "local" ] || [ "$ip_scope" = "global" ] ; then
			echo -n .
			djedefre_log  "    $ip / $cidr"
			if [ "$cidr" != '' ] ; then
				if [ $cidr -gt 20 ] ; then
					sudo fping -g $ip/$cidr 2>&1 | sed -n "s/ is alive/ $id $ip_scope/p">> $tmpip
				fi
			fi
		fi
	done 
echo
djedefre_log "Add interfaces"
touch $tmpip

sort -u $tmpip | while read ip subnetid ip_scope; do
	declare -A interface_data
	interface_data[ip]="$ip"
	interface_data[ip_scope]="$ip_scope"
	interface_data[subnet]="$subnetid"
	interface_data[source]="scan_subnet"
	set_interface interface_data
	unset interface_data
	echo -n .
	
done
echo

idfrom_interfaces host NULL > $tmpint

cat $tmpint | while read interfaceid ; do
	ip=$(valfromid interfaces $interfaceid ip)
	name=$(host $ip | grep -v NXDOMAIN |sed 's/.* //;s/\..*//')
	if [ "$name" = "" ] ; then
		name="$ip"
	fi
	echo "$interfaceid: $ip $name"
	declare -A server_data

	server_data[name]="$name"
	server_data[type]="server"
	server_data[last_up]="$NOW"
	server_data[source]="scan_subnet"
	set_server server_data
	serverid=$db_retval
	unset server_data

	declare -A interface_data
	interface_data[ip]="$ip"
	interface_data[id]="$interfaceid"
	interface_data[host]="$serverid"
	interface_data[source]="scan_subnet"
	set_interface interface_data
	unset interface_data
	

	echo "$interfaceid: $ip $name server:$serverid in $db_retval"
done

rm -f $tmpip
rm -f $tmpnets
rm -f $tmpint
