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
	date
	timeout 300 bash $SCRIPTPATH/scan_$script.sh $dbfile 2>&1 | sed "s/^/$script: /" 2>&1
	if [ $? = 124 ] ; then
		echo "-----$script killed"
	else
		echo "-----$script DONE"
	fi
	if [ $enter = yes ] ; then
		read line
	fi
done

for script in page_*.sh ; do
	echo "-----STARTING $script"
	date
	timeout 300 bash $SCRIPTPATH/$script $dbfile | sed "s/^/$script: /" 2>&1
	if [ $? = 124 ] ; then
		echo "-----$script killed"
	else
		echo "-----$script DONE"
	fi
	if [ $enter = yes ] ; then
		read line
	fi
done
