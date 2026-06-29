#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_access.$$   #list of vbox hosta
tmp1=/tmp/scan_access1.$$ #interfaceslist

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
arplist=/tmp/djedefre.arp.$$


list_interfaces | cut -d' ' -f1,2 > $tmp1


cat $tmp1 | while read if_id if_ip ; do
	if_host=$(valfromid interfaces $if_id host)
	if_access=$(valfromid interfaces $if_id access)
	srv_type=$(valfromid server $if_host type)
	srv_name=$(valfromid server $if_host name)
	if cmd_on $if_id which vboxmanage  | grep -q vboxmanage 2>/dev/null ; then
		echo "Host  $srv_name ($if_host) is a vbox host"
		cmd_on $if_id vboxmanage list runningvms | sed "s/.*{//;s/}.*//;s/^/$if_host $if_id /" >> $serverlist  2>/dev/null 
	fi
done

echo "----------------------------------"
awk '!seen[$1, $3]++' $serverlist | while read -r vboxhost vboxif vboxid ; do
	if [ "$vboxid" != "" ] ; then
		tmpmac=''
		vboxmac=''
		client_if_id=''
		client_srv_id=''
		client_srv_name=''
		tmpmac=$(cmd_on $vboxif "VBoxManage showvminfo $vboxid  --machinereadable" | sed -n 's/"//g;s/^macaddress[0-9]*=//p' | head -1)
		vboxmac=$(echo $tmpmac | sed -E 's/(..)(..)(..)(..)(..)(..)/\1:\2:\3:\4:\5:\6/' | tr 'A-Z' 'a-z')
		client_if_id=$(idfromval interfaces macid "$vboxmac")
		if [ "$client_if_id" != "" ] ; then
			client_srv_id=$(valfromid interfaces $client_if_id host)
			client_srv_name=$(valfromid server $client_srv_id name)
			srv_options=$(optfromid server $client_srv_id)
			srv_options=$(setvarstring vboxhost $vboxhost "$vboxhost")
echo "$srv_options"
			setfromid server $client_srv_id options "$srv_options"
		fi
		echo "----------------------------------"
	fi
done
	
rm -f $vboxlist $serverlist $arplist  $tmp $tmp1
exit




			sed 's/^/serverlist: /'  "$serverlist"
			sed 's/^"//;s/".*//' "$serverlist"| while read vbox ; do
				if [ "$vbox" != "" ] ; then
					echo "  vbox: $vbox:"
					echo hop|$sshcmd$interface "vboxmanage showvminfo '$vbox'"> $vboxlist
					sed 's/^/  vboxlist:/' $vboxlist
					vboxmac=$(grep 'MAC: ' "$vboxlist" | sed  's/,.*//;s/.*MAC: //;s/.\{2\}/&:/g;s/:$//;' |tr [:upper:] [:lower:]|head -1)
					#vboxip=$(echo hop|$access $interface "VBoxManage guestproperty get '$vbox'  /VirtualBox/GuestInfo/Net/0/V4/IP"| sed 's/.*: *//')
					vboxid=''
					vboxip=''
					echo "    boxmac=$vboxmac vboxip=$vboxip vboxid=$vboxid"
					if [ "$vboxmac" != "" ] ; then
						vboxid=$(sqlite3 $database  "SELECT host FROM interfaces WHERE macid='$vboxmac'")
						vboxip=$(sqlite3 $database  "SELECT ip FROM interfaces WHERE macid='$vboxmac'")
					fi
					echo "    vboxmac=$vboxmac vboxip=$vboxip vboxid=$vboxid"
					if [ "$vboxid" != "" ] ; then
					#	if grep -qi 'stat.*run' "$vboxlist" ; then
							echo -n " _______----> "
							sqlite3 $database  "SELECT options FROM server WHERE id=$vboxid"
							if sqlite3 $database  "SELECT options FROM server WHERE id=$vboxid" | grep -q "vboxhost:" ; then
								echo -n "on right host: "
								sqlite3 $database  "SELECT options FROM server WHERE id=$vboxid"
								echo "    Already on the right host"
							else
								prevopt=$(sqlite3 $database  "SELECT options FROM server WHERE id=$vboxid")
								sqlite3 $database  "UPDATE server SET options='vboxhost:$vboxhostid,$prevopt' WHERE id=$vboxid"
								sqlite3  $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
							fi
						fi
					#fi
				fi
			done
		fi
	fi
done


sqlite3 -separator '	' $database  "SELECT * FROM server"  | grep vbox


rm -f $vboxlist $serverlist  $tmp $tmp1
