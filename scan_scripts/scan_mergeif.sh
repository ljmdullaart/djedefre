#!/bin/bash

tmp=/tmp/scan_merge.$$
tmp1=/tmp/scan_merge.$$.1


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


get_ipv4_addrs() {
    local if_id="$1"

    : > "$tmp"

    # 1. Linux / modern: ip -4 addr
    cmd_on "$if_id" "ip -4 addr" 2>/dev/null \
        | sed -n 's/.*inet \([0-9.]*\)\/.*/\1/p' > "$tmp"
    [[ -s "$tmp" ]] && return 0

    # 2. Linux / generic: ip addr
    cmd_on "$if_id" "ip addr" 2>/dev/null \
        | sed -n 's/.*inet \([0-9.]*\)\/.*/\1/p' > "$tmp"
    [[ -s "$tmp" ]] && return 0

    # 3. ifconfig (Linux/BSD/macOS)
    cmd_on "$if_id" "ifconfig" 2>/dev/null \
        | sed -n 's/.*inet \(addr:\)\?\([0-9.]\+\).*/\2/p' > "$tmp"
    [[ -s "$tmp" ]] && return 0

    # 4. Windows: ipconfig
    cmd_on "$if_id" "ipconfig" 2>/dev/null \
        | sed -n 's/.*IPv4[^0-9]*\([0-9.]\+\).*/\1/p' > "$tmp"
    [[ -s "$tmp" ]] && return 0

    # 5. Cisco‑achtig: sh ip int br
    cmd_on "$if_id" "sh ip int br" 2>/dev/null \
        | awk 'NR>1 && $2 ~ /^[0-9.]+$/ {print $2}' > "$tmp"
    [[ -s "$tmp" ]] && return 0

    return 1
}



#merge
list_interfaces |
	while read if_id if_ip rest ; do
		get_ipv4_addrs $if_id
		sed "s/^/$if_id: /" $tmp
		for ip in $(cat $tmp) ; do
			sn_scope=''
			srv_name=''
			if_host=$(valfromid interfaces $if_id host)
			if [ "$if_host" != "" ] ; then
				srv_name=$(valfromid server $if_host name)
			fi
			sn_id=$(get_subnet $ip)
			if [ "$sn_id" != "" ] ; then
				sn_scope=$(valfromid subnet $sn_id scope)
			fi
			echo "   $ip to host $if_host ($srv_name)  subnet: $sn_id $sn_scope"
			if [ "$sn_scope" = "global" ] && [ "$if_host" != "" ] ; then
				declare -A interface_data
				interface_data[ip]="$ip"
				interface_data[host]="$if_host"
				interface_data[subnet]="$sn_id"
				interface_data[ip_scope]="global"
				set_interface interface_data
				unset interface_data
			fi
				
				
		done
	done
#cleanup server
list_server | while read srv_id ; do
	if_ids=$(idfrom_interfaces host $srv_id)
	if [ "$if_ids" = "" ] ; then
		del_server $srv_id
		echo "->del $srv_id"
	fi
done


rm -f $tmp $tmp1 

exit

