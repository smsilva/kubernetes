#!/usr/bin/env bash

export StackInstanceTestRun_EXECUTION_ID=$(uuidgen)

envsubst < events_template.json > data.json

curl \
  --silent \
  --output /dev/null \
  --write-out "%{http_code}" \
  --header "Content-Type: application/json" \
  --header "Api-Key: ${NEW_RELIC_LICENSE_KEY?}" \
  --request POST "https://insights-collector.newrelic.com/v1/accounts/${NEW_RELIC_ACCOUNT_ID?}/events" \
  --data @data.json
