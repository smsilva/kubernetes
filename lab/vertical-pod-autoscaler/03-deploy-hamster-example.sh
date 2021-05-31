#!/bin/bash

kubectl create --filename ${KUBERNETES_AUTOSCALER_LOCAL_GIT_REPOSITORY?}/vertical-pod-autoscaler/examples/hamster.yaml

kubectl get deploy hamster \
  --output jsonpath='{.spec.template.spec.containers[*].resources}' | jq .

kubectl wait pod \
  --selector app=hamster \
  --for condition=Ready \
  --timeout 3600s

kubectl get pods \
  --selector app=hamster \
  --output jsonpath='{.items[*].spec.containers[?(@.name == "hamster")].resources}' | jq .
