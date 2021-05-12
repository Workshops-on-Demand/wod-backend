#!/bin/bash

OUT=/tmp/ldap-modif
min=1201
max=1274

i=$min

echo > $OUT
while [ $i -le $max ]; do
	j=$(($i+13000))
	cat >> $OUT << EOF
dn: uid=sec-student$i,ou=People,dc=hpedevlab,dc=net
changetype: modify
replace: gidNumber
gidNumber: $j

EOF
	i=$((i+1))
done
