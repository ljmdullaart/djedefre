#!/bin/bash

tmp=/tmp/scan_remote_server.$$
tmp2=/tmp/scan_remote_server.$$.2
iflstfile=/tmp/scan_remote_server.$$.3


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
		shift
	else
		echo "Database=$database, not $1"
	fi
fi


if [ "$1" = "" ] ; then
        list_interfaces | awk '{print $1}' > $iflstfile

else
        echo $1 > $iflstfile
fi


for if_id in $(cat $iflstfile) ; do
	echo "Interface $if_id:"
	cidr=''
	serverid=$(valfromid interfaces $if_id host)
	servername=$(valfromid server $serverid name)
	if cmd_on $if_id which ip | grep -q ip ; then
		echo "    ip addr on $servername"
		cmd_on $if_id  ip -o addr |
			grep -v '127.0.0.1'  |
			sed  's/\// /g'      |
			sed 's/^/        /'
			ifname=''
		cmd_on $if_id  ip -o addr |
			grep -v '127.0.0.1'  |
			sed  's/\// /g'      |
			grep -v '^$'         |
			while read seq ifname type ip rcidr rest ; do
				if [ "$type" = "inet" ] ; then
					echo "        read ip=$ip  rcidr=$rcidr"
					echo "        add interface  $ip $serverid"
					declare -A interface_data
					interface_data[ip]="$ip"
					interface_data[host]="$serverid"
					interface_data[ifname]="$ifname"
					interface_data[source]="scan_remote_system"
					set_interface interface_data
					unset interface_data
					this_if=$(idfromval interfaces ip "$ip" | head -1)
					if [ "$rcidr" != "" ] ; then
						nwaddr=$(ipcalc $ip/$rcidr | sed -n 's/\/.*//;s/^Network:\s*//p')
						echo "    add subnet $nwaddr $rcidr"
						declare -A subnet_data
						subnet_data[nwaddress]="$nwaddr"
						subnet_data[cidr]="$rcidr"
						subnet_data[source]=scan_remotesystem
						set_subnet subnet_data
						unset subnet_data
						echo "     $nwaddr $rcidr added"
					fi
				fi
				rcidr=''
				ifname=''
			done
	elif $sshcmd$interface which ifconfig | grep -q ifconfig ; then
		ifname=''
		echo "    ifconfig"
		cmd_on $if_id ifconfig               |
		  #sed 's/: / /;:a;N;$!ba;s/\n[ \t]/ /g'  |
		  #grep -v '127.0.0.1'                    |
		  #grep -v '^$'                           |
		  #while read ifname flags labm mtu inet ip nm mask rest ; do
		  awk '	/^[a-z]/	{ interface = $1 }
			/^[ \t]*inet /	{ ip[interface] = $2 ; mask[interface] = $4}
			/^[ \t]*ether /	{ mac[interface] = $2 }
			END		{ for (i in ip) { print i, ip[i], mask[i], mac[i] } }
		  ' |
		  grep -v 'lo' |
		  while read ifname ip mask mac ; do
			echo "    add interface  $ip $serverid"
			declare -A interface_data
			interface_data[ip]="$ip"
			interface_data[host]="$serverid"
			interface_data[ifname]="$ifname"
			interface_data[macid]="$mac"
			interface_data[source]="scan_remote_system"
			set_interface interface_data
			unset interface_data
			nwaddr=$(ipcalc $ip/$mask | sed -n 's/\/.*//;s/^Network:\s*//p')
			rcidr=$(ipcalc -b $ip/$mask | sed -n 's/Netmask:.*= //p')
			echo "    add subnet $nwaddr $rcidr"
			declare -A subnet_data
			subnet_data[nwaddress]="$nwaddr"
			subnet_data[cidr]="$rcidr"
			subnet_data[source]=scan_remotesystem
			set_subnet subnet_data
			unset subnet_data
			echo "     $nwaddr $rcidr"
			ifname=''
		done
	fi

done


rm -f $tmp
rm -f $tmp2
rm -f $iflstfile


