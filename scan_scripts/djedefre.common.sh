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

debug_common(){
	if [ "$DEBUG" = "yes" ] ; then
		echo "$@"
	fi
}

common_tmp=/tmp/$$.commontmp


#                   __ _
#   ___ ___  _ __  / _(_) __ _
#  / __/ _ \| '_ \| |_| |/ _` |
# | (_| (_) | | | |  _| | (_| |
#  \___\___/|_| |_|_| |_|\__, |
#                        |___/

configs=''
database=djedefre.db
logfile='djedefre.log'

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

ignore_subnet=none
if [ -f ignore_subnet ] ; then
	ignore_subnet=ignore_subnet
elif [ -f ../ignore_subnet ] ; then
	ignore_subnet=../ignore_subnet
elif [ -f ~/.ignore_subnet ] ; then
	ignore_subnet=~/.ignore_subnet
elif [ -f database/ignore_subnet ] ; then
	ignore_subnet=database/ignore_subnet
fi

ignores=/tmp/djedefre.ignores
touch $ignores

if [ -f $ignore_subnet ] ; then
	sed -n 's/\// /p' $ignore_subnet  | while read -r net cidr ; do
		nmap -sL -n  "$net/$cidr" | sed 's/.* //' | grep '[0-9]' >$ignores
	done
	grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' $ignore_subnet  >$ignores
fi

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

#                                  _ 
#   __ _  ___ _ __   ___ _ __ __ _| |
#  / _` |/ _ \ '_ \ / _ \ '__/ _` | |
# | (_| |  __/ | | |  __/ | | (_| | |
#  \__, |\___|_| |_|\___|_|  \__,_|_|
#  |___/                             
#   __                  _   _                 
#  / _|_   _ _ __   ___| |_(_) ___  _ __  ___ 
# | |_| | | | '_ \ / __| __| |/ _ \| '_ \/ __|
# |  _| |_| | | | | (__| |_| | (_) | | | \__ \
# |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
#                
cmd_on(){   # $1=interface id in the interface table, rest are the command and arguments
	cmd_if=$1
	shift
	cmd_access=$(SQL "SELECT access FROM interfaces WHERE id=$cmd_if")
	cmd_ip=$(SQL "SELECT ip FROM interfaces WHERE id=$cmd_if" | head -1)
	djedefre_log  "cmd_on    $cmd_ip $*" 
	if [ "$cmd_access" = "ssh" ] ; then
		echo exit| timeout 5 ssh -o PasswordAuthentication=no -o ConnectTimeout=4  "$cmd_ip" "$*"  | dos2unix >$common_tmp
	elif [ "$cmd_access" = "ssh(admin)" ] ; then
		echo exit| timeout 5 ssh -o PasswordAuthentication=no -o ConnectTimeout=4  "admin@$cmd_ip" "$*"  | dos2unix >$common_tmp
	elif [ "$cmd_access" = "ssh(root)" ] ; then
		echo exit| timeout 5 ssh -o PasswordAuthentication=no -o ConnectTimeout=4  "root@$cmd_ip" "$*" | dos2unix >$common_tmp
	elif [ "$cmd_access" = "dotelnet" ] ; then
		echo exit | timeout 5 dotelnet "$cmd_ip" "$*"  | dos2unix >$common_tmp
	else
		echo "Sorry"  >$common_tmp
	fi
	cat "$common_tmp"
	rm -f "$common_tmp"
}


in_subnet() {
    local ip=$1
    local subnet=$2
    local ip_net
    ip_net=$(ipcalc -n "$ip/${subnet#*/}" | grep Network | awk '{print $2}')
    local target_net
    target_net=$(ipcalc -n "$subnet" | grep Network | awk '{print $2}')
    if [ "$ip_net" = "$target_net" ]; then
        return 0 # Match
    else
        return 1 # Geen match
    fi
}

setvarstring() {
    local name="$1"
    local value="$2"
    local str="$3"
    if echo "$str" | grep -E -q "^$name=|;$name=" ; then
        echo "$str" | sed "s/\(^\|;\)$name=[^;]*/\1$name=$value/"
    else
        echo "$str;$name=$value"
    fi
}


clean_mac() {
    local raw_mac="$1"
    local clean
    clean=$(echo "$raw_mac" | sed 's/[.: -]//g' | tr 'A-Z' 'a-z')
    if [[ ! "$clean" =~ ^[0-9a-f]{12}$ ]]; then
        echo "Fout: Ongeldig MAC-adres ($raw_mac)" >&2
	echo '00:00:00:00:00:00'
        return 1
    fi
    
    # 3. Zet de dubbele punten terug tussen elke 2 tekens
    echo "$clean" | sed -E 's/(..)(..)(..)(..)(..)(..)/\1:\2:\3:\4:\5:\6/'
}

#      _       _        _                    
#   __| | __ _| |_ __ _| |__   __ _ ___  ___ 
#  / _` |/ _` | __/ _` | '_ \ / _` / __|/ _ \
# | (_| | (_| | || (_| | |_) | (_| \__ \  __/
#  \__,_|\__,_|\__\__,_|_.__/ \__,_|___/\___|
### DATABASE:
SQL(){
	djedefre_log "SQL $*  "
	if sqlite3  -separator ' ' -cmd ".timeout 1000"  "$database" "$*" ; then 
		:
	else 
		echo "ERROR: $*" >&2
	fi
}

db_retval='';
	### Database functions return values in $dbretval or on stdout

delfromid(){
	local tabel="$1"
	local id="$2"
	SQL "DELETE FROM $tabel WHERE id=$id"
}

setfromid(){
	local tabel="$1"
	local id="$2"
	local var="$3"
	local val="$4"
	local dtype=text
	djedefre_log "setfromid: UPDATE $tabel SET $var=$val WHERE id=$id"
	dtype=$(SQL "pragma table_info ($tabel)" | awk -v "col=$var" '$2== col {print $3}'| tail -1)
	case $dtype in
	text) SQL "UPDATE $tabel SET $var='$val' WHERE id=$id" ;;
	integer) SQL "UPDATE $tabel SET $var=$val WHERE id=$id" ;;
	*) echo "dtype $dtype of column $var in $tabel is unknown"
	esac
}
valfromid(){
	local tabel="$1"
	local id="$2"
	local var="$3"
	djedefre_log "valfromid: SELECT $var FROM $tabel WHERE id=$id"
	SQL "SELECT $var FROM $tabel WHERE id=$id"
}
idfromval(){
        local tabel="$1"
        shift
        local var="$1"
        local val
        local where="WHERE 1=1"
        while [ "$var" != "" ] ; do
                shift
                val="$1"
                shift
                local dtype
                dtype=$(SQL "pragma table_info($tabel)" | grep -w "$var" | tail -1 | cut -d, -f3)
                case "$dtype" in
                text*|TEXT*)   where="$where AND $var='$val'" ;;
                int*|INT*)     where="$where AND $var=$val" ;;
                *)             where="$where AND $var='$val'" ;; # Safe fallback to text
                esac
                var="$1"
        done
	
        SQL "SELECT id FROM $tabel $where"
}
optfromid(){
	local tabel="$1"
	local id="$2"
	SQL "SELECT options FROM $tabel WHERE id=$id"
}
	
#------------------------------ interfaces -----------------------------------------------------------
set_ipmac(){
	ip="$1"
	mac="$2"
	if [ "$ip" = '' ] ; then return 1; fi
	if [ "$mac" = '' ] ; then return 1; fi
	local if_id;
	if_id=$(idfromval interfaces ip "$ip")
	if [ "$if_id" = "" ] ; then
		if_id=$(idfromval interfaces macid "$mac")
	fi
	if [ "$if_id" = "" ] ; then return 1; fi  # do not create new interfaces as byproduct
	SQL "UPDATE interfaces SET ip='$ip' WHERE id=$if_id"
	SQL "UPDATE interfaces SET macid='$mac' WHERE id=$if_id"
	echo $if_id
}
	
# Call with: declare -A interface_data
#            interface_data[ip]="$interface"
#            interface_data[host]="$srvid"
#            set_interface interface_data
#            unset interface_data

clean_mac() {
    local raw_mac="$1"
    # Verwijder alle ., :, spaties en - en maak lowercase
    local clean
    clean=$(echo "$raw_mac" | sed 's/[.: -]//g' | tr 'A-Z' 'a-z')
    
    # Controleer of we exact 12 hexadecimale tekens overhebben
    if [[ ! "$clean" =~ ^[0-9a-f]{12}$ ]]; then
        return 1
    fi
    
    # Voeg dubbele punten toe
    echo "$clean" | sed -E 's/(..)(..)(..)(..)(..)(..)/\1:\2:\3:\4:\5:\6/'
}

set_interface() {
    local -n data_ref=$1
    data_ref[ip]="${data_ref[ip]//[[:space:]]/}"
    data_ref[macid]="${data_ref[macid]//[[:space:]]/}"
    data_ref[id]="${data_ref[id]//[[:space:]]/}"
    
    # --- INTEGRATIE CLEAN_MAC ---
    # Als er een macid is meegegeven, gaan we deze valideren en opschonen
    if [[ -n "${data_ref[macid]}" ]]; then
        local cleaned
        if cleaned=$(clean_mac "${data_ref[macid]}"); then
            data_ref[macid]="$cleaned"
        else
            djedefre_log "set_interface: FOUT - Ongeldig MAC-adres meegegeven (${data_ref[macid]})"
            echo "Fout: Ongeldig MAC-adres (${data_ref[macid]})" >&2
            db_retval=""
            return 1
        fi
    fi

    local ip="${data_ref[ip]}"
    local mac="${data_ref[macid]}"
    local forced_id="${data_ref[id]}"
    
    if [[ -z "$ip$mac$forced_id" ]]; then
        db_retval=""
        return
    fi
    
    # --- UPDATE via Forced ID ---
    if [[ -n "$forced_id" ]]; then
        local updates=()
        for key in "${!data_ref[@]}"; do
            [[ "$key" == "id" ]] && continue
            # Sla lege velden over zodat bestaande data niet wordt overschreven
            [[ -z "${data_ref[$key]}" ]] && continue
            
            local val="${data_ref[$key]//\'/\'\'}"
            updates+=("$key='$val'")
        done

        SQL "
            UPDATE interfaces
            SET $(printf '%s,' "${updates[@]}" | sed 's/,$//')
            WHERE id=$forced_id;
        "

        db_retval="$forced_id"
        djedefre_log "set_interface: forced update id=$forced_id"
        return
    fi
    
    # --- UPSERT via IP ---
    if [[ -n "$ip" ]]; then
        local cols=() vals=() updates=()

        for key in "${!data_ref[@]}"; do
            [[ "$key" == "id" ]] && continue
            
            local val="${data_ref[$key]//\'/\'\'}"
            cols+=("$key")
            vals+=("'$val'")
            
            # Voorkom dat bestaande data (zoals macid) wordt leeggemaakt bij een conflict
            if [[ -n "$val" ]]; then
                updates+=("$key=excluded.$key")
            else
                updates+=("$key=interfaces.$key")
            fi
        done

        SQL "
            INSERT INTO interfaces ($(printf '%s,' "${cols[@]}" | sed 's/,$//'))
            VALUES ($(printf '%s,' "${vals[@]}" | sed 's/,$//'))
            ON CONFLICT(ip) DO UPDATE SET
                $(printf '%s,' "${updates[@]}" | sed 's/,$//');
        "
        db_retval=$(SQL "SELECT id FROM interfaces WHERE ip='$ip' LIMIT 1;")
        djedefre_log "set_interface: upsert via ip=$ip id=$db_retval"
        return
    fi

    # --- UPSERT via macid (fallback) ---
    local existing_id
    existing_id=$(SQL "SELECT id FROM interfaces WHERE macid='$mac' LIMIT 1;")
    if [[ -n "$existing_id" ]]; then
        local updates=()
        for key in "${!data_ref[@]}"; do
            [[ "$key" == "id" ]] && continue
            # Sla lege velden over bij update via fallback
            [[ -z "${data_ref[$key]}" ]] && continue
            
            local val="${data_ref[$key]//\'/\'\'}"
            updates+=("$key='$val'")
        done
        SQL "
            UPDATE interfaces
            SET $(printf '%s,' "${updates[@]}" | sed 's/,$//')
            WHERE id=$existing_id;
        "
        db_retval="$existing_id"
        djedefre_log "set_interface: update via macid=$mac id=$existing_id"
        return
    fi
    
    # --- Standaard INSERT via macid ---
    local cols=() vals=()
    for key in "${!data_ref[@]}"; do
        [[ "$key" == "id" ]] && continue
        local val="${data_ref[$key]//\'/\'\'}"
        cols+=("$key")
        vals+=("'$val'")
    done
    SQL "
        INSERT INTO interfaces ($(printf '%s,' "${cols[@]}" | sed 's/,$//'))
        VALUES ($(printf '%s,' "${vals[@]}" | sed 's/,$//'));
    "
    db_retval=$(SQL "SELECT id FROM interfaces WHERE macid='$mac' LIMIT 1;")
    djedefre_log "set_interface: insert via macid=$mac id=$db_retval"
}


# list_interfaces | while read id ip macid hostname host subnet access connect_if port ifname switch options ; do
list_interfaces(){
	SQL 'SELECT id,ip,macid,hostname,host,subnet,access,connect_if,port,ifname,switch,options FROM interfaces'
}
idfrom_interfaces(){
	djedefre_log "idfrom_interfaces $*" 
	local var
	local val

	local select=''
	while [ "$1" != "" ] ; do
		var="$1"
		shift
		val="$1"
		shift
		case "$var" in 
			(ip)	select="$select AND ip='$val'" ;;
			(macid)	select="$select AND macid='$val'" ;;
			(subnet)	select="$select AND subnet=$val" ;;
			(host)
				if [ "$val" = "NULL" ] ; then
					select="$select AND host IS NULL" 
				else
					select="$select AND host=$val"
				fi
				;;
			(hostname)	select="$select AND hostname='$val'" ;;
			(access)	select="$select AND access='$val'" ;;
		esac
	done
	select="${select# AND}"
	djedefre_log "idfrom_interfaces: SELECT id FROM interfaces WHERE $select"
	SQL "SELECT id FROM interfaces WHERE $select"
}


#------------------------------ server ---------------------------------------------------------------
# Call with: declare -A server_data
#            server_data[name]="$server"
#            set_server server_data
#            unset server_data

set_server() {
    local -n data_ref=$1
    local name="${data_ref[name]}"

    # Bouw kolommen, waarden en update-set
    local cols="" vals="" updates=""

    for key in "${!data_ref[@]}"; do
        local val="${data_ref[$key]}"
        cols+="$key, "
        vals+="'${val//\'/\'\'}', "

        # name is de UNIQUE key → niet updaten
        [[ "$key" == "name" ]] && continue

        updates+="$key=excluded.$key, "
    done

    # UPSERT uitvoeren
    SQL "
        INSERT INTO server (${cols%, })
        VALUES (${vals%, })
        ON CONFLICT(name) DO UPDATE SET ${updates%, };
    "

    # ID ophalen
    db_retval=$(SQL "SELECT id FROM server WHERE name='$name' LIMIT 1;")
}

list_server(){
	SQL "SELECT id FROM server"
}

list_vboxhosts(){
	SQL select options from server                  |
		sed -n 's/.*vboxhost=\([0-9]*\).*/\1/p' |
		sort -u
}

del_server(){
	local srv_id=$1
	SQL "DELETE FROM server WHERE id=$srv_id"
	SQL "DELETE FROM interfaces WHERE host=$srv_id"
	SQL "DELETE FROM l2connect WHERE from_tbl='server' AND from_id=$srv_id"
	SQL "DELETE FROM l2connect WHERE to_tbl='server' AND to_id=$srv_id"
	SQL "DELETE FROM pages WHERE tbl='server' AND item=$srv_id"
}


#------------------------------- pages --------------------------------------------------------------

pages_insert(){
	SQL "INSERT INTO pages (page,tbl,item,xcoord,ycoord) VALUES ('$1','$2',$3,$4,$5)"
}

pages_delete(){
	SQL "DELETE FROM pages WHERE id=$1"
}

list_pages(){
	SQL "SELECT id FROM pages"
}

#------------------------------ subnet ---------------------------------------------------------------

# Call with: declare -A subnet_data
#            subnet_data[name]="$subnet"
#            set_subnet subnet_data
#            unset subnet_data
set_subnet() {
    local -n data_ref=$1

    # --- Normaliseer nwaddress en cidr ---
    data_ref[nwaddress]="${data_ref[nwaddress]//[[:space:]]/}"
    data_ref[cidr]="${data_ref[cidr]//[[:space:]]/}"

    # --- Bouw kolommen en waarden ---
    local cols=() vals=() updates=()

    for key in "${!data_ref[@]}"; do
        [[ "$key" == "id" ]] && continue
        local val="${data_ref[$key]//\'/\'\'}"
        cols+=("$key")
        vals+=("'$val'")
        updates+=("$key=excluded.$key")
    done

    # --- UPSERT ---
    SQL "
        INSERT INTO subnet ($(printf '%s,' "${cols[@]}" | sed 's/,$//'))
        VALUES ($(printf '%s,' "${vals[@]}" | sed 's/,$//'))
        ON CONFLICT(nwaddress) DO UPDATE SET
            $(printf '%s,' "${updates[@]}" | sed 's/,$//');
    "

    # --- Haal ID op ---
    db_retval=$(SQL "
        SELECT id FROM subnet
        WHERE nwaddress='${data_ref[nwaddress]//\'/\'\'}'
        LIMIT 1;
    ")

    djedefre_log "subnet upsert id=$db_retval nwaddress=${data_ref[nwaddress]}"
}


list_subnet(){
	SQL "SELECT id, nwaddress, cidr, name, access, options, source FROM subnet"
}


get_subnet() {
	local target_ip="$1"
	SQL "SELECT id, nwaddress, cidr FROM subnet WHERE nwaddress IS NOT NULL;" > $common_tmp
	# 2. Haal alle subnets op uit de SQLite database
	local nwaddress cidr
	cat $common_tmp |
	while read -r id nwaddress cidr ; do
		if in_subnet $target_ip "$nwaddress/$cidr" ; then
			echo $id
		fi
	done | head -1
}


#------------------------------ cloud ---------------------------------------------------------------

# Call with: declare -A cloud_data
#            cloud_data[name]="$cloud"
#            set_cloud cloud_data
#            unset cloud_data

set_cloud() {
    local -n data_ref=$1

    # --- Normaliseer name (UNIQUE key) ---
    data_ref[name]="${data_ref[name]//[[:space:]]/}"

    # Als name leeg is, doen we niets
    if [[ -z "${data_ref[name]}" ]]; then
        db_retval=""
        return
    fi

    # --- Bouw kolommen, waarden en update‑regels ---
    local cols=() vals=() updates=()

    for key in "${!data_ref[@]}"; do
        [[ "$key" == "id" ]] && continue
        local val="${data_ref[$key]//\'/\'\'}"
        cols+=("$key")
        vals+=("'$val'")
        updates+=("$key=excluded.$key")
    done

    # --- UPSERT op basis van UNIQUE(name) ---
    SQL "
        INSERT INTO cloud ($(printf '%s,' "${cols[@]}" | sed 's/,$//'))
        VALUES ($(printf '%s,' "${vals[@]}" | sed 's/,$//'))
        ON CONFLICT(name) DO UPDATE SET
            $(printf '%s,' "${updates[@]}" | sed 's/,$//');
    "

    # --- Haal ID op ---
    db_retval=$(SQL "
        SELECT id FROM cloud
        WHERE name='${data_ref[name]//\'/\'\'}'
        LIMIT 1;
    ")

    djedefre_log "set_cloud: upsert id=$db_retval name=${data_ref[name]}"
}


#------------------------------ l2connect ---------------------------------------------------------------
l2detete(){
	source="$1"
	SQL  "DELETE FROM l2connect WHERE source='$source'"
}
# Call with: declare -A l2_data
#            l2_data[from_tbl]="$from_tbl"
#            l2_data[from_id]="$from_id"
#            set_l2 l2_data
#            unset l2_data
set_l2(){
	local -n data_ref=$1
	local to_tbl="${data_ref[to_tbl]}"
	local to_id="${data_ref[to_id]}"
	local to_port="${data_ref[to_port]}"
	local id
	if [ "$to_id" = "" ] ; then return ; fi
	if [ "$to_tbl" = "" ] ; then return ; fi
	if [ "$to_port" = "" ] ; then
		l2_id=$(SQL "SELECT id FROM l2connect WHERE to_id=$to_id AND to_tbl='$to_tbl' LIMIT 1" )
	else
		l2_id=$(SQL "SELECT id FROM l2connect WHERE to_id=$to_id AND to_tbl='$to_tbl' AND to_port=$to_port LIMIT 1" )
	fi
	if [ "$l2_id" != "" ] ; then
		SQL "DELETE FROM l2connect WHERE id=$l2_id"
	fi
	local cols=() vals=() updates=()
	for key in "${!data_ref[@]}"; do
		[[ "$key" == "id" ]] && continue
		local val="${data_ref[$key]//\'/\'\'}"
		cols+=("$key")
		vals+=("'$val'")
		updates+=("$key=excluded.$key")
	done
	SQL "
		INSERT INTO l2connect ($(printf '%s,' "${cols[@]}" | sed 's/,$//'))
		VALUES ($(printf '%s,' "${vals[@]}" | sed 's/,$//'))
	"
}
#------------------------------ config table ---------------------------------------------------------------

set_dbconfig(){
	local attribute="$1"
	local item="$2"
	local value="$3"
	if SQL "SELECT item FROM config WHERE attribute='$attribute' AND item='$item'" | grep -q "$item" ; then
		SQL "UPDATE config SET value='$value' WHERE attribute='$attribute' AND item='$item'"
	else
		SQL "INSERT INTO config (attribute,item,value) VALUES ('$attribute','$item','$value')"
	fi
}

get_dbconfig(){
	local attribute="$1"
	local item="$2"
	SQL "SELECT value FROM config WHERE attribute='$attribute' AND item='$item'" 
}


#   ___  _     ____  
#  / _ \| |   |  _ \ 
# | | | | |   | | | |
# | |_| | |___| |_| |
#  \___/|_____|____/ 
#   







# still in :
#scan_dhcp.sh
#scan_remote_system.sh
#scan_server.sh
#scan_subnet.sh

add_server(){
	### add_server <servername> : add a server if not exists; return server ID.
	name="$1"
	server_old=$(SQL "SELECT id FROM server WHERE name='$name'")
	if [ "$server_old" = "" ] ; then
		SQL "INSERT INTO server (name) VALUES ('$name')"
	fi
	server_old=$(SQL "SELECT id FROM server WHERE name='$name'")
	db_retval="$server_old"
}

add_subnet(){
	### add_subnet <nwaddress> <cidr-bits> : Add a subnet if it does not exist; return the ID
	nwaddress="${1// /}"
	cidr="$2"
	src="$3"
	if [ "$src" = "" ] ; then
		src=Unknown
	fi
	debug_common "nwaddress=$nwaddress   cidr=$cidr"
	if [[ $nwaddress =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		if [[ $cidr =~ ^[0-9]+$ ]] ; then
			old_value=$(SQL "SELECT id FROM subnet WHERE nwaddress='$nwaddress'")
			if [ "$old_value" = "" ] ; then
				SQL "INSERT INTO subnet (nwaddress,cidr,source) VALUES ('$nwaddress','$cidr','$src')"
			else
				SQL "UPDATE subnet SET source='$src' WHERE id=$old_value"
			fi
			old_value=$(SQL "SELECT id FROM subnet WHERE nwaddress='$nwaddress'")
			db_retval="$old_value"
		else
			debug_common wrong cidr $cidr
		fi
	else
		debug_common wrong ip $nwaddress
	fi
}

if_net(){
	ips=$(SQL "SELECT ip FROM interfaces")
	for interface in $ips ; do

		ids=$(SQL "SELECT id FROM subnet")
		for snid in $ids; do
			nwadr=$(SQL "SELECT nwaddress FROM subnet WHERE id=$snid")
			if [[ $nwaddress =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
				cidr=$(SQL "SELECT cidr FROM subnet WHERE id=$snid")
				if echo $interface | grepcidr $nwadr/$cidr ; then
					SQL "UPDATE interfaces SET subnet=$snid WHERE ip='$interface'"
				fi
			fi
		done
	done
}


if [ "$verbose" = "yes" ] ; then
	echo "Configs read are $configs"
	echo "networkdefinitions = $networkdefinitions"
	echo "database           = $database"
	echo "logfile            = $logfile"
	echo "$db_retval"
fi



