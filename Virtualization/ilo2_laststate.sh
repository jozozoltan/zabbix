#!/bin/bash

while getopts a:c: OPTNAME;
do
	case "$OPTNAME" in
		a) ip="$OPTARG";;
		c) community="$OPTARG";;
	esac
done

snmp_result=$(snmpwalk -v 2c -c $community $ip 1.3.6.1.4.1.232.9.2.3.2.1.4 | grep power | tail -n 1)

snmp_result=$(echo "$snmp_result" | tr -d '"')

if [[ "$snmp_result" == *"Restored power state to standby"* ]]; then
    result="Standby"
else
    result="Not Standby"
fi
echo $result
