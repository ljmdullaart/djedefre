#!/bin/bash



SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

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

#            _     _                                                             
#   __ _  __| | __| |  _ __ ___   ___    __ _ ___   ___  ___ _ ____   _____ _ __ 
#  / _` |/ _` |/ _` | | '_ ` _ \ / _ \  / _` / __| / __|/ _ \ '__\ \ / / _ \ '__|
# | (_| | (_| | (_| | | | | | | |  __/ | (_| \__ \ \__ \  __/ |   \ V /  __/ |   
#  \__,_|\__,_|\__,_| |_| |_| |_|\___|  \__,_|___/ |___/\___|_|    \_/ \___|_|   
# 

me=$(hostname -s)
add_server "$me"
serverid=$db_retval


 
#  _       _             __                                       _ 
# (_)_ __ | |_ ___ _ __ / _| __ _  ___ ___  ___    __ _ _ __   __| |
# | | '_ \| __/ _ \ '__| |_ / _` |/ __/ _ \/ __|  / _` | '_ \ / _` |
# | | | | | ||  __/ |  |  _| (_| | (_|  __/\__ \ | (_| | | | | (_| |
# |_|_| |_|\__\___|_|  |_|  \__,_|\___\___||___/  \__,_|_| |_|\__,_|
#                                                                   
#            _                _       
#  ___ _   _| |__  _ __   ___| |_ ___ 
# / __| | | | '_ \| '_ \ / _ \ __/ __|
# \__ \ |_| | |_) | | | |  __/ |_\__ \
# |___/\__,_|_.__/|_| |_|\___|\__|___/
#  

ip addr |
	grep -v '127.0.0.1' |
	sed -n 's/.*inet \(.*\)\/\(.*\) brd.*/\1 \2/p' | 
	while read ip cidr ; do
		add_if $ip $serverid
		nwaddr=$(ipcalc $ip/$cidr | sed -n 's/\/.*//;s/^Network:\s*//p')
		add_subnet $nwaddr $cidr
	done
