#!/bin/bash

# k3d Install
# https://k3d.io/v4.4.8/
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v4.4.4 bash

k3d cluster create mykeptn \
  -p "8082:80@agent[0]" \
  --k3s-server-arg '--no-deploy=traefik' \
  --agents 10

# Install keptn cli
curl -sL https://get.keptn.sh | bash

# Install keptn into k3d cluster
keptn install

# https://github.com/keptn/keptn#developing-keptn
keptn install --use-case=continuous-delivery

# Port Forward keptn bridge (UI)
kubectl -n keptn port-forward service/api-gateway-nginx 8080:80

keptn auth \
  --endpoint=http://localhost:8080/api \
  --api-token=$(kubectl get secret keptn-api-token \
      -n keptn \
      -o jsonpath={.data.keptn-api-token} | base64 --decode)

# Install and configure Istio for Ingress + continuous delivery use-case
curl -SL https://raw.githubusercontent.com/keptn/keptn.github.io/master/content/docs/quickstart/exposeKeptnConfigureIstio.sh | bash

# (Optional but recommended) Create a demo project with multi-stage pipeline + SLO-based quality gates
curl -SL https://raw.githubusercontent.com/keptn/keptn.github.io/master/content/docs/quickstart/get-demo.sh | bash

# Create a Project
keptn create project podtatohead --shipyard=./shipyard.yaml

# Onboard a Keptn service
keptn onboard service helloservice --project=podtatohead --chart=./helm-charts/helloserver
keptn onboard service helloservice --project=podtatohead --chart=./podtato-head/delivery/keptn/helm-charts/helloserver

# Trigger the delivery sequence with Keptn
keptn trigger delivery \
  --project=podtatohead \
  --service=helloservice \
  --image=ghcr.io/podtato-head/podtatoserver \
  --tag=v0.1.0

# Stop Cluster
k3d cluster stop mykeptn

# Delete Cluster
k3d cluster delete mykeptn

# Troubleshooting
https://keptn.sh/docs/0.9.x/troubleshooting/

# Get Events
kubectl -n sockshop-dev get events  --sort-by='.metadata.creationTimestamp'
