#!/bin/bash

while getopts i:s:t:g:d: OPTNAME;
do
        case "$OPTNAME" in
                i) client_id="$OPTARG";;
                s) client_secret="$OPTARG";;
                t) tenant="$OPTARG";;
                g) group="$OPTARG";;
                d) dataset="$OPTARG";;
        esac
done

access_token=$(curl -s -X POST "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$client_id" \
  -d "client_secret=$client_secret" \
  -d "scope=https://analysis.windows.net/powerbi/api/.default" \
  -d "grant_type=client_credentials" | jq -r .access_token)

response=$(curl -sS -X GET "https://api.powerbi.com/v1.0/myorg/groups/$group/datasets/$dataset/refreshes" \
	  -H "Authorization: Bearer $access_token" \
	  -H "Accept: application/json" |
	jq '.value | sort_by(.endTime) | last')

echo "$response" | jq
