#!/bin/bash
kubectl get nodes -o wide -L disktype

echo ""

kubectl get pdb

echo ""

kubectl get pods -o wide -l app=nginx
