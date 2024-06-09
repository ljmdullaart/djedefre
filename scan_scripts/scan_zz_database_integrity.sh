#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_dbconsist.$$
tmp2=/tmp/scan_dbconsist2.$$

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


echo 'Set subnet ID on interfaces'
ips=$(sqlite3 "$database" "SELECT ip FROM interfaces")

for interface in $ips ; do
	echo "Interface $interface"
	ids=$(sqlite3 "$database" "SELECT id FROM subnet")
	for snid in $ids; do
		nwadr=$(sqlite3 "$database" "SELECT nwaddress FROM subnet WHERE id=$snid")
		cidr=$(sqlite3 "$database" "SELECT cidr FROM subnet WHERE id=$snid")
		if [ "$nwadr" != "Internet" ] ; then
			if echo $interface | grepcidr $nwadr/$cidr ; then
				echo "    $nwadr/$cidr -> $snid"
				sqlite3 "$database" "UPDATE interfaces SET subnet=$snid WHERE ip='$interface'"
			fi
		fi
	done
done


if [ "$verbose" = "yes" ] ; then
	echo "Configs read are $configs"
	echo "networkdefinitions = $networkdefinitions"
	echo "database           = $database"
	echo "logfile            = $logfile"
	echo "$db_retval"
fi

#
readarray -t interfaces < <(sqlite3 -separator ' ' $database 'SELECT id,ip,host FROM interfaces'    | grep -v '^$')
readarray -t subnets    < <(sqlite3 -separator ' ' $database 'SELECT id,nwaddress,cidr FROM subnet' | grep -v '^$')
readarray -t servers    < <(sqlite3 -separator ' ' $database 'SELECT id,name FROM server'           | grep -v '^$')

#
echo  Fill the subnet-field in interfaces based on the IP address
#
for interface in "${interfaces[@]}" ; do
	read ifid ip host < <(echo $interface)
	for subnet in "${subnets[@]}" ; do
		read snid nwaddress cidr< <(echo $subnet)
		if echo $ip | grepcidr "$nwaddress/$cidr" > /dev/null 2>/dev/null ; then
			sqlite3 -separator ' ' $database "UPDATE interfaces SET subnet=$snid WHERE id=$ifid"
		elif [ "$ip" = "$nwaddress" ] ; then
			sqlite3 -separator ' ' $database "UPDATE interfaces SET subnet=$snid WHERE id=$ifid"
			
		fi
	done
done


#
echo  Delete some unlikely IP addresses and delete interfaces without host
#		
for interface in "${interfaces[@]}" ; do
	read ifid ip host < <(echo $interface)

	if [[ $ip =~ ^0x\. ]]; then	
		sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE id=$ifid"
		echo "    Removed $ifif ($ip)"
	elif [[ $ip =~ ^255\. ]]; then	
		sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE id=$ifid"
		echo "    Removed $ifif ($ip)"
	elif [[ $ip =~ ^127\. ]]; then	
		sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE id=$ifid"
		echo "    Removed $ifif ($ip)"
	elif [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then	
		:
	elif [[ $ip =~ Internet ]]; then	
		:
	else
		sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE id=$ifid"
		echo "    Removed $ifif ($ip)"
	fi
	host=$(sqlite3 -separator ' ' $database "SELECT host FROM interfaces WHERE id=$ifid")
	if [ "$host" != "" ] ; then
		existing=$(sqlite3 -separator ' ' $database "SELECT id FROM server WHERE id=$host")
		if [ "$existing" = "" ] ; then
			sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE id=$ifid"
			echo "    Removed $ifif ($ip has no host)"
		fi
	fi
	
done

#
echo  Remove subnet and interfaces that must be ignored
#
ignore_subnet=none
if [ -f ignore_subnet ] ; then
	ignore_subnet=ignore_subnet
elif [ -f ../ignore_subnet ] ; then
	ignore_subnet=../ignore_subnet
elif [ -f ~/.ignore_subnet ] ; then
	ignore_subnet=~/.ignore_subnet
elif [ -f database/ignore_subnet ] ; then
	ignore_subnet=database/ignore_subnet
fi


#
echo Remove duplicate interfaces
#

for interface in "${interfaces[@]}" ; do
	read ifid ip host < <(echo $interface)
	dup=no
	for interface in "${interfaces[@]}" ; do
		read ifid2 ip2 host2 < <(echo $interface)
		if [ "$ip" = "$ip2" ] ; then
			if [ "$ifid" != "$ifid2" ] ; then
				if [ "$ifid" != "" ] ; then
					dup="$ifid $ifid2"
				fi
			fi
		fi
	done
	if [ "$dup" != "no" ] ; then
		read id1 id2 < <(echo $dup)
		sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE id=$id2"
		echo "    Remove $id2 (same as $id)"
		# there should be a better way to handle this instead of just deleting the lates
	fi
done

# 
#echo remove interfaces without server
#
#sqlite3 -separator ' ' $database "SELECT * FROM interfaces WHERE host IS NULL"
#sqlite3 -separator ' ' $database "DELETE   FROM interfaces WHERE host IS NULL"

echo Remove non-existing servers

for interface in "${interfaces[@]}" ; do
	read ifid ip host < <(echo $interface)
	hid=$(sqlite3 -separator ' ' $database "SELECT id FROM server WHERE id=$host")
	if [ "$hid" = "" ] ; then
		sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE host=$host"
	fi
done

#

rm -f $tmp
rm -f $tmp2
