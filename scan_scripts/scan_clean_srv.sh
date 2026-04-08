#!/bin/bash

tmp=/tmp/clean_server.$$
tmp1=/tmp/clean_server.$$.1
tmp2=/tmp/clean_server.$$.2


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

echo  clean-up interfaces for good measure
sqlite3  -separator ' ' "$database" "DELETE FROM interfaces WHERE ip like '255.255%'"
sqlite3  -separator ' ' "$database" "DELETE FROM interfaces WHERE ip like '127.%'"

echo  remove hosts that are more than 3 months down
sqlite3  -separator ' ' "$database" "SELECT id FROM SERVER WHERE last_up IS NULL OR last_up = '' OR last_up < DATE('now', '-2 months');" > $tmp
sqlite3  -separator ' ' "$database" "SELECT server.id FROM server LEFT JOIN interfaces ON server.id = interfaces.host WHERE interfaces.host IS NULL;" >> $tmp
while read id ; do
	sqlite3  -separator ' ' "$database" "DELETE FROM interfaces WHERE host=$id"
	sqlite3  -separator ' ' "$database" "DELETE FROM server WHERE id=$id"

done <$tmp

echo  remove servers without interfaces

while read id ; do
	sqlite3  -separator ' ' "$database" "SELECT * FROM interfaces WHERE host = $id" > $tmp1
	if [ "$(wc -c < $tmp1)" -le 5 ]; then
		sqlite3  -separator ' ' "$database" "DELETE FROM server WHERE id=$id"
	fi
done <$tmp

echo remove non-existing servers from pages

sqlite3  -separator ' ' "$database" "SELECT item FROM pages WHERE tbl='server'" > $tmp1
while read item ; do
	sqlite3  -separator ' ' "$database" "SELECT * FROM server WHERE id=$item" > $tmp2
	if [ "$(wc -c < $tmp2)" -le 5 ]; then
		sqlite3  -separator ' ' "$database" "DELETE FROM pages WHERE tbl='server' AND item=$item"
	fi
done <$tmp1

rm -f $tmp
rm -f $tmp1
rm -f $tmp2
