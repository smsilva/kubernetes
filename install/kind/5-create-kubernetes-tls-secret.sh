#!/bin/bash
kubectl create secret tls \
  secret-tls-app-example-com \
  --key cert.key.pem \
  --cert cert.pem
