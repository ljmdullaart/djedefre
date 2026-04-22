#!/bin/bash
#aesopos             12    0     0    
echo "                 ANSIBLE"
echo "------------------------------------------"
echo "HOST                OK unreach change fail"

ssh fontaine 'cat /tmp/last.ansible.log' | 
sed -n 's/      //;s/\(.*\) : ok=\(.*\)changed=\(.*\)unreachable=\(.*\)failed=\(.*\) *skip.*/\1\2 \4 \3 \5/p'

#aesopos                    : ok=12   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0 
