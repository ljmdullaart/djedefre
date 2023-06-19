#!/bin/bash

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

for script in local_system subnet arp access type server dhcp  status remote_system cisco dns dhcp arp  vbox  status local_system internet  status
do
	bash $SCRIPTPATH/scan_$script.sh $dbfile
	echo "$script done"
done

if [ -f webserver/database/djedefre.db ] ; then
	cp $dbfile webserver/database/djedefre.db
fi


exit 0
all_scan.sh
djedefre.common.sh
djedefre.db
loopscan.sh
scan_access.sh
scan_arp.sh
scan_cisco.sh
scan_dns.sh
scan_internet.sh
scan_placeongrid.sh
scan_remote_system.sh
scan_server.sh
scan_short_hostnames.sh
scan_status.sh
scan_subnet.sh
scan_type.sh
scan_vbox.sh
scan_zz_database_integrity.sh
status.check.log
status_aesopos.sh
status_laserjet.sh
status_ronsard.sh
