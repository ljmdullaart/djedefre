#!/bin/bash

enter=no
if [ "$1" = "-k" ] ; then
	enter=yes
fi

if [ "a" = 'b' ] ; then 
	:
elif [ -f database/djedefre.db ] ;  then
	dbfile=$(realpath database/djedefre.db)
elif [ -f ../database/djedefre.db ] ; then
	dbfile=$(realpath ../database/djedefre.db)
elif [ -f djedefre.db ] ;  then
	dbfile=$(realpath djedefre.db)
elif [ -f ../djedefre.db ] ; then
	dbfile=$(realpath ../djedefre.db)
else
	dbfile=/home/ljm/src/djedefre/database/djedefre.db
fi
cd /home/ljm/src/djedefre/scan_scripts

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

for script in local_system subnet arp access type server dhcp  remote_system cisco dns dhcp arp  vbox  local_system internet  clean_if l2top l2unifi l2vbox ifconnect
do
	echo "-----STARTING $script"
	timeout 300 bash $SCRIPTPATH/scan_$script.sh $dbfile | sed "s/^/$script: /" 2>&1
	echo "-----$script DONE"
	if [ $enter = yes ] ; then
		read line
	fi
done

for script in Cloud all_servers clean complete l2top  ; do
	echo "-----STARTING $script"
	timeout 300 bash $SCRIPTPATH/page_$script.sh $dbfile | sed "s/^/$script: /" 2>&1
	echo "-----$script DONE"
	if [ $enter = yes ] ; then
		read line
	fi
done
