#!/bin/bash
#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_access.$$
tmp1=/tmp/scan_access1.$$

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


sqlite3 -separator ' ' $database  'SELECT ip,host,access FROM interfaces' > $tmp1

cat $tmp1 | 
while read interface vboxhostid access ; do
	type=$(sqlite3 -separator ' ' $database  "SELECT type FROM server WHERE id=$vboxhostid")
	if [ "$access" = "" ] ; then
		:
	elif [ "$access" = "none" ] ; then
		:
	elif [ "$type" = "cisco" ]  ; then
		:
	else
		if [[ "$access" == *"root"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 root@'
		elif [[ "$access" == *"admin"* ]] ; then
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 admin@'
		else
			sshcmd='ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 '
		fi
		echo "Testing if $interface contains a vbox manager:"
		if echo hop|$sshcmd$interface which vboxmanage ; then
			echo "Host  $vboxhostid is a vbox host"
			echo hop|$sshcmd$interface vboxmanage list vms > "$serverlist" 2>/dev/null
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
