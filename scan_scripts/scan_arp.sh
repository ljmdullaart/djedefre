#!/bin/bash

tmp=/tmp/scan_arp.$$
tmp1=/tmp/scan_arp.$$.1
tmp2=/tmp/scan_arp.$$.2


SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ -f $SCRIPTPATH/djedefre.common.sh ] ; then
	. $SCRIPTPATH/djedefre.common.sh
fi

djedefre_log '########################## scan arp ############################'

if [ "$1" = "-h" ] ; then
	echo 'HELP!!'
	exit 0
elif [ "$1" != '' ] ; then
	if [ -f "$1" ] ; then
		database="$1"
	else
		echo "Database=$database, not $1"
		djedefre_log  "Database=$database, not $1"
	fi
fi

cat /proc/net/arp |
awk '{print $1 " " $4}' |
egrep -v '00:00:00:00:00:00|IP' >> $tmp1

list_interfaces | while read id ip rest ; do
	access=$(valfromid interfaces $id access)
	echo "$id $ip $access"
done > $tmp

egrep 'ssh|telnet'  $tmp |
	while read id ip access ; do
		echo "Get arp from $ip"
		djedefre_log  "Get arp from $ip"
		if cmd_on $id which ip 2>/dev/null | grep -q 'usr.*ip' ; then
			cmd_on $id ip addr | awk '
				/inet /{ inet=$2 }
				/link.ether/ { link=$2}
				/^[0-9]/ { printf "%s %s\n", inet, link }
				END { printf "%s %s\n", inet, link }
			' | sed -n 's/\/[0-9]*//p' |sort -u | grep -v 127.0.0.1 >> $tmp2
		fi
		if cmd_on $id which arp  2>/dev/null | grep -q 'usr.*ip' ; then
			cmd_on $id arp -a | sed 's/.*(\(.*\)) at \([0-9a-fA-F:]*\).*/\1 \2/' | grep -v "00:00:00:00:00:0" >>$tmp2
		fi
		cmd_on $id '[ -f /proc/net/arp ] && cat /proc/net/arp'| sed 's/.*(\(.*\)) at \([0-9a-fA-F:]*\).*/\1 \2/'  | grep -v "00:00:00:00:00:0">>$tmp2
			
	done
sed -n 's/\([0-9\.]*\) .* \([0-9a-f:][0-9a-f:]*\) .*/\1 \2/p' $tmp2 | sort -u
sed -n 's/\([0-9\.]*\) .* \([0-9a-f:][0-9a-f:]*\) .*/\1 \2/p' $tmp2 | sort -u |
	while read myip mymac ; do
		if [[ $myip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			# add only if ip in a subnet that is "global"
			subnetid=$(get_subnet $myip)
			if [ "$subnetid" = "" ] ; then
				djedefre_log "IP address $myip is not in a known subnet"
			else
				subnetscope=$(valfromid subnet "$subnetid" scope)
				if [ "$subnetscope" = "global" ] ; then
					declare -A interface_data
					interface_data[ip]="$myip"
					if [ "$mymac" != "" ] ; then interface_data[macid]="$mymac" ; fi
					interface_data[source]="scan_arp"
					interface_data[subnet]="$subnetid"
					set_interface interface_data
					unset interface_data
					djedefre_log "IP address $myip added"
				else
					djedefre_log "IP address $myip not in global subnet"
				fi
			fi
		fi
	done

sed -n 's/\([0-9\.]*\) .* \([0-9a-f:][0-9a-f:]*\) .*/\1 \2/p' $tmp2 | sort -u |
	while read myip mymac ; do
		set_ipmac $myip $mymac
		djedefre_log  "$myip has mac-id  $mymac"
	done


rm -f $tmp $tmp1 $tmp2
