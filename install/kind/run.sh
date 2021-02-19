#!/bin/bash
./1-create-cluster.sh
./2-deploy-httpbin.sh
./3-install-nginx-ingress-controller.sh
./4-generate-self-signed-certificate.sh
./5-create-kubernetes-tls-secret.sh
./6-create-ingress-object.sh

if ! grep --quiet app.example.com /etc/hosts; then
  echo "127.0.0.1 app.example.com" | sudo tee -a /etc/hosts
fi

echo ""
echo "How to test it:"
echo ""
echo "  curl -ks https://app.example.com/get"
echo ""
