#!/bin/bash
kubectl apply -f ingress/httpbin/

kubectl wait --for=condition=Ready deploy httpbin
