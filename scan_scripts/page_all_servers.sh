#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp1=/tmp/scan_l2top1.$$
tmp2=/tmp/scan_l2top2.$$

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
	shift
fi


pagename=all_servers

confid=$(sqlite3 -separator ' '  $database "SELECT id FROM config WHERE attribute='page:type' AND item='$pagename'";)

if [ "$confid" = "" ] ; then
	sqlite3 -separator ' '  $database "INSERT INTO config (attribute,item,value) VALUES ('page:type','$pagename','l3')"
else
	echo "Config exists"
fi

incr=100
xcntr=$incr
ycntr=$incr
maxx=1500

nextpos(){
	xcntr=$((xcntr+incr))
	if [ $xcntr -gt $maxx ] ; then
		ycntr=$((ycntr+incr))
		xcntr=$incr
	fi
}
	


sqlite3 -separator ' '  $database "SELECT tbl,item FROM pages WHERE page='$pagename'" >$tmp1

for tbl in server ; do
	sqlite3 -separator ' '  $database "SELECT id,xcoord,ycoord FROM $tbl ORDER BY options,name" > $tmp2
	cat $tmp2 | while read id x y ; do
		if [ "$id" != "" ] ; then
			x=$xcntr; y=$ycntr; nextpos
			if  grep -q "$tbl $id$" $tmp1  ; then
				echo -n '.'
				sqlite3 $database "UPDATE pages SET xcoord=$x WHERE page='$pagename' AND tbl='$tbl' and item=$id"
				sqlite3 $database "UPDATE pages SET ycoord=$y WHERE page='$pagename' AND tbl='$tbl' and item=$id"
			else
				echo -n '+'
				sqlite3 $database "INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ('$pagename','$tbl',$id,$x,$y)"
			fi
		fi
	done

done

sqlite3 -separator ' '  $database "SELECT item,tbl FROM pages WHERE page='$pagename'" >$tmp1
cat  $tmp1 | while read item tbl ; do
	is=$(sqlite3 -separator ' '  $database "SELECT id FROM $tbl WHERE id=$item");
	if [ "$is" = "" ] ; then
		sqlite3 $database "DELETE FROM pages WHERE page='$pagename' AND tbl='$tbl' and item=$item"
	fi
done

echo


rm -f $tmp1
rm -f $tmp2
