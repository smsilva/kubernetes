#!/bin/bash
for n in {001..100}; do
  STATUS=$(kubectl -n istio-system get iop istio-operator -o jsonpath='{.status.status}')
  echo "[${n}] Istio Operator Status: ${STATUS}"
  if [ "${STATUS}" == "HEALTHY" ]; then
    break
  else
    sleep 10
  fi
done
