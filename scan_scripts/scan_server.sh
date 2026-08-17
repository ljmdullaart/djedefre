#!/bin/bash

tmp=/tmp/scan_server.$$		# list of interfaces
tmp1=/tmp/scan_server.$$.1	# list of IP CIDR
tmp2=/tmp/scan_server.$$.2


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

get_ipv4_full() {
	local if_id="$1"
	local outfile="$2"
	: > "$outfile"

	# Helper: bereken netwerk via ipcalc
	calc_net() {
		local ip="$1"
		local cidr="$2"
		ipcalc "$ip/$cidr" | sed -n 's/\/.*//;s/Network. *//p'
	}

	# 1. Linux modern: ip -4 -o addr
	cmd_on "$if_id" "ip -4 -o addr" 2>/dev/null | \
	awk '{print $2, $4}' | while read -r iface ipcidr; do
		ip="${ipcidr%/*}"
		cidr="${ipcidr#*/}"
		net=$(calc_net "$ip" "$cidr")
		echo "$ip $cidr $net $iface"
	done > "$outfile"
	[[ -s "$outfile" ]] && return 0

	# 2. Linux generic: ip addr
	cmd_on "$if_id" "ip addr" 2>/dev/null | \
	awk '/inet / {print $NF, $2}' | while read -r iface ipcidr; do
		ip="${ipcidr%/*}"
		cidr="${ipcidr#*/}"
		net=$(calc_net "$ip" "$cidr")
		echo "$ip $cidr $net $iface"
	done > "$outfile"
	[[ -s "$outfile" ]] && return 0

	# 3. BSD/macOS/Linux-ifconfig
	cmd_on "$if_id" "ifconfig" 2>/dev/null | \
	awk '
		/^[a-zA-Z0-9]/ {iface=$1}
		/inet / {
			ip=$2
			for(i=1;i<=NF;i++){
				if($i=="netmask"){
					mask=$(i+1)
					# macOS/BSD hex → dec
					if(mask ~ /^0x/){
						m=mask
						gsub("0x","",m)
						split(m,a,"")
						bin=""
					 for(j=1;j<=length(m);j+=2){
							byte=substr(m,j,2)
							dec=strtonum("0x" byte)
							for(k=7;k>=0;k--) bin=bin""int(dec/2^k)%2
						}
						cidr=gsub(/1/,"1",bin)
					} else {
					 split(mask,oct,".")
					 cidr=0
						for(j in oct){
							n=oct[j]
						 while(n>0){ cidr+=n%2; n=int(n/2) }
						}
					}
					print ip, cidr, iface
				}
			}
		}
	' | while read -r ip cidr iface; do
		net=$(calc_net "$ip" "$cidr")
		echo "$ip $cidr $net $iface"
	done > "$outfile"
	[[ -s "$outfile" ]] && return 0

	# 4. Windows: ipconfig
	cmd_on "$if_id" "ipconfig" 2>/dev/null | \
	awk '
		/adapter/ {iface=$0; gsub(".*adapter ","",iface); gsub(":","",iface)}
		/IPv4 Address/ {ip=$NF}
		/Subnet Mask/ {
			split($NF,oct,".")
			cidr=0
			for(i in oct){
				n=oct[i]
				while(n>0){ cidr+=n%2; n=int(n/2) }
			}
			print ip, cidr, iface
		}
	' | while read -r ip cidr iface; do
		net=$(calc_net "$ip" "$cidr")
		echo "$ip $cidr $net $iface"
	done > "$outfile"
	[[ -s "$outfile" ]] && return 0

	# 5. Cisco: sh ip int (NIET br)
	cmd_on "$if_id" "sh ip int" 2>/dev/null | \
	awk '
		/Internet address/ {
			iface=$1
			sub("Internet address is ","",$0)
			split($4,parts,"/")
			ip=parts[1]
			cidr=parts[2]
			print ip, cidr, iface
		}
	' | while read -r ip cidr iface; do
		net=$(calc_net "$ip" "$cidr")
		echo "$ip $cidr $net $iface"
	done > "$outfile"
	[[ -s "$outfile" ]] && return 0

	return 1
}


list_interfaces | cut -d' ' -f1,2 > $tmp

cat $tmp | while read if_id if_ip ; do
	echo "if_id=$if_id if_ip=$if_ip"
	if_access=$(valfromid interfaces $if_id access)
	if_host=$(valfromid interfaces $if_id host)
	if [ "$if_host" != "" ] ; then
		srv_name=$(valfromid server $if_host name)
	else
		srv_name=$(host $if_ip | grep -v NXDOMAIN | head -1)
	fi
	 echo "	 srv_name=$srv_name "
	if [ "$if_access" != "" ] ; then
		echo "Scan server for $if_ip"
		get_ipv4_full "$if_id" $tmp1
		hostname=$(cmd_on $if_id hostname -s)
		if [ "$srvname" = "" ] ; then
			srvname="$hostname"
		fi
		sort -u  $tmp1 | sed "s/^/tmp1 for $if_ip: /"
		sort -u  $tmp1 | while read ip cidr  nwaddress interfacename; do
			if [ "$nwaddress" = "" ] ; then echo "================> ip=$ip cidr=$cidr" ; continue  ; fi
			sn_id=$(get_subnet $ip)
			netscope=''
			echo "   ip=$ip  cidr=$cidr  nwaddress=$nwaddress sn_id=$sn_id"
			declare -A interface_data
			declare -A subnet_data
			if [ "$sn_id" = "" ] ; then
				subnet_data[nwaddress]=$nwaddress
				subnet_data[name]=$nwaddress
				subnet_data[cidr]=$cidr
				subnet_data[source]="scan_server"
				set_subnet subnet_data
				sn_id=$db_retval
			else
				# is the subnet scope global ?
				netscope=$(valfromid subnet $sn_id scope)
				if [ "$netscope" != "global" ] || [ "$netscope" != "local" ] ; then
					sn_id=''
				fi
			fi
			
			if [ "$subnetid" != "" ] ; then
				interface_data[ip]="${ip// /}"
				interface_data[host]="${if_host// /}"
				interface_data[subnet]="$sn_id"
				interface_data[ip_scope]="$netscope"
				interface_data[source]="scan_server"
				other_int=$(idfrom_interfaces ip $ip)
				echo "->other_int=$other_int from idfrom_interfaces ip $ip"
				set_interface interface_data
			fi
			unset interface_data
			unset subnet_data
		done
	fi
done

rm -f $tmp
rm -f $tmp2
rm -f $tmp1
