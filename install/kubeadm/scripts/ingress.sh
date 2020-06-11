#!/bin/bash

# Ingress HAProxy Controller
# https://kubernetes.io/docs/concepts/services-networking/ingress/
# https://github.com/jcmoraisjr/haproxy-ingress
# https://haproxy-ingress.github.io/docs/getting-started/
# https://haproxy-ingress.github.io/docs/configuration/keys/
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest

kubectl create -f https://haproxy-ingress.github.io/resources/haproxy-ingress.yaml

watch -n 3 'kubectl get deploy,cm,ds,rs,pods,services -o wide -n ingress-controller'

for NODE in $(kubectl get nodes -l node-role.kubernetes.io/master="" --no-headers -o custom-columns="NAME:.metadata.name"); do
  kubectl label node ${NODE} role=ingress-controller
done

ls ../objects/ingress/*.yaml | while read FILE; do
  vg scp "${FILE}" master-1:/home/vagrant/example/ingress/
done

curl -Is foo.apps.example.com/v1
curl -Is nginx.apps.example.com/v2
