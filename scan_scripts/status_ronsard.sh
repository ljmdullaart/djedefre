#!/bin/bash

if [ "$1" = "-v" ] ; then
	verbose=yes
else
	verbose=no
fi

TMP=/tmp/status_ronsard.$$

#ljm       2239  2151 47  2021 ?        39-05:45:44 /opt/VirtualBox/VBoxHeadless --comment Win10 --startvm e9967a6c-574e-4ad0-be11-03fca4415279 --vrde config
#ljm       2303  2151 10  2021 ?        8-10:48:24 /opt/VirtualBox/VBoxHeadless --comment win7 --startvm dacaa2a6-0c26-4784-a84f-b9b3df6ff686 --vrde config
#ljm       2366  2151  8  2021 ?        6-14:43:30 /opt/VirtualBox/VBoxHeadless --comment UnifyNetworkController --startvm b92ce5ca-18e9-436f-b5e5-1d2ca708374c --vrde config

ssh ronsard.home ps -ef | grep VBoxHeadless > $TMP

down=no

for vhost in Win10 win7 UnifyNetworkController nullboard ; do
	if grep -q $vhost $TMP ; then
		if [ $verbose = yes ] ; then
			echo "$vhost is up"
		fi
	else
		down=yes
		if [ $verbose = yes ] ; then
			echo "$vhost is down"
		fi
	fi
done

rm -f $TMP

if [ $verbose = yes ] ; then
	echo "Down=$down"
fi

if [ $down = no ] ; then
	exit 0
else
	exit 1
fi


