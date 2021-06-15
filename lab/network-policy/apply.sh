#!/bin/bash
helm template chart/ | kubectl apply -f -

sleep 5

while read line; do
  NAMESPACE=$(awk '{ print $1 }' <<< "$line")
  POD_NAME=$(awk '{ print $2 }' <<< "$line")

  echo "waiting for: ${NAMESPACE}/${POD_NAME}..."

  kubectl \
    --namespace ${NAMESPACE} \
    wait \
    --for condition=Ready \
    --timeout 120s \
    pod ${POD_NAME}

  echo ""
done <<< $(kubectl get po -A | grep -E "^olinda|^recife")
