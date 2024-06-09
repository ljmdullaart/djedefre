#!/bin/bash

nwhostfile=/tmp/scan.$$		# list of hosts that are tagged as being a network host
mcadumpfile=/tmp/scan.$$.1	# mca-dump output from the current device
hostmac=/tmp/scan.$$.222	# space separated list of host-id,if-id, mac-id and IP from the interfaces table in the database.
portmacvlan=/tmp/scan.$$.3	# if-id-port-mac-vlan(or ssid) from MCA-dumps
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


sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT id FROM server WHERE devicetype='network'" > $nwhostfile
sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT host,id,macid,ip FROM interfaces" > $hostmac

sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "SELECT id FROM server WHERE options LIKE '%vbox%'" | 
while read vbox ; do
	sed -i "/^ *$vbox /d" $hostmac
done
	

sqlite3 -cmd ".timeout 1000"  -separator '/'  "$database" "SELECT nwaddress,cidr FROM subnet" | while read toping ; do
	fping -c1 -q -t100 -g "$toping"  &
done

wait



# first get the mca-dumps
cat $nwhostfile |
    while read host_id; do
	>&2 echo  -n "Doing $host_id"
	if [[ "$access" == *"root"* ]] ; then
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 root@'
	elif [[ "$access" == *"admin"* ]] ; then
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 admin@'
	else
		sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 '
	fi
	my_ip=$(sqlite3 -cmd ".timeout 1000" "$database" "SELECT ip FROM interfaces WHERE host='$host_id'"| head -1)
	my_id=$(sqlite3 -cmd ".timeout 1000" "$database" "SELECT id FROM interfaces WHERE host='$host_id'"| head -1)
	if [ "$(echo hop| $sshcmd$my_ip echo test 2> /dev/null )" = test ] ; then			# I can ssh to the host
		if echo hop| $sshcmd$my_ip test -f /usr/bin/mca-dump  2>/dev/null >/dev/null ; then	# There is an mca-dump program
			echo hop| $sshcmd$my_ip mca-dump > $mcadumpfile 2>/dev/null
			>&2 echo "	mca-dump"
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

grep 'b8:27:eb:c0:55:47' $portmacvlan | sed 's/^/A-/'


sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database"  "SELECT from_id, from_port FROM l2connect WHERE from_tbl='interfaces' AND source != 'ifconnect' " |
while read id port ; do
	sed -i "/ *$id  *$port /d" $portmacvlan
done
grep 'b8:27:eb:c0:55:47' $portmacvlan | sed 's/^/B-/'
sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database"  "SELECT to_id, to_port FROM l2connect WHERE to_tbl='interfaces' AND source != 'ifconnect' " |
while read id port ; do
	if [ "$port" != "" ] ; then
		sed -i "/ *$id  *$port /d" $portmacvlan
	fi
done
grep 'b8:27:eb:c0:55:47' $portmacvlan | sed 's/^/C-/'
sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database" "DELETE FROM l2connect WHERE source='ifconnect'"
cat $hostmac | while read hm_host hm_interface hm_mac hm_ip ; do
	if grep -q $hm_mac $portmacvlan ; then
		pm_ifid=$(grep $hm_mac $portmacvlan | head -1 | awk '{print $1}')
		pm_port=$(grep $hm_mac $portmacvlan | head -1 | awk '{print $2}')
		echo "INSERT INTO l2connect (from_tbl,from_id,from_port,to_tbl,to_id,to_port,source) VALUES ('interfaces',$pm_ifid,$pm_port,'interfaces',$hm_interface,'','ifconnect');"

	fi
done | sqlite3 -cmd ".timeout 1000"  -separator ' ' "$database"
sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"

rm -f $nwhostfile $mcadumpfile $hostmac $tmp4 $portmacvlan
