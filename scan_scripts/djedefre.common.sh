#!/bin/bash

if [ "$1" = "-v" ] ; then 
	verbose=yes
elif [ "$1" = "-h" ] ; then 
	cat <<EOF
NAME: $0 - common settings for djedefre scanscripts
USAGE: . $0
       $0 -h
       $0 -v
DESCRIPTION:
$0 does a number of settings that are common to all
djedefre scanscripts. Because it sets variables, it
needs to be sourced into the scanscript.

Config  files  may  be called "djedefre.config"  or
"djedefre.conf". They are searched in the following
order:

/etc
/opt/djedefre/etc
/usr/local/etc
/var/local/etc
~/.   (f.e. ~/.djedefre.conf)
current directory

Running $0 as stand-alone allows two flags:

-h : Print this help and exit
-v : Print a list of settings

EOF
exit 0
fi

debug(){
	if [ "$DEBUG" = "yes" ] ; then
		echo $*
	fi
}



#                   __ _
#   ___ ___  _ __  / _(_) __ _
#  / __/ _ \| '_ \| |_| |/ _` |
# | (_| (_) | | | |  _| | (_| |
#  \___\___/|_| |_|_| |_|\__, |
#                        |___/

configs=''
database=djedefre.db
logfile=''

parse_config (){
	file=$1
	if [ -f "$file" ] ; then
		configs="$configs $file"
		var=$(sed -n 's/^database=//p' "$file")
		if [ "$var" != "" ] ; then database="$var" ; fi
		var=$(sed -n 's/^logfile=//p' "$file")
		if [ "$var" != "" ] ; then logfile="$var" ; fi
	fi
}

parse_config '/etc/djedefre.config'
parse_config '/etc/djedefre.conf'
parse_config '/opt/djedefre/etc/djedefre.config'
parse_config '/opt/djedefre/etc/djedefre.conf'
parse_config '/usr/local/etc/djedefre.config'
parse_config '/usr/local/etc/djedefre.conf'
parse_config '/var/local/etc/djedefre.config'
parse_config '/var/local/etc/djedefre.conf'
parse_config "$HOME/.djedefre.config"
parse_config "$HOME/.djedefre.conf"
parse_config 'djedefre.config'
parse_config 'djedefre.conf'

networkdefinitions=''
if [ -f /etc/network.definitions ] ; then networkdefinitions=/etc/network.definitions ; fi
if [ -f /opt/djedefre/etc/network.definitions ] ; then networkdefinitions=/opt/djedefre/etc/network.definitions ; fi
if [ -f /usr/local/etc/network.definitions ] ; then networkdefinitions=/usr/local/etc/network.definitions ; fi
if [ -f /var/local/etc/network.definitions ] ; then networkdefinitions=/var/local/etc/network.definitions ; fi
if [ -f ~/.network.definitions ] ; then networkdefinitions=~/.network.definitions ; fi
if [ -f network.definitions ] ; then networkdefinitions=network.definitions ; fi

#  _                   _             
# | | ___   __ _  __ _(_)_ __   __ _ 
# | |/ _ \ / _` |/ _` | | '_ \ / _` |
# | | (_) | (_| | (_| | | | | | (_| |
# |_|\___/ \__, |\__, |_|_| |_|\__, |
#          |___/ |___/         |___/

djedefre_log(){
	if [ "$logfile" = "" ] ; then
		logger "DJEDEFRE: $1"
	else
		now=$(date)
		echo "$now $1" >> "$logfile"
	fi
}


#      _       _        _                    
#   __| | __ _| |_ __ _| |__   __ _ ___  ___ 
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
### DATABASE:

db_retval='';
	### Database functions return values in $dbretval
#------------------------------ interfaces -----------------------------------------------------------
add_if(){
	### add_if <interface-IP>  [server-ID] : add an interface if it did not exist; return if-id
	interface="$1"
	server="$2"
	if_old=$(sqlite3 "$database" "SELECT id FROM interfaces WHERE ip='$interface'")
	if [ "$if_old" = "" ] ; then
		if [ "$server" = "" ] ; then
			sqlite3 "$database" "INSERT INTO interfaces (ip) VALUES ('$interface')"
		else
			sqlite3 "$database" "INSERT INTO interfaces (ip,host) VALUES ('$interface','$server')"
		fi
	else
		if [ "$server" != "" ] ; then
			sqlite3 "$database" "UPDATE interfaces SET host='$server' WHERE ip='$interface'"
		fi
	fi
	if_old=$(sqlite3 "$database" "SELECT id FROM interfaces WHERE ip='$interface'")
	db_retval="$if_old"
}


#------------------------------ server ---------------------------------------------------------------

add_server(){
	### add_server <servername> : add a server if not exists; return server ID.
	name="$1"
	server_old=$(sqlite3 "$database" "SELECT id FROM server WHERE name='$name'")
	if [ "$server_old" = "" ] ; then
		sqlite3 "$database" "INSERT INTO server (name) VALUES ('$name')"
	fi
	server_old=$(sqlite3 "$database" "SELECT id FROM server WHERE name='$name'")
	db_retval="$server_old"
}


#------------------------------ subnet ---------------------------------------------------------------

add_subnet(){
	### add_subnet <nwaddress> <cidr-bits> : Add a subnet if it does not exist; return the ID
	nwaddress=$(echo $1|sed 's/ //g')
	cidr="$2"
	debug "nwaddress=$nwaddress   cidr=$cidr"
	if [[ $nwaddress =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		if [[ $cidr =~ ^[0-9]+$ ]] ; then
			old_value=$(sqlite3 "$database" "SELECT id FROM subnet WHERE nwaddress='$nwaddress'")
			if [ "$old_value" = "" ] ; then
				sqlite3 "$database" "INSERT INTO subnet (nwaddress,cidr) VALUES ('$nwaddress','$cidr')"
			fi
			old_value=$(sqlite3 "$database" "SELECT id FROM subnet WHERE nwaddress='$nwaddress'")
			db_retval="$old_value"
		else
			debug wrong cidr $cidr
		fi
	else
		debug wrong ip $nwaddress
	fi
}




if [ "$verbose" = "yes" ] ; then
	echo "Configs read are $configs"
	echo "networkdefinitions = $networkdefinitions"
	echo "database           = $database"
	echo "logfile            = $logfile"
	echo "$db_retval"
fi
