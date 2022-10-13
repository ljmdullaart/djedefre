#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp=/tmp/scan_dbconsist.$$

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
readarray -t interfaces < <(sqlite3 -separator ' ' $database 'SELECT id,ip FROM interfaces'          )
readarray -t subnets    < <(sqlite3 -separator ' ' $database 'SELECT id,nwaddress,cidr FROM subnet'  )


for interface in "${interfaces[@]}" ; do
	read ifid ip < <(echo $interface)
	if host $ip > /dev/null 2>/dev/null ; then
		hostname=$(host $ip | sed 's/.* //')
		sqlite3  $database "UPDATE interfaces SET hostname='$hostname' WHERE id=$ifid"
	fi
done

	




rm -f $tmp
