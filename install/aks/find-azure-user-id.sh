#!/bin/bash
AZ_USER_EMAIL=$1

FILTER_EXPRESSION=$(printf "mail eq '%s'" "${AZ_USER_EMAIL?}")

AZ_USER_ID=$(az ad user list \
  --filter "${FILTER_EXPRESSION?}" \
  --output tsv \
  --query='[*].objectId')

if [ -z "${AZ_USER_ID}" ]; then
  QUERY_EXPRESSION=$(printf "[?contains(otherMails, '%s')].objectId" "${AZ_USER_EMAIL?}")
  AZ_USER_ID=$(az ad user list \
    --query "${QUERY_EXPRESSION?}" \
    --output tsv)
fi

echo ${AZ_USER_ID?}
