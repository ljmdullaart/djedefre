#!/bin/bash

organization=Default
db=database/djedefre.db

tmp=itop/itopimport.$$
hvisors=itop/hvisors.$$

mkdir -p itop
i=1
echo $i organization
echo 'Name*,Code' > itop/$i-Organization.csv
echo "$organization,none" >> itop/$i-Organization.csv

i=$((i+1))
echo $i OS_Family
echo 'Name*' > itop/$i-OS_Family.csv
sqlite3 $db  'SELECT DISTINCT ostype FROM server' | grep -v '^$' >> "itop/$i-OS_Family.csv"

i=$((i+1))
echo $i OS_Version
echo "Name*,OS family->Name" > "itop/$i-OS_Version.csv"
sqlite3 $db --separator ,  "SELECT DISTINCT os,ostype
                            FROM server" |
	grep -v '^,*$' >> "itop/$i-OS_Version.csv"

i=$((i+1))
echo $i Server
echo "Name*,OS family->Name,OS version->Name,CPU,RAM,Organization->Name" > "itop/$i-Server.csv"
sqlite3 $db --separator ,  "SELECT name,ostype,os,processor,memory,'$organization'
                            FROM server
                            WHERE (( options NOT LIKE '%vboxhost%' ) OR (options IS NULL) )
" | grep -v '^,*$' | grep -v "^[0-9]" >> "itop/$i-Server.csv"

i=$((i+1))
echo $i Hypervisors
echo "Name*,Organization->Name,Status,Server->Name"  > itop/$i-Hypervisors.csv
sqlite3 $db "SELECT DISTINCT options
             FROM server
             WHERE options LIKE '%vboxhost:%'" |
	sed 's/.*vboxhost://;s/,.*//'  > $tmp
sort -u $tmp | while read host ; do
	sqlite3 $db --separator ,  "SELECT name,'$organization','production',name
                                    FROM server
                                    WHERE id=$host" >> itop/$i-Hypervisors.csv
done

i=$((i+1))
echo $i Virtual_Machine
sqlite3 $db --separator ','  "SELECT name,ostype,os,processor,memory,options
                              FROM server
                              WHERE  options LIKE '%vboxhost%' " > $tmp
echo "Name*,Organization->Name,Status,Virtual host->Name,OS family->Name,OS version->Name,CPU,RAM" > itop/$i-Virtual_Machine.csv
sed 's/ /%/g;s/,/ /g'  $tmp | while read name ostype os processor memory option ; do
	vboxhost=${option#*vboxhost:}
	vboxhost=${vboxhost%%,*}
	vboxhostname=$(echo "SELECT name FROM server WHERE id=$vboxhost" | sqlite3 $db)
	memory=${memory//%/}
	os=${os//%/ }
	processor=${processor//%/ }
	echo "$name,$organization,production,$vboxhostname,$ostype,$os,$processor,$memory" >> itop/$i-Virtual_Machine.csv

done

i=$((i+1))
echo $i NAS

rm -f $tmp $hvisors	
