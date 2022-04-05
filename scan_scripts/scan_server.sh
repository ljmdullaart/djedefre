#!/bin/bash

log=log_scanserver

if [ -f /usr/local/bin/djedefre.common ] ; then
	. /usr/local/bin/djedefre.common
fi
if [ -f /opt/djedefre/bin/djedefre.common ] ; then
	. /opt/djedefre/bin/djedefre.common
fi
if [ -f djedefre.common.sh ] ; then
	. djedefre.common.sh
fi

#
#  ___  ___ __ _ _ __      __ _     ___  ___ _ ____   _____ _ __
# / __|/ __/ _` | '_ \    / _` |   / __|/ _ \ '__\ \ / / _ \ '__|
# \__ \ (_| (_| | | | |  | (_| |   \__ \  __/ |   \ V /  __/ |
# |___/\___\__,_|_| |_|   \__,_|   |___/\___|_|    \_/ \___|_|
#

date > $log

scan_server(){
	srv="$1" 
	srv_id="$2"
	cmd="$3"
	didit=no
	echo "$erver ($srv_id):" >>$log
	echo hop |$cmd$srv ip addr |
		sed -n 's/\([0-9]\) .*/\1/;s/\// /;s/.*inet //p' |
		grep -v 127.0.0.1 |
		while read ip cidr ; do
		echo "    interface : $ip" >> $log
		add_if "$ip" "$srv_id"
		nwaddress=$(ipcalc "$ip/$cidr" | sed -n 's/\/.*//;s/Network: *//p'| sed 's/ //g')
		echo "    subnet    : $ip / $cidr" >> $log
		if [ "$nwaddress" = "" ] ; then
			echo "    empty" >> $log
		elif [ "$cidr" = "" ] ; then
			echo "    empty" >> $log
		else
			add_subnet "$nwaddress" "$cidr"
		fi
		didit=yes
	done
	if [ "$didit" = "no" ] ; then
		echo hop |$cmd$srv ifconfig -a |
			sed -n 's/.*inet //;s/ *netmask */ /;s/ *broad.*//p' |
			grep -v 127.0.0.1 |
			while read ip mask; do
			cidr=$(ipcalc -b  $ip $mask | sed -n 's/.*[0-9]\///p')
			nwaddress=$(ipcalc "$ip/$cidr"  | sed -n 's/\/.*//;s/Network: *//p')
			echo "    subnet    : $ip / $cidr" >>$log
			add_subnet "$nwaddress" "$cidr"
		done
		didit=yes
	fi

}

#                                                   _  __
#  ___  ___ __ _ _ __      _ __ ___  _   _ ___  ___| |/ _|
# / __|/ __/ _` | '_ \    | '_ ` _ \| | | / __|/ _ \ | |_
# \__ \ (_| (_| | | | |   | | | | | | |_| \__ \  __/ |  _|
# |___/\___\__,_|_| |_|   |_| |_| |_|\__, |___/\___|_|_|
#                                    |___/


add_server "$(hostname)"
echo $db_retval >>$log
scan_server 127.0.0.1 "$db_retval" "ssh "


#                            _                      _
#  _   _ _ __   __ _ ___ ___(_) __ _ _ __   ___  __| |
# | | | | '_ \ / _` / __/ __| |/ _` | '_ \ / _ \/ _` |
# | |_| | | | | (_| \__ \__ \ | (_| | | | |  __/ (_| |
#  \__,_|_| |_|\__,_|___/___/_|\__, |_| |_|\___|\__,_|
#                              |___/
#  _       _             __
# (_)_ __ | |_ ___ _ __ / _| __ _  ___ ___  ___
# | | '_ \| __/ _ \ '__| |_ / _` |/ __/ _ \/ __|
# | | | | | ||  __/ |  |  _| (_| | (_|  __/\__ \
# |_|_| |_|\__\___|_|  |_|  \__,_|\___\___||___/
#        

for ip in $(sqlite3 "$database" "SELECT ip FROM interfaces WHERE host IS NULL "); do
	if nc -zw 1 "$ip"  22 ; then
		access=$(sqlite3 "$database" "SELECT access FROM interfaces WHERE ip='$ip'")
		if [ "$access" = "" ] ; then
			if  echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "$ip" id > /dev/null 2>/dev/null ; then
				access="ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 "
			elif  echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "admin@$ip" id > /dev/null 2>/dev/null ; then
				access="ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 admin@"
			elif  echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "root@$ip" id > /dev/null 2>/dev/null ; then
				access="ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 root@"
			else
				access=none
			fi
			sqlite3 "$database" "UPDATE interfaces SET access='$access' WHERE ip='$ip'"
		fi
		if [ "$access" != "none" ] ; then
			#name=$(echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "root@$ip" hostname)
			name=$(echo hop| $access$ip hostname | sed 's/\..*//')
			if [ "$name" = "" ] ; then
				name=$(host "$ip" | sed 's/.* //;s/\..*//' | grep -v NXDOMAIN)
			fi
			if [ "$name" = "" ] ; then
				name="$ip"
			fi
			add_server "$name"
			server_id="$db_retval"
			add_if "$ip" "$server_id"
			scan_server "$ip" "$server_id" "$access"
			arplist=''
			if $access$ip test -f /usr/sbin/arp ; then 
				arplist=$(echo hop| $access$ip /usr/sbin/arp -a | grep :..:..:.. | sed 's/.*(//;s/).*//')
			elif $access$ip test -f /usr/bin/arp ; then 
				arplist=$(echo hop| $access$ip /usr/bin/arp -a | grep :..:..:.. | sed 's/.*(//;s/).*//')
			elif $access$ip test -f /bin/arp ; then 
				arplist=$(echo hop| $access$ip /bin/arp -a | grep :..:..:.. | sed 's/.*(//;s/).*//')
			fi
			for arp_if in $arplist ; do
				add_if "$arp_ip" "$server_id"
			done

		else
			# Cannot see if there are multiple IP's on this server
			name=$(echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "root@$ip" hostname)
			if [ "$name" = "" ] ; then
				name=$(host "$ip" | sed 's/.* //;s/\..*//' | grep -v NXDOMAIN)
			fi
			if [ "$name" = "" ] ; then
				name="$ip"
			fi
			add_server "$name"
			add_if "$ip" "$db_retval"
			
		fi
	else
		# no ssh access; port is closed
		name=$(host "$ip" | sed 's/.* //;s/\..*//' | grep -v NXDOMAIN)
		if [ "$name" = "" ] ; then
			name="$ip"
		fi
		add_server "$name"
		add_if "$ip" "$db_retval"
	fi
done

for id in $(sqlite3 "$database" "SELECT id FROM interfaces") ; do
	host=''
	host=$(sqlite3 "$database" "SELECT id FROM server WHERE interfaces LIKE '%$id%'")
	echo "$id -> $host"
done


#                _                      _
#   __ _ ___ ___(_) __ _ _ __   ___  __| |
#  / _` / __/ __| |/ _` | '_ \ / _ \/ _` |
# | (_| \__ \__ \ | (_| | | | |  __/ (_| |
#  \__,_|___/___/_|\__, |_| |_|\___|\__,_|
#                  |___/
#  _       _             __
# (_)_ __ | |_ ___ _ __ / _| __ _  ___ ___  ___
# | | '_ \| __/ _ \ '__| |_ / _` |/ __/ _ \/ __|
# | | | | | ||  __/ |  |  _| (_| | (_|  __/\__ \
# |_|_| |_|\__\___|_|  |_|  \__,_|\___\___||___/
#


for ip in $(sqlite3 "$database" "SELECT ip FROM interfaces WHERE host IS NOT NULL "); do
	if nc -zw 1 "$ip"  22 ; then
		access=$(sqlite3 "$database" "SELECT access FROM interfaces WHERE ip='$ip'")
		if [ "$access" = "" ] ; then
			if  echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "$ip" id > /dev/null 2>/dev/null ; then
				access="ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 "
			elif  echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "admin@$ip" id > /dev/null 2>/dev/null ; then
				access="ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 -l admin "
			elif  echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "root@$ip" id > /dev/null 2>/dev/null ; then
				access="ssh -x -o PasswordAuthentication=no -o ConnectTimeout=2 -l root "
			else
				access=none
			fi
			sqlite3 "$database" "UPDATE interfaces SET access='$access' WHERE ip='$ip'"
		fi
		server_id=$(sqlite3 "$database" "SELECT host FROM interfaces WHERE ip='$ip'")
		name=$(sqlite3 "$database" "SELECT name FROM server WHERE id=$server_id")
		if [ "$name" = "" ] ; then
			name="$ip"
		fi
		if [ "$access" != "none" ] ; then
			add_if "$ip" "$server_id"
			scan_server "$ip" "$server_id" "$access"
			arplist=''
			if $access$ip test -f /usr/sbin/arp ; then 
				arplist=$(echo hop| $access$ip /usr/sbin/arp -a | grep :..:..:.. | sed 's/.*(//;s/).*//')
			elif $access$ip test -f /usr/bin/arp ; then 
				arplist=$(echo hop| $access$ip /usr/bin/arp -a | grep :..:..:.. | sed 's/.*(//;s/).*//')
			elif $access$ip test -f /bin/arp ; then 
				arplist=$(echo hop| $access$ip /bin/arp -a | grep :..:..:.. | sed 's/.*(//;s/).*//')
			fi
			for arp_if in $arplist ; do
				add_if "$arp_ip" "$server_id"
			done

		else
			# Cannot see if there are multiple IP's on this server
			name=$(echo hop|ssh -x -o PasswordAuthentication=no -o ConnectTimeout=1 "root@$ip" hostname)
			if [ "$name" = "" ] ; then
				name=$(host "$ip" | sed 's/.* //;s/\..*//' | grep -v NXDOMAIN)
			fi
			if [ "$name" = "" ] ; then
				name="$ip"
			fi
			add_server "$name"
			add_if "$ip" "$db_retval"
			
		fi
	fi
done


#                                                                       _ 
#  _ __ ___ _ __ ___   _____   _____     _   _ _ __  _   _ ___  ___  __| |
# | '__/ _ \ '_ ` _ \ / _ \ \ / / _ \   | | | | '_ \| | | / __|/ _ \/ _` |
# | | |  __/ | | | | | (_) \ V /  __/   | |_| | | | | |_| \__ \  __/ (_| |
# |_|  \___|_| |_| |_|\___/ \_/ \___|    \__,_|_| |_|\__,_|___/\___|\__,_|
#                                                                        
#  _               _       
# | |__   ___  ___| |_ ___ 
# | '_ \ / _ \/ __| __/ __|
# | | | | (_) \__ \ |_\__ \
# |_| |_|\___/|___/\__|___/
#                          


sqlite3 "$database" "SELECT id FROM server" | while read server_id ; do
iflist=$(sqlite3 "$database" "SELECT COUNT(ALL)  FROM interfaces WHERE host=$server_id")
	echo "-------------------------------------------------------"
	echo -n "$server_id: $iflist"
	if [ "$iflist" = "0" ] ; then
		sqlite3  "$database" "DELETE  FROM server WHERE id=$server_id"
		echo "DELETED"
	else
		echo "ok"
	fi
done


