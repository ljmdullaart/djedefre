#!/bin/bash

#log=log_subnet


if [ -f /usr/local/bin/djedefre.common ] ; then
	. /usr/local/bin/djedefre.common
fi
if [ -f /opt/djedefre/bin/djedefre.common ] ; then
	. /opt/djedefre/bin/djedefre.common
fi
if [ -f djedefre.common.sh ] ; then
	. djedefre.common.sh
fi

date > $log

for subnet in $(sqlite3 -separator '/' "$database" "SELECT nwaddress,cidr FROM subnet WHERE cidr > 23") ; do
	echo "$subnet" >> "$log"
	for ip in $(fping -a -q -g "$subnet") ; do
		add_if $ip
	done
done

for server_id in $(sqlite3 "$database" "SELECT id FROM server") ; do
	qif=$(sqlite3 "$database" "SELECT COUNT(ALL)  FROM interfaces WHERE host=$server_id")
	if [ "$qif" -gt 1 ] ; then
		for int_id in $(sqlite3 "$database" "SELECT id FROM interfaces WHERE host=$server_id") ; do
			thishost=0
			ifip=$(sqlite3 "$database" "SELECT ip from interfaces WHERE id=$int_id")
			access=$(sqlite3 "$database" "SELECT access from interfaces WHERE id=$int_id")
			if [[ $access =~ 'ssh' ]] ; then
				if $access $ifip test -f /usr/bin/fping ; then
					echo "fping available on $ifip">> "$log"
					for subnet in $(sqlite3 -separator '/' "$database" "SELECT nwaddress,cidr FROM subnet WHERE cidr > 23") ; do
						if [ "$thishost" = 0 ] ; then
							echo "$subnet on $ifip">> "$log"
							echo $access $ifip fping -a -q -g "$subnet">> "$log"
							$access $ifip fping -a -q -g "$subnet"
							$access $ifip fping -a -q -g "$subnet" | while read ip ; do
								echo "     add $ip">> "$log"
								add_if $ip
							done
						fi
					done
				fi
				thishost=1
			fi
		done
	fi
done

# Remove interfaces without IP address
sqlite3 $database "DELETE FROM interfaces WHERE ip='';"

