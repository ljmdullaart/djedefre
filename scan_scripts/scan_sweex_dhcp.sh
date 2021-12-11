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

IPMAC=/tmp/ipmac.$$
TMP=/tmp/exp.$$

host="$1"
TMP=/tmp/exp.$$


helptext(){
cat <<EOF
NAME: scan_sweex_dhcp
SYNOPSIS:
    scan_sweex_dhcp host
    scan_sweex_dhcp -h

DESCRIPTION:

scan_sweex_dhcp queries a Sweex LW050 router and stores
the information in a djedefre database. When the IP of an
interface (determined by MAC-id) changes, it is updated in 
the database.

scan_sweex_dhcp will ask for a user-ID and password if there
is no corresponding entry in .dedefre.pw.

EOF
}

if [ "$database" = "" ] ; then
	helptext
	exit 0
fi
if [ $database = "-h" ] ; then
	helptext
	exit 0
fi

if [ -f ~/.djedefre.pw ] ; then
	user=$(sed -n "s/:[^:]*$//;s/$host://p" ~/.djedefre.pw)
	pw=$(sed -n "s/:.*:/;/;s/$host;//p" ~/.djedefre.pw)
fi
if [ -f .djedefre.pw ] ; then
	user=$(sed -n "s/:[^:]*$//;s/$host://p" .djedefre.pw)
	pw=$(sed -n "s/:.*:/;/;s/$host;//p" .djedefre.pw)
fi
if [ "$user" = "" ]; then
	read -p 'Userid:   ' user
fi
if [ "$pw" = "" ] ; then
	read -p 'Password: ' pw
fi

print "$user:$pw"
curl -u $user:$pw http://nogeentje.home/userRpm/AssignedIpAddrListRpm.htm?Refresh=Refresh > $TMP
grep '..-..-..-..' $TMP | sed 's/-/:/g;s/"//g;s/,/ /g' | tr '[:upper:]' '[:lower:]' | 
   while read name mac ip lease ; do
	echo $ip $mac >> $IPMAC
done

egrep '[0-9]' $IPMAC |
while read ip mac ; do
	echo "# doing $ip $mac"
	add_if $ip
	sqlite3 $database "UPDATE interfaces SET hostname='$hostname' WHERE macid='$mac'";
done 


sqlite3 -separator '	'  $database "SELECT * FROM interfaces ORDER BY host" 


rm -f  $TMP
rm -f  $IPMAC
rm -f  $DHCP
