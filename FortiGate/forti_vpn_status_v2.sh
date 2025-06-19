#!/bin/bash

while getopts i:c:n:a:A:l:u:v: OPTNAME;
do
        case "$OPTNAME" in
                i) ip="$OPTARG";;
                c) community="$OPTARG";;
                n) ifname="$OPTARG";;
                a) protocol="$OPTARG";;
                A) passphrase="$OPTARG";;
                l) level="$OPTARG";;
                u) user="$OPTARG";;
                v) ver="$OPTARG";;
        esac
done

if [[ "$ver" == "2c" ]]; then
        snmpconn="-v $ver -c $community $ip";
elif [[ "$ver" == "3" ]]; then
        snmpconn="-v $ver -a $protocol -A $passphrase -l $level -u $user $ip";
else
        result=4
        exit
fi

#AdminStatus
snmp_result_if_id_nyers=$(snmpwalk $snmpconn 1.3.6.1.2.1.31.1.1.1 | grep $ifname$)
while [[ -z "$snmp_result_if_id_nyers" && -n "$ifname" ]]; do
    ifname="${ifname%?}"  # Remove the last character
    snmp_result_if_id_nyers=$(snmpwalk $snmpconn 1.3.6.1.2.1.31.1.1.1 | grep "$ifname")
done
snmp_result_if_id=$(echo "$snmp_result_if_id_nyers" | awk -F '[ .]' '{print $(NF-3)}')
snmp_result_if_adminstatus_nyers=$(snmpwalk $snmpconn 1.3.6.1.2.1.2.2.1.7.$snmp_result_if_id)
snmp_result_if_adminstatus=$(echo "$snmp_result_if_adminstatus_nyers" | awk -F '[()]' '{print $2}')

if [[ "$snmp_result_if_adminstatus" != "1" ]]; then
        result=3
        exit
fi

#Operating Status
snmp_result_vpn_id_nyers=$(snmpwalk $snmpconn 1.3.6.1.4.1.12356.101.12.2.2.1.2 | grep \"$ifname\")
while read -r line; do
    interface_id=$(echo "$snmp_result_vpn_id_nyers" | awk -F'.' '{print $(NF-1)"."$NF}' | awk -F' ' '{print $1}')
    interface_ids+=("$interface_id")
done <<< "$snmp_results"

result=1

for id in "${interface_ids[@]}"; do

    snmp_value=$(snmpwalk $snmpconn 1.3.6.1.4.1.12356.101.12.2.2.1.20.$id | awk -F': ' '{print $2}')

    if [ "$snmp_value" -eq 2 ]; then
        result=2
        break
    fi
done

echo $result
