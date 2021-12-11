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


sed 's/=/ /' "$networkdefinitions" | while read attr item value ; do
	oldvalue=$(sqlite3 "$database" "SELECT value FROM config WHERE item='$item' AND attribute='$attr'")
	if [ "$oldvalue" = "" ] ; then
		sqlite3 "$database" "INSERT INTO config (attribute,item,value) VALUES ('$attr','$item','$value')"
	elif [ "$value" = "DELETE" ] ; then
		sqlite3 "$database" "DELETE FROM config WHERE item='$item' AND attribute='$attr'"
	fi
	if [ "$attr" = "type" ] ; then
		sqlite3 "$database" "UPDATE server SET type='$value' WHERE name='$item'"
	elif [ "$attr" = "name" ] ; then
		id=0
		qty=$(sqlite3 "$database" "SELECT COUNT(ALL) FROM interfaces WHERE ip='$item'")
		if [ $qty -ge 1 ] ; then
			hostid=$(sqlite3 "$database" "SELECT host FROM interfaces WHERE ip='$item'")
			sqlite3 "$database" "UPDATE server SET name='$value' WHERE id=$hostid"
		else
			 sqlite3 "$database" "UPDATE subnet SET name='$value' WHERE nwaddress='$item'"
		fi
	fi

done

