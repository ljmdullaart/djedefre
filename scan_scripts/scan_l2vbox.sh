#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_tmp.$$

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


now=$(date +%s)
serverlist=/tmp/djedefre.serverlist.$$
vboxlist=/tmp/djedefre.vbox.$$



vboxhosts=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' $database "SELECT DISTINCT options FROM server" | sed -n 's/.*vboxhost:\([0-9]*\).*/\1/p')

sqlite3 -cmd ".timeout 1000" $database  "
	DELETE FROM l2connect WHERE source='l2vbox'
	"
for vboxhost in $vboxhosts ; do
	# get an interface that can be accessed
	vboxif=none
	vboxifs=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' $database "SELECT ip FROM interfaces WHERE host=$vboxhost")
	for interface in $vboxifs ; do
		if [ "$(ssh -o ConnectTimeout=2 $interface  echo hop)" = hop ] ; then
			vboxif=$interface
		fi
	done
	if [ "$vboxif" != "none" ] ; then
		# Get a list of all VMs and store them in an array
		mapfile -t vms < <(ssh $vboxif VBoxManage list vms | sed 's/"//g')

		# Get a list of all host-only interfaces and store them in an array
		mapfile -t hostonlyifs < <(ssh $vboxif VBoxManage list hostonlyifs | grep "^Name:" | cut -d ':' -f 2 | sed 's/^[ \t]*//')

		# Iterate through each VM
		for vm in "${vms[@]}"; do
			vm_name=$(echo "$vm" | cut -d ' ' -f 1)
			ssh $vboxif VBoxManage showvminfo "$vm_name" --machinereadable > $tmp 2>/dev/null
			for i in $(seq 1 8) ; do
				toif=''
				if grep -qi "nic$i=\"bridged" $tmp ; then
					toif=$(sed -n "s/bridgeadapter.*=\"\(.*\)\".*/\1/p" $tmp)
					frommac=$(sed -n "s/macaddress$i=\"\(.*\)\".*/\1/p" $tmp )
					frommac=$(echo $frommac| tr ABCDEF abcdef)
					frommac=$(echo $frommac| sed 's/../&:/g; s/:$//')
					fromifid=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' $database "SELECT id FROM interfaces WHERE macid='$frommac'")
					toifid=$(sqlite3 -cmd ".timeout 1000"  -separator ' ' $database "SELECT id FROM interfaces WHERE host=$vboxhost AND ifname='$toif'")
					if [ "$fromifid" != "" ] && [ "$toifid" != "" ] ; then
						echo "$vboxhost;$vm_name;$toif;$frommac;$fromifid;$toifid"
						sqlite3 -cmd ".timeout 1000" $database  "
							INSERT INTO l2connect(from_tbl,from_id,to_tbl,to_id,source)
							VALUES ('interfaces',$fromifid,'interfaces',$toifid,'l2vbox')
						"
					else
						echo "NOT vboxhost=$vboxhost;vm_name=$vm_name;toif=$toif;frommac=$frommac;fromifid=$fromifid;toifid=$toifid"
#id          vlan        from_tbl    from_id     from_port   to_tbl      to_id       to_port     source  
					fi

				fi
			done
		done 
	fi
done


rm -f $vboxlist $serverlist $tmp
