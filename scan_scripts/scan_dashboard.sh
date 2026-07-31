#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp1=/tmp/scan_dash.$$
tmp2=/tmp/scan_dash.$$

mkdir -p /tmp/djedefre

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
djedefre_log '########################### scan dashboard ###################################'

scandate=$(date)
db_dash_set_val 'Last scan' 'Date' "$scandate"


for dash_script in $SCRIPTPATH/dashboard_*sh ; do
	djedefre_log "running $dash_script"
	bash $dash_script > $tmp1
	grep -v ^$ $tmp1 | while read line ; do
		if [[ "$line" == *: ]] ; then
			server=${line%:*}
			djedefre_log "server=$server"
		else
			IFS=';' read -ra ADDR <<< "$line"
			tpe="${ADDR[0]}"
			variable="${ADDR[1]}"
			value="${ADDR[2]}"
			color1="${ADDR[3]}"
			color2="${ADDR[4]}"
			djedefre_log "    tpe=$tpe variable=$variable value=$value color1=$color1 color2=$color2"
			if [ "$server" != "" ] && [ "$variable" != "" ] && [ "$tpe" != "" ] ; then
				db_dash_set_val "$server" "$variable" "$value" "$tpe" "$color1" "$color2"
			fi
				
		fi
	done
done
rm -f $tmp1 $tmp2

rm -f  /tmp/djedefre.listing
for listscript in $SCRIPTPATH/listing_*sh ; do
	djedefre_log "running $listscript"
	baselist=$(basename $listscript)
	bash $listscript -s >> /tmp/djedefre.listing 2>>/tmp/djedefre.log
	bash $listscript -htm > /tmp/djedefre/$baselist.htm 2>>/tmp/djedefre.log
done 
set_dbconfig 'run:param' 'changed' 'yes'

exit
				
