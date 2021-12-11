#!/bin/bash


if [ -f /usr/local/bin/djedefre.common ] ; then
	. /usr/local/bin/djedefre.common
fi
if [ -f /opt/djedefre/bin/djedefre.common ] ; then
	. /opt/djedefre/bin/djedefre.common
fi
if [ -f djedefre.common.sh ] ; then
	. djedefre.common.sh
fi

allarps=/tmp/allarps.$$

sqlite3 $database "select access||ip from interfaces where access like 'ssh%';" | while read line; do
	arpcmd=''
	if echo hop | $line test -f /sbin/arp ; then arpcmd='/sbin/arp -a '
	elif echo hop | $line test -f /usr/sbin/arp ; then arpcmd='/usr/sbin/arp -a '
	elif echo hop | $line test -f /usr/bin/arp ; then arpcmd='/usr/bin/arp -a '
	fi
	if [ "$arpcmd" = "" ] ; then
		:
	else
		echo $line  $arpcmd >> $allarps
	fi


done 

bash $allarps | sed 's/.*(//;s/) at /;/;s/ .*//;s/;/ /' 


bash $allarps | sed 's/.*(//;s/) at /;/;s/ .*//;s/;/ /' |
	grep -v incomplete | 
	while read ip mac ; do
		add_if $ip
		sqlite3 $database "UPDATE interfaces SET macid='$mac' WHERE ip='$ip'";
	done


rm -f $allarps
