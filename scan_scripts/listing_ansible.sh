#!/bin/bash
#aesopos             12    0     0    

oklines=0
unreachablelines=0
changedlines=0
failedlines=0


if [ "$1" = "-s" ] ; then
	while read line ; do
		if [[ $line =~ ok=([0-9]+) ]]; then
			count="${BASH_REMATCH[1]}"
			if [ "$count" -gt 0 ]; then
				oklines=$((oklines+1))
			fi
		fi
		if [[ $line =~ changed=([0-9]+) ]]; then
			count="${BASH_REMATCH[1]}"
			if [ "$count" -gt 0 ]; then
				changedlines=$((changedlines+1))
			fi
		fi
		if [[ $line =~ unreachable=([0-9]+) ]]; then
			count="${BASH_REMATCH[1]}"
			if [ "$count" -gt 0 ]; then
				unreachablelines=$((unreachablelines+1))
			fi
		fi
		if [[ $line =~ failed=([0-9]+) ]]; then
			count="${BASH_REMATCH[1]}"
			if [ "$count" -gt 0 ]; then
				failedlines=$((failedlines+1))
			fi
		fi
	done < <( ssh fontaine 'cat /tmp/last.ansible.log' | grep 'ok=.*changed.*unreachable.*failed.*skipped.*rescued.*ignored')
	echo "                 ANSIBLE"
	ssh fontaine 'head -1 /tmp/last.ansible.log' | sed 's/starting *//'
	echo "------------------------------------------"
	echo "OK:          $oklines hosts"
	echo "Changed:     $changedlines hosts"
	echo "Unreachable: $unreachablelines hosts"
	echo "Failed:      $failedlines hosts"
	
elif [ "$1" = "-htm" ] ; then
	echo "<h2>Ansible</h2>"
	ssh fontaine 'head -1 /tmp/last.ansible.log' | sed 's/starting *//'
	echo '<br>'
	echo "<table>"

	echo "<tr><td><b>host</b></td><td><b> ok</b></td><td><b>changed</b></td><td><b>unreachable</b></td><td><b>failed</b></td></tr>"
	ssh fontaine 'cat /tmp/last.ansible.log' | 
	sed -n 's/      //;s/\(.*\) : ok=\(.*\)changed=\(.*\)unreachable=\(.*\)failed=\(.*\) *skip.*/\1\2 \3 \4 \5/p' |
	while read host  ok changed unreachable failed rest ; do
		echo "<tr><td>$host</td><td> $ok</td><td>$changed</td><td>$unreachable</td><td>$failed</td></tr>"
	done

	echo "</table>"
	echo "<br>"
	ssh fontaine cat /tmp/last.ansible.log | grep Finished		

else
	echo "                 ANSIBLE"
	ssh fontaine 'head -1 /tmp/last.ansible.log' | sed 's/starting *//'
	echo "------------------------------------------"
	echo "HOST                OK unreach change fail"
	
	ssh fontaine 'cat /tmp/last.ansible.log' | 
	sed -n 's/      //;s/\(.*\) : ok=\(.*\)changed=\(.*\)unreachable=\(.*\)failed=\(.*\) *skip.*/\1\2 \4 \3 \5/p'
fi

#aesopos                    : ok=12   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0 
