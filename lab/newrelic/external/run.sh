#!/usr/bin/env bash

export StackInstanceTestRun_EXECUTION_ID=$(uuidgen)

envsubst < events_template.json > data.json

curl \
  --silent \
  --output /dev/null \
  --write-out "%{http_code}" \
  --request POST "https://insights-collector.newrelic.com/v1/accounts/${NEW_RELIC_ACCOUNT_ID?}/events" \
  --header 'Content-Type: application/json' \
  --header "x-insert-key: ${NEW_RELIC_API_KEY?}" \
  --data @data.json
