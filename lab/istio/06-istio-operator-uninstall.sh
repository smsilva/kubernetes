#!/bin/bash
# Uninstall
kubectl delete ns istio-operator --grace-period=0 --force

istioctl manifest generate | kubectl delete -f -

kubectl delete ns istio-system --grace-period=0 --force
