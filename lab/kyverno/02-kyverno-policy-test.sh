#!/bin/bash

kubectl apply -f kyverno-cluster-policy.yaml

kubectl create deployment nginx --image=nginx
