#!/bin/bash

tmp=/tmp/scan_serverinfo.$$	# osdetect
tmp1=/tmp/scan_serverinfo.$$.1  # list_interfaces
tmp2=/tmp/scan_serverinfo.$$.2
tmp3=/tmp/scan_serverinfo.$$.2	# cpuinfo


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


list_interfaces | cut -d' ' -f1,2 > $tmp1

cat $tmp1 | while read if_id if_ip ; do
	srv_name=''
	if_access=$(valfromid interfaces $if_id access)
	if_host=$(valfromid interfaces $if_id host)
	if_ip=$(valfromid interfaces $if_id ip)
	if [ "$if_host" != "" ] ; then
		srv_name=$(valfromid server $if_host name)
	fi
	if [ "$srv_name" = "" ] ; then continue ; fi
	if [ "$if_access" != "" ] ; then
		echo "Scan server info  for $if_ip"
		ostype=''
		os=''
		cpu=''
		mem=''
		if [ "$ostype" = "" ] ; then
			cmd_on "$if_id" "show version"  > $tmp3 2>/dev/null
			sed 's/^/tmp3: /' $tmp3
			if grep -iq cisco $tmp3  ; then
				ostype='Cisco IOS'
				os=$(sed -n  's/.*IOS.*(\(.*\)), \(.*\),.*/\1 \2/p' $tmp3)
				cpu=$(sed -n 's/[Pp]rocessor.*//p' $tmp3)
				mem=$(sed -n 's/.* \([0-9][0-9]*\)K\/.*/\1/p' $tmp3)
				ifname=$(cmd_on "$if_id" "sh ip int br" | sed -n "s/  *$if_ip .*//p")
				setfromid interfaces "$if_id" name "$ifname"
			fi
		fi
		if [ "$ostype" = "" ] ; then
			out=$(cmd_on "$if_id" ver 2>/dev/null | grep -i windows 2>/dev/null)
			if [ "$out" != "" ] ; then
				ostype='Microsoft Windows'
				cpu=$(cmd_on "$if_id" "powershell -NoLogo -NoProfile -Command \"(Get-WmiObject Win32_Processor).Name\"" 2>/dev/null)
				mem_bytes=$(cmd_on "$if_id" "powershell -NoLogo -NoProfile -Command \"(Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory\"" 2>/dev/null)
				mem=$(( mem_bytes / 1024 ))
				os=$(cmd_on "$if_id" systeminfo | dos2unix | sed -n  's/.*Microsoft Windows/Microsoft Windows/p')
				ifname=$(cmd_on "$if_id" "netsh interface ipv4 show addresses" | awk -v ip="$if_ip" '
					/nterface / {
						match($0, /nterface /);
						name = substr($0, RSTART + RLENGTH);
						gsub(/["\r]/, "", name);
						gsub(/^[ \t]+|[ \t]+$/, "", name);
					}
					$0 ~ ip {
						print name;
						exit;
					}
				')
				setfromid interfaces "$if_id" name "$ifname"
			fi
		fi
		if [ "$ostype" = "" ] ; then
			out=$(cmd_on "$if_id" uname -s)
			if echo "$out" | grep -q Linux ; then
				ostype=Linux
				os=$(cmd_on "$if_id" '[ -f /etc/os-release ] && cat /etc/os-release '| sed -n 's/"//g; s/PRETTY_NAME=//p')
				if [ "$os" = "" ] ; then
					os=$(cmd_on "$if_id" '[ -f /proc/version ] && cat  /proc/version ' | sed -n 's/ (.*//p')
				fi
				arch=$(cmd_on "$if_id" "uname -m")
				cmd_on "$if_id" "[ -f /proc/cpuinfo ] && cat /proc/cpuinfo" > $tmp3
				if [ "$cpu" = "" ] ; then
					cpu=$(sed -n 's/model name.*: *//p' $tmp3 | head -1)
				fi
				if [ "$cpu" = "" ] ; then
					cpu=$(sed -n 's/cpu model.*: *//p' $tmp3 | head -1)
				fi
				if [ "$cpu" = "" ] ; then
					cpu=$(sed -n 's/Processor.*: *//p' $tmp3 | head -1)
				fi
				if [ "$cpu" = "" ] ; then
					cpu=$(sed -n 's/^cpu.*: *//p' $tmp3 | head -1)
				fi
				if [ "$cpu" = "" ] ; then
					cpu=$(cmd_on "$if_id" lscpu | sed -n  's/Model name:[[:space:]]*//p')

				fi
				mem=$(cmd_on "$if_id" "grep MemTotal /proc/meminfo" | awk '{print $2}')
				ifname=$(cmd_on "$if_id" ifconfig | awk -v ip="$if_ip" '
					/flags=/{sub(/:.*/, "", $0); ifname = $0; }
					$0 ~ ip {
						print ifname;
						exit;
					}
				')
				setfromid interfaces "$if_id" name "$ifname"
					
			fi
		fi
		if [ "$ostype" = "" ] ; then
			out=$(cmd_on "$if_id" uname -s 2>/dev/null)
			if echo "$out" | grep -q BSD ; then
				ostype="BSD"
				os=$(cmd_on "$if_id" "uname -sr" 2>/dev/null)
				cpu=$(cmd_on "$if_id" "sysctl -n hw.model" 2>/dev/null)
				mem=$(cmd_on "$if_id" "sysctl -n hw.physmem64" 2>/dev/null)
				if [ -z "$mem" ] ; then
					mem=$(cmd_on "$if_id" "sysctl -n hw.physmem" 2>/dev/null)
				fi
				if [ -n "$mem" ] ; then
					mem=$(( mem / 1024 ))
				fi
			fi
		fi

		echo "---------------------------------"
		echo "Name:      $srv_name"
		echo "OStype:    $ostype"
		echo "OS:        $os"
		echo "CPU:       $cpu"
		echo "Memory:    $mem"
		echo "Interface: $ifname"
		if [ "$ostype" != "" ] ; then
			declare -A server_data
			server_data[name]="$srv_name"
			server_data[ostype]="$ostype"
			if [ "$os" != "" ] ; then server_data[os]="$os"; fi
			if [ "$cpu" != "" ] ; then server_data[processor]="$cpu"; fi
			if [ "$mem" != "" ] ; then server_data[memory]="$mem"; fi
			set_server server_data
			unset server_data
		fi
	fi
done

rm -f $tmp
rm -f $tmp2
rm -f $tmp1
rm -f $tmp3
