#!/bin/bash

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
tmp1=/tmp/scan_access.$$
tmp2=/tmp/scan_access2.$$

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

scandate=$(date)
ovariable=$(sqlite3 -cmd ".timeout 1000" $database "SELECT variable FROM dashboard WHERE type='val' AND  server='Last scan' AND variable='Date'")
if [ "$ovariable" = "" ] ; then
	sqlite3 -cmd ".timeout 1000" $database "INSERT INTO dashboard (server,type,variable,value,color1,color2) VALUES('Last scan','val','Date','$scandate','black','black')"
else
	sqlite3 -cmd ".timeout 1000" $database "UPDATE dashboard SET value='$scandate' WHERE type='val' AND  server='Last scan' AND variable='Date'"
fi

for dash_script in $SCRIPTPATH/dashboard_*sh ; do
	bash $dash_script > $tmp1
	grep -v ^$ $tmp1 | while read line ; do
		if [[ "$line" == *: ]] ; then
			server=${line%:*}
			echo "server=$server"
		else
			IFS=';' read -ra ADDR <<< "$line"
			tpe="${ADDR[0]}"
			variable="${ADDR[1]}"
			value="${ADDR[2]}"
			color1="${ADDR[3]}"
			color2="${ADDR[4]}"
			echo "    tpe=$tpe variable=$variable value=$value color1=$color1 color2=$color2"
			if [ "$server" != "" ] && [ "$variable" != "" ] && [ "$tpe" != "" ] ; then
				if [ "$color1" = "" ] ; then color1=black ; fi
				if [ "$color2" = "" ] ; then color1=grey  ; fi
				ovariable=$(sqlite3 -cmd ".timeout 1000" $database "SELECT variable FROM dashboard WHERE type='$tpe' AND variable='$variable'")
				#echo "SELECT variable FROM dashboard WHERE type='$tpe' AND  server='$server' AND variable='$variable' ->$ovariable"
				if [ "$ovariable" = "" ] ; then
					sqlite3 -cmd ".timeout 1000" $database "DELETE FROM dashboard WHERE server='$server' AND variable='$variable'"
					sqlite3 -cmd ".timeout 1000" $database "INSERT INTO dashboard (server,type,variable,value,color1,color2) VALUES('$server','$tpe','$variable','$value','$color1','$color2')"
				else
					ovalue=$(sqlite3 $database "SELECT value FROM dashboard WHERE type='$tpe' AND  server='$server' AND variable='$variable'")
					sqlite3 -cmd ".timeout 1000" $database "UPDATE dashboard SET value='$value' WHERE type='$tpe' AND  server='$server' AND variable='$variable'"
					sqlite3 -cmd ".timeout 1000" $database "UPDATE dashboard SET color1='$color1' WHERE type='$tpe' AND  server='$server' AND variable='$variable'"
					sqlite3 -cmd ".timeout 1000" $database "UPDATE dashboard SET color2='$color2' WHERE type='$tpe' AND  server='$server' AND variable='$variable'"
					if [ "$value" != "$ovalue" ] ; then
						sqlite3 -cmd ".timeout 1000" $database "UPDATE config SET value='yes' WHERE attribute='run:param' AND item='changed'"
					fi
				fi
			fi
				
		fi
	done
done
rm -f $tmp1 $tmp2

exit
				
