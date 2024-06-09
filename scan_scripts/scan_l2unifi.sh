#!/bin/bash

nwhostfile=/tmp/scan_l2.$$
mcadumpfile=/tmp/scan_l2.$$.1
portmacvlan=/tmp/scan_l2.$$.2
lldpfile=/tmp/scan_l2.$$.3
tmp4=/tmp/scan_l2.$$.4


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

nwhosts=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT id FROM server WHERE devicetype='network'")
for hst in $nwhosts ; do
	sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT id,ip,access,host FROM interfaces WHERE host=$hst" >> $nwhostfile
done

touch $lldpfile

grep ssh $nwhostfile |
    while read my_id my_ip access my_host ; do
	>&2 echo  -n "Doing $my_ip"
	if [[ "$access" == *"root"* ]] ; then
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 root@'
	elif [[ "$access" == *"admin"* ]] ; then
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 admin@'
	else
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 '
	fi
	my_ifmac=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT macid FROM interfaces WHERE id=$my_id")
	if [ "$(echo hop| $sshcmd$my_ip echo test 2> /dev/null )" = test ] ; then
		if echo hop| $sshcmd$my_ip test -f /usr/bin/mca-dump  2>/dev/null >/dev/null ; then
			echo hop| $sshcmd$my_ip mca-dump > $mcadumpfile 2>/dev/null
			>&2 echo "	mca-dump"
			if jq -r '.lldp_table[] | "\(.chassis_id) \(.local_port_idx)"' $mcadumpfile  > /dev/null 2>&1 ; then
				jq -r '.lldp_table[] | "\(.chassis_id) \(.local_port_idx)"' $mcadumpfile  |
				    tr '[:upper:]' '[:lower:]' |
				    while read to_mac my_port ; do
					to_ip=$(sqlite3 -cmd ".timeout 1000" $database "SELECT ip FROM interfaces WHERE macid='$to_mac'"|head -1)
					if grep -q "$my_ifmac;$my_port;$to_mac;" $lldpfile ; then
						echo "already in file $my_ip $my_ifid $my_ifmac host $my_hostname port $my_port TO $to_ip $to_mac"
					elif grep -q "$to_mac;[0-9]*;$my_ifmac" $lldpfile ; then
						echo "reverse in file $my_ip $my_ifid $my_ifmac host $my_hostname port $my_port TO $to_ip $to_mac"
						sed -i "s/$to_mac;\([0-9]*\);$my_ifmac;[0-9]*$/$to_mac;\1;$my_ifmac;$my_port/"  $lldpfile
					else
						echo "not yet in file $my_ip $my_ifid $my_ifmac host $my_hostname port $my_port TO $to_ip $to_mac"
						echo "$my_ifmac;$my_port;$to_mac;" >> $lldpfile 
					fi
	
				done
			fi
			if grep "model_display" $mcadumpfile  | grep -q 'US' ; then
				cat  $mcadumpfile |
			   	jq -r '.port_table[] | "\(.port_idx) \(.mac_table[].mac)  \(.mac_table[].vlan)"' |
			   	sed "s/^/$my_id /" >>$portmacvlan
			fi
			if grep "model_display" $mcadumpfile  | grep -q 'UAP' ; then
				cat  $mcadumpfile  |
			   	jq '.vap_table[]' | sed -n 's/",//;s/.*"mac": "//p' |
			   	cat -n  |
			   	sed "s/^ */1000/;s/^/$my_id /;s/$/ 0/" >>$portmacvlan
			fi
		else
			>&2 echo "	Not a unifi"
		fi
	else
		>&2 echo "	Not a unifi"
	fi
done
nwips=$(grep ssh $nwhostfile | awk '{print $2}')
for ip in $nwips ; do
	
	ssh $ip ip link show |
	    sed -n  's/: <.*//;s/^[0-9]*: //p;s/ brd.*//;s/ *link.[a-z]* //p' |
	    paste -d ' ' - - |
	    sed -n 's/.*eth\([0-9]*\) \(.*\)/\2 \1/p' |
	    sort -u |
	    while read mac mport ; do
		sed -i "s/$mac;$/$mac;$mport/" $lldpfile
	done
done
	

tableize '-d;,' $lldpfile

sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "DELETE FROM l2connect WHERE source='l2unifi'"
sed 's/;/ /g' $lldpfile | sort -u | while read from_mac from_port to_mac to_port ; do
	if [ "$to_port" != "" ] ; then
		from_ifid=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT id FROM interfaces WHERE macid='$from_mac'"| head -1)
		to_ifid=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT id FROM interfaces WHERE macid='$to_mac'"| head -1)
		echo "INSERT INTO l2connect (from_tbl,from_id,from_port,to_tbl,to_id,to_port,source) VALUES ('interfaces',$from_ifid,$from_port,'interfaces',$to_ifid,$to_port,'l2unifi');" | tee -a logfile | sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" 
	else
		echo " $from_mac $from_port $to_mac $to_port:"
	fi
done

sort -u  -k2,2 -k4,4 $portmacvlan 







rm -f $nwhostfile $mcadumpfile $portmacvlan $lldpfile $tmp4
