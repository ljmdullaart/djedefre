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


pagename=Cloud


confid=$(SQL "SELECT id FROM config WHERE attribute='page:type' AND item='$pagename'";)

if [ "$confid" = "" ] ; then
	SQL "INSERT INTO config (attribute,item,value) VALUES ('page:type','$pagename','l3')"
else
	echo "Config exists"
fi

incr=100
xcntr=$incr
ycntr=$incr
maxx=1000

nextpos(){
	xcntr=$((xcntr+incr))
	if [ $xcntr -gt $maxx ] ; then
		ycntr=$((ycntr+incr))
		xcntr=$incr
	fi
}
	


SQL "SELECT tbl,item FROM pages WHERE page='$pagename'" >$tmp1

for tbl in cloud ; do
	SQL "SELECT id,xcoord,ycoord FROM $tbl" > $tmp2
	cat $tmp2 | while read id x y ; do
		if [ "$id" != "" ] ; then
			if   [ "$x" = "" ] ; then x=$xcntr; y=$ycntr; nextpos
			elif [ "$y" = "" ] ; then x=$xcntr; y=$ycntr; nextpos
			fi
			if  grep -q "$tbl $id$" $tmp1  ; then
				echo -n '.'
				SQL "UPDATE pages SET xcoord=$x WHERE page='$pagename' AND tbl='$tbl' and item=$id"
				SQL "UPDATE pages SET ycoord=$y WHERE page='$pagename' AND tbl='$tbl' and item=$id"
			else
				echo -n '+'
				SQL "INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ('$pagename','$tbl',$id,$x,$y)"
			fi
		fi
	done

done

SQL "SELECT item,tbl FROM pages WHERE page='$pagename'" >$tmp1
cat  $tmp1 | while read item tbl ; do
	is=$(SQL "SELECT id FROM $tbl WHERE id=$item");
	if [ "$is" = "" ] ; then
		SQL "DELETE FROM pages WHERE page='$pagename' AND tbl='$tbl' and item=$item"
	fi
done

echo


rm -f $tmp1
rm -f $tmp2
