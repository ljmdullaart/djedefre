#!/bin/bash
#INSTALLEDFROM verlaine:/home/ljm/src/system
#INSTALL@ /usr/local/bin/hplevelmail
TMP1=/tmp/hplevel1.$$
TMP2=/tmp/hplevel2.$$

if [ "$1" = "" ] ; then
	prt=Epson
	iprt=$(host printer.home)
	iprt=${iprt##* }
elif [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	prt="$1"
	iprt="$1"
else
	prt=$1
	iprt=$(host $1)
	iprt=${iprt##* }
fi

uri='http://printer.home/PRESENTATION/HTML/TOP/PRTINFO.HTML'

echo "$prt:"

curl "$uri" > $TMP1

for color in K Y M C ; do
	pct=$(sed -n  "s/.*IMAGE.Ink_$color.*height='\([0-9]*\).*/\1/p" $TMP1)
	case "$color" in
	(K) tcolor=black ;;
	(Y) tcolor=yellow ;;
	(M) tcolor=magenta ;;
	(C) tcolor=cyan ;;
	esac
	ocolor=grey
	if [ $pct -lt 25 ] ; then ocolor=burlywood1 ; fi
	if [ $pct -lt 10 ] ; then ocolor=tomato ; fi
	echo "pct;$tcolor;$pct;$tcolor;$ocolor"
done

echo ''
		
rm -f $TMP1 $TMP2

exit
