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

now=$(date +%s)
serverlist=/tmp/djedefre.serverlist.$$
vboxlist=/tmp/djedefre.vbox.$$


sqlite3 -separator ' ' $database  'SELECT ip,host,access FROM interfaces' | 
while read interface vboxhostid access ; do
	if [ "$access" = "" ] ; then
		:
	elif [ "$access" = "none" ] ; then
		:
	else
		echo "Testing $interface:"
		echo $access $interface "ls -l  /usr/bin/vboxmanage"
		if echo hop|$access $interface test -e /usr/bin/vboxmanage ; then
			echo "Host  $vboxhostid is a vbox host"
			echo hop|$access $interface vboxmanage list vms >"$serverlist" 2>/dev/null
			sed 's/^"//;s/".*//' "$serverlist"| while read vbox ; do
				if [ "$vbox" != "" ] ; then
					echo "  $vbox:"
					echo hop|$access $interface "vboxmanage showvminfo '$vbox'"> $vboxlist
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
							if sqlite3 $database  "SELECT options FROM server WHERE id=$vboxid" | grep -q "vboxhost:$vboxhostid," ; then
								echo -n "on right host: "
								sqlite3 $database  "SELECT options FROM server WHERE id=$vboxid"
								echo "    Already on the right host"
							else
								prevopt=$(sqlite3 $database  "SELECT options FROM server WHERE id=$vboxid")
								sqlite3 $database  "UPDATE server SET options='vboxhost:$vboxhostid,$prevopt' WHERE id=$vboxid"
							fi
						fi
					#fi
				fi
			done
		fi
	fi
done


sqlite3 -separator '	' $database  "SELECT * FROM server"  | grep vbox


rm -f $vboxlist $serverlist 
