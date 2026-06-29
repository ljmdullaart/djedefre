#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_access.$$

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


declare -A subnet_data
subnet_data[name]="Internet"
subnet_data[nwaddress]="Internet"
set_subnet subnet_data
internetsn_id=$dbretval
unset subnet_data


tmpfile=/tmp/scan_internet.$$
tmpfile2=/tmp/scan_internet2.$$

traceroute 8.8.8.8                |
	grep ms                   |
	sed -n 's/.*(//;s/).*//p' >>$tmpfile2

lastif=$( ip route get 8.8.8.8 | sed -n 's/.*src //;s/ .*//;1p')
lastif_id=$(idfromval interfaces ip "$lastif" )
if [ "$lastif_id" = "" ] ; then
	echo "Cannot determine the last host before Internet"
	exit 
fi

path="$lastif"
pathif_id=$(idfromval interfaces ip "$lastif" )
pathif_host=$(valfromid interfaces $pathif_id host)

for ip in $(cat $tmpfile2) ; do
	nextif_id=$(idfromval interfaces ip "$ip")
	echo -n "SCAN INTERNET  $ip-> $next ; "
	if [ "$nextif_id" != "" ] ; then
		nextif_host=$(valfromid interfaces $nextif_id host)
		nextsrv_name=$(valfromid server $nextif_host name)
		lastif=$ip
		lastif_id=$nextif_id
		path="$path:$nextsrv_name"
		idpath="$idpath:$nextif_host"
	fi
	echo "lastif=$lastif"
done

rm -f $tmpfile
rm -f $tmpfile2

echo $path

echo "Path=$path"
echo "Idpath=$idpath"
set_dbconfig 'run:param' 'idpath' "$idpath"

internetsn_id=$(idfromval subnet nwaddress Internet)
echo  "subnet : $internetsn_id"
echo  "host nr: $nextif_host"
echo  "host   : $nextsrv_name"
echo  "ip     : Internet"
echo  "path   : $path"



declare -A interface_data
interface_data[ip]="Internet"
interface_data[host]="$nextif_host"
interface_data[subnet]="$internetsn_id"
set_interface interface_data
unset interface_data
