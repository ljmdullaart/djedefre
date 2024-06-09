#!/bin/bash
#INSTALLEDFROM verlaine:/home/ljm/src/system
#INSTALL@ /usr/local/bin/hplevelmail
TMP1=/tmp/hplevel1.$$
TMP2=/tmp/hplevel2.$$

if [ "$1" = "" ] ; then
	prt=laserjet
	iprt=$(host laserjet)
	iprt=${iprt##* }
elif [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	prt="$1"
	iprt="$1"
else
	prt=$1
	iprt=$(host $1)
	iprt=${iprt##* }
fi

uri=$(hp-makeuri $iprt | sed -n 's/.*URI: //p')

echo "$prt:"

hp-levels -d "$uri" | sed 's/....m//g' > $TMP1

cat $TMP1 | while read line; do
	case "$line" in
	(*toner*)
		color=${line%% *}
		tcolor=${color,,}
		;;
	(Part*)
		part=${line##* }
		;;
	(Health*)
		health=${line##* }
		;;
	(\|*)
		pct=${line##* }
		pct=${pct%\%*)}
		ocolor=grey
		if [ $pct -lt 25 ] ; then ocolor=burlywood1 ; fi
		if [ $pct -lt 10 ] ; then ocolor=tomato ; fi
		echo "pct;$color;$pct;$tcolor;$ocolor"
		;;
	esac
done

echo ''
		
rm -f $TMP1 $TMP2

exit
