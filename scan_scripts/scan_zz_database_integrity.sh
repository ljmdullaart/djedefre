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


#CREATE TABLE subnet (
#          id         integer primary key autoincrement,
#          nwaddress  string,
#          cidr       integer,
#          xcoord     integer,
#          ycoord     integer,
#          name       string,
#          options    string,
#          access     string
#        );
#CREATE TABLE server (
#          id         integer primary key autoincrement,
#          name       string,
#          xcoord     integer,
#          ycoord     integer,
#          type       string,
#          interfaces string,
#          access     string,
#          status     string,
#          last_up    integer,
#          options    string
#        );
#
##CREATE TABLE interfaces (
#          id        integer primary key autoincrement,
#          macid     string,
#          ip        string,
#          hostname  string
#	   host      integer
#          subnet    integer
#        , access);
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

if [ -f $ignore_subnet ] ; then
	sed 's/\// /' $ignore_subnet  | while read net cidr ; do
		nmap -sLn  $net/$cidr | sed 's/.* //' | grep '[0-9]' > $tmp
		sqlite3 -separator ' ' $database "SELECT id,host,ip FROM interfaces" > $tmp2
		grep -v '^$' $tmp2 | while read ifid host ip ; do
			echo "    Remove $net $cidr"
			if grep -q $ifid $tmp ; then
				qif=$(sqlite3 -separator ' ' $database "SELECT COUNT(id) FROM interfaces WHERE host=$host");
				if [ "$qif" = 1 ] ; then
					sqlite3 -separator ' ' $database "DELETE FROM server WHERE host=$host"
				fi
				sqlite3 -separator ' ' $database "DELETE FROM interfaces WHERE id=$id"
			fi
		done
	done
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
echo remove interfaces without server
#
sqlite3 -separator ' ' $database "SELECT * FROM interfaces WHERE host IS NULL"
sqlite3 -separator ' ' $database "DELETE   FROM interfaces WHERE host IS NULL"


#
echo Remove hosts without interfaces
#
for server in "${servers[@]}" ; do
	read id name < <(echo $server)
	found=no
	for interface in "${interfaces[@]}" ; do
		read ifid ip host < <(echo $interface)
		if [ "$id" = "$host" ] ; then
			found=yes
		fi
	done
	if [ $found = no ] ; then
		echo "    removed $id $name"
		sqlite3 -separator ' ' $database "DELETE FROM server  WHERE id=$id"
	fi
done


rm -f $tmp
rm -f $tmp2
