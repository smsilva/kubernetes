#!/bin/bash

# https://developer.godaddy.com/doc/endpoint/domains

CNAME_RECORD_ID="apps"
CNAME_RECORD_VALUE="silvios-dev.eastus2.cloudapp.azure.com"
CNAME_UPDATE_PAYLOAD_FILE="cname-${CNAME_RECORD_ID?}.${GODADDY_DOMAIN?}.json"

# Retrieve CNAME "apps" record value
curl \
  --silent \
  --request GET \
  --header "Authorization: sso-key ${GODADDY_API_KEY_ID?}:${GODADDY_API_KEY_SECRET?}" \
  --header "accept: application/json" \
  https://api.godaddy.com/v1/domains/${GODADDY_DOMAIN?}/records/CNAME/${CNAME_RECORD_ID?} | jq

dig @8.8.8.8 ${CNAME_RECORD_ID?}.${GODADDY_DOMAIN?} | grep -E "^${CNAME_RECORD_ID?}.${GODADDY_DOMAIN?}"

cat <<EOF > ${CNAME_UPDATE_PAYLOAD_FILE?}
[
  {
    "type": "CNAME",
    "name": "${CNAME_RECORD_ID?}",
    "data": "${CNAME_RECORD_VALUE?}",
    "ttl": 3600
  }
]
EOF

# Update CNAME "apps" record value
curl \
  --request PUT \
  --header "accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: sso-key ${GODADDY_API_KEY_ID?}:${GODADDY_API_KEY_SECRET?}" \
  --data @${CNAME_UPDATE_PAYLOAD_FILE?} \
  https://api.godaddy.com/v1/domains/${GODADDY_DOMAIN?}/records/CNAME/${CNAME_RECORD_ID?}
