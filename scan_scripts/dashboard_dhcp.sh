#!/bin/bash

tmp1=/tmp/dje_dash.$$.1
tmp2=/tmp/dje_dash.$$.2

ssh root@phi grep DHCP  /var/log/daemon.log >> $tmp1
mins=61
deldate=$(date -d "-$mins minutes" '+%b %_d %H:%M')
while ! grep -q "^$deldate" $tmp1 && [ $mins -ge 30 ] ; do
	mins=$((mins-1))
	deldate=$(date -d "-$mins minutes" '+%b %_d %H:%M')
done

if  ! grep -q "^$deldate" $tmp1  ; then
	exit
fi

sed -i "1,/^$deldate/d" $tmp1


dhcpack=$(grep -c DHCPACK $tmp1)
dhcpnack=$(grep -c DHCPNAK $tmp1)
dhcpdiscover=$(grep -c DHCPDISCOVER $tmp1)
dhcpinform=$(grep -c DHCPINFORM $tmp1)
dhcpoffer=$(grep -c DHCPOFFER $tmp1)
dhcprelease=$(grep -c DHCPRELEASE $tmp1)
dhcprequest=$(grep -c DHCPREQUEST $tmp1)

colornack=red
if [ "$dhcpnack" = "0" ] ; then colornack=black ; fi

echo "dhcp:"
echo "val;dhcp request;$dhcprequest;black;black"
echo "val;dhcp discover;$dhcpdiscover;black;black"
echo "val;dhcp ack;$dhcpack;black;black"
echo "val;dhcp nack;$dhcpnack;black;$colornack"
echo "val;dhcp offer;$dhcpoffer;black;black"
echo "val;dhcp release;$dhcprelease;black;black"
echo "val;dhcp inform;$dhcpinform;black;black"

echo ''

external=error
internal=error
colext=red
colint=red

if nslookup google.com > /dev/null 2>&1 ; then
	external=ok
	colext=black
fi
if nslookup pi.home > /dev/null 2>&1 ; then
	internal=ok
	colint=black
fi
echo "dns:"
echo "val;dns internal;$internal;$colint;$colint"
echo "val;dns external;$external;$colext;$colext"
echo ''


rm -f $tmp1 $tmp2
