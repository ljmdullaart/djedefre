#!/bin/bash

tmp=/tmp/scan_data.$$.0
tmp1=/tmp/scan_data.$$.1
tmp2=/tmp/scan_data.$$.2


SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if [ -d data ] ; then DATADIR=data 
elif [ -d "$SCRIPTPATH/data" ] ; then DATADIR="$SCRIPTPATH/data"
elif [ -d "$SCRIPTPATH/../data" ] ; then DATADIR="$SCRIPTPATH/../data"
fi
if [ -f $SCRIPTPATH/djedefre.common.sh ] ; then
	. $SCRIPTPATH/djedefre.common.sh
fi

hellup(){
cat <<EOF
NAME: $0
USAGE:
    $0 <database>
    $0 -h
DESCRIPTION:
$0 reads all csv files that are in the data directory. The data directory is
the first of:
- data in the current directory
- data under the directory SCRIPTPATH (currently $SCRIPTPATH/data)
- data under the parent of SCRIPTPATH (currently $SCRIPTPATH/../data)

Csv files are lines with ,-separated fields. Lines starting with # are dropped.
The first line has 2 fields:
- dejedefre (litteral text)
- the type of data.

For the different type of data, the columns mean:
connect: vlan, from server name, from port, to server name, to port
cloud: name, vendor, type, service
EOF
}

if [ "$1" = "-h" ] ; then
	hellup
	exit 0
elif [ "$1" != '' ] ; then
	if [ -f "$1" ] ; then
		database="$1"
	else
		echo "Database=$database, not $1"
	fi
fi

for csvfile in "$DATADIR"/*csv ; do
	echo "Doing $csvfile"
	datatype=none
	while IFS=, read  f1 f2 f3 f4 f5 f6 f7 f8 f9 ; do
		case $datatype in
		(connect)
			echo '-----------------------'
			if [ "$f1" = "djedefre" ] ; then datatype="$2"
			else
				if [ "$f1" = "" ] ; then f1=1 ; fi
				if [ "$f3" = "" ] ; then f3=1 ; fi
				if [ "$f5" = "" ] ; then f5=1 ; fi
				from_id=$(idfromval server name "$f2")
				to_id=$(idfromval server name "$f4")
				echo "connect $f2 ($from_id)  to $f4 ($to_id) "
				if [ "$from_id" != "" ] && [ "$to_id" != "" ] ; then
					declare -A l2_data
					l2_data[vlan]="$f1"
					l2_data[from_tbl]="server"
					l2_data[from_id]="$from_id"
					l2_data[from_port]="$f3"
					l2_data[to_tbl]="server"
					l2_data[to_id]="$to_id"
					l2_data[to_port]="$f5"
					set_l2 l2_data
					unset l2_data
				fi
			fi
			;;
		(cloud)
			echo '-----------------------'
			if [ "$f1" = "djedefre" ] ; then datatype="$2"
			else
				echo "Cloud $f1 from $f2 has service $f4"
				declare -A cloud_data
				cloud_data[name]="$f1"
				cloud_data[vendor]="$f2"
				cloud_data[type]="$f3"
				cloud_data[service]="$f4"
				set_cloud cloud_data
				unset cloud_data
			fi
			;;
		(none)
			if [ "$f1" = "djedefre" ] ; then
				datatype="$f2" 
				echo "$datatype"
			fi
			;;
		esac
	done < <(grep -v '^#' "$csvfile")
done
	




rm -f /tmp/scan_data.$$.*
