#!/bin/bash

while getopts i:s:t:u:c: OPTNAME;
do
        case "$OPTNAME" in
                i) client_id="$OPTARG";;
                s) client_secret="$OPTARG";;
		t) tenant="$OPTARG";;
		u) user="$OPTARG";;
		c) check="$OPTARG";;
        esac
done

access_token=$(curl -s -X POST "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$client_id" \
  -d "client_secret=$client_secret" \
  -d "scope=https://graph.microsoft.com/.default" \
  -d "grant_type=client_credentials" | jq -r .access_token)

response=$(curl -sS -X GET "https://graph.microsoft.com/v1.0/users/$user/licenseDetails" \
	  -H "Authorization: Bearer $access_token" \
	  -H "Accept: application/json")

IFS=',' read -ra SKUS <<< "$check"
for sku in "${SKUS[@]}"; do
    if echo "$response" | jq -e --arg id "$sku" '.value[] | select(.skuId == $id)' > /dev/null; then
        echo "SKU ID $sku exists"
    else
        echo "SKU ID $sku does NOT exist"
    fi
done
