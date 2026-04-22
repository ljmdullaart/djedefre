#!/bin/bash

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


