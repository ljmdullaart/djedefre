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

set_dbconfig 'page:type' "$pagename" 'l3'

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
	


SQL "SELECT tbl,item FROM pages WHERE page='$pagename'" >$tmp1

for tbl in server ; do
	list_server | while read srv_id ; do
		xcoord=$(valfromid $tbl $srv_id xcoord)
		ycoord=$(valfromid $tbl $srv_id ycoord)
		echo "$srv_id $xcoord $ycoord" >>$tmp2
	done
	cat $tmp2 | while read id x y ; do
		if [ "$id" != "" ] ; then
			x=$xcntr; y=$ycntr; nextpos
			if  grep -q "$tbl $id$" $tmp1  ; then
				echo -n '.'
				pg_id=$(idfromval pages page "$pagename" tbl "$tbl" item "$id")
				setfromid pages $pg_id xcoord $x
				setfromid pages $pg_id ycoord $y
			else
				echo -n '+'
				pages_insert "$pagename" "$tbl" $id $x $y
			fi
		fi
	done

done

rm -f $tmp1
#list_pages | while read pg_id ; do
#	item=$(valfromid pages $pg_id item)
#	tbl=$(valfromid pages $pg_id tbl)
#	echo "$item $tbl" >>$tmp1
#done
#
#cat  $tmp1 | while read item tbl ; do
#	srv_name=$(idfromval $tbl $item name)
#	if [ "$srv_name" = "" ] ; then
#		pg_id=$(idfromval pages tbl "$tbl" item "$item")
#		delfromid pages $pg_id
#	fi
#done
#
echo


rm -f $tmp1
rm -f $tmp2
