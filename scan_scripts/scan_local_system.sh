#!/bin/bash


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
djedefre_log "############################ scan local system ##########################################"

#            _     _                                                             
#   __ _  __| | __| |  _ __ ___   ___    __ _ ___   ___  ___ _ ____   _____ _ __ 
#  / _` |/ _` |/ _` | | '_ ` _ \ / _ \  / _` / __| / __|/ _ \ '__\ \ / / _ \ '__|
# | (_| | (_| | (_| | | | | | | |  __/ | (_| \__ \ \__ \  __/ |   \ V /  __/ |   
#  \__,_|\__,_|\__,_| |_| |_| |_|\___|  \__,_|___/ |___/\___|_|    \_/ \___|_|   
# 

djedefre_log "Adding local server"
me=$(hostname -s)

declare -A server_data
server_data[name]="$me"
server_data[source]="scan_localhost"
server_data[status]="up"
server_data[type]="server"
server_data[xcoord]=100
server_data[ycoord]=100
set_server server_data
unset server_data
serverid=$db_retval

djedefre_log "local server =$serverid"

#  _       _             __                                       _ 
# (_)_ __ | |_ ___ _ __ / _| __ _  ___ ___  ___    __ _ _ __   __| |
# | | '_ \| __/ _ \ '__| |_ / _` |/ __/ _ \/ __|  / _` | '_ \ / _` |
# | | | | | ||  __/ |  |  _| (_| | (_|  __/\__ \ | (_| | | | | (_| |
# |_|_| |_|\__\___|_|  |_|  \__,_|\___\___||___/  \__,_|_| |_|\__,_|
#                                                                   
#            _                _       
#  ___ _   _| |__  _ __   ___| |_ ___ 
# / __| | | | '_ \| '_ \ / _ \ __/ __|
# \__ \ |_| | |_) | | | |  __/ |_\__ \
# |___/\__,_|_.__/|_| |_|\___|\__|___/
#  

interfacelist=$(ip addr |
	grep -v '127.0.0.1' |
	grep -v ' ::1' |
	sed -n 's/.*inet \(.*\)\/\(.*\) brd.*/\1 \2/p' 
	)

djedefre_log  "Found interfaces:"
djedefre_log  "$interfacelist"
echo

ip route show | grep "via" | awk '{print $5}' | sort -u | while read -r iface; do
    ip -o -4 addr show "$iface" | awk '{print $2, $4}' | while read -r name ip_mask; do
        # Splits IP en Subnet (bijv. 192.168.1.10/24 -> 192.168.1.10 192.168.1.0/24)
        ip_addr=$(echo $ip_mask | cut -d/ -f1)
        subnet=$(ip route show dev "$name" | grep "proto kernel" | awk '{print $1}' | head -n1)
        djedefre_log  "$name $ip_addr $subnet"
    done
done 

ip addr | sed -n 's/\w*: \([[:alnum:]]*\).*/\1/p'  | sort -u |
	while read ifname ip mycidr ; do
		read ip mycidr <<< $(ip -o -f inet addr show $ifname | awk '{print $4}' | sed 's/\// /')
		echo "serverid=$serverid ip=$ip cidr=$mycidr"
		if [ "$mycidr" != '' ] ; then
			echo "   serverid=$serverid ip=$ip cidr=$mycidr"
			nwaddress=$(ipcalc $ip/$mycidr | sed -n 's/\/.*//;s/^Network:\s*//p')
			echo "   serverid=$serverid ip=$ip nwaddr=$nwaddress cidr=$mycidr"
			declare -A subnet_data
			subnet_data[nwaddress]="${nwaddress// /}"
			subnet_data[cidr]="$mycidr"
			subnet_data[name]="$nwaddress"
			subnet_data[source]="scan_localsystem"
			set_subnet subnet_data
			subnetid=$db_retval
			djedefre_log "Added subnet $nwaddress/$cidr: $subnetid"

			declare -A interface_data
			interface_data[ip]="${ip// /}"
			interface_data[host]="$serverid"
			interface_data[subnet]="$subnetid"
			interface_data[macid]=$(ip addr show | grep -B1 "inet $ip/" | grep -oP 'link/ether \K[^ ]+')
			interface_data[ifname]=$(ip -o addr show | awk -v ip="$ip" '$4 ~ "^"ip"/" {print $2}')
			interface_data[source]="scan_localsystem"
			set_interface interface_data
			djedefre_log "Added interface $ip ($ifname) - $host on  $subnetid"

			subnet_data[access]="$db_retval"
			set_subnet subnet_data

			unset interface_data 
			unset subnet_data
			
		fi
		mycidr=''
	done



