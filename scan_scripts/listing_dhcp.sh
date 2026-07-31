#!/bin/bash

if [ "$1" = "-htm" ] ; then
	echo "<h2>DHCP</h2>"
	date
	echo "<table>"
	ssh root@nameserver cat /var/log/daemon.log  /var/log/daemon.log.1 |
	sed -n 's/ to .*//;s/.*DHCPACK on //p' |
	sort -u |
	while read ip ; do
		hst=$(host $ip | sed 's/.* //')
		name=$(printf '%-20.20s' "$hst")
		echo "<tr><td>$hst </td><td>$ip</td></tr>"
	done |
	sort |
	grep -v  'NXDOMAIN' 

	ssh root@nameserver cat /var/log/daemon.log  /var/log/daemon.log.1 |
	sed -n 's/ to .*//;s/.*DHCPACK on //p' |
	sort -u |
	while read ip ; do
		hst=$(host $ip | sed 's/.* //')
		name=$(printf '%-20.20s' "$hst")
		echo "<tr><td>$hst </td><td>$ip</td></tr>"
	done |
	grep  'NXDOMAIN'
	echo "</table>"
else
	echo "               DHCP HOSTS"
	echo "-----------------------------------------"
	ssh root@nameserver cat /var/log/daemon.log  /var/log/daemon.log.1 |
	sed -n 's/ to .*//;s/.*DHCPACK on //p' |
	sort -u |
	while read ip ; do
		hst=$(host $ip | sed 's/.* //')
		name=$(printf '%-20.20s' "$hst")
		echo "$name  $ip"
	done |
	grep -v 'NXDOMAIN' | sort
	ssh root@nameserver cat /var/log/daemon.log  /var/log/daemon.log.1 |
	sed -n 's/ to .*//;s/.*DHCPACK on //p' |
	sort -u |
	while read ip ; do
		hst=$(host $ip | sed 's/.* //')
		name=$(printf '%-20.20s' "$hst")
		echo "$name  $ip"
	done |
	grep  'NXDOMAIN' | sort
fi

