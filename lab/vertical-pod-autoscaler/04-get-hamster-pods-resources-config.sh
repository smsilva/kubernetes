#!/bin/bash

kubectl get pods \
  --selector app=hamster \
  --output jsonpath='{.items[*].spec.containers[?(@.name == "hamster")].resources}' | jq .
