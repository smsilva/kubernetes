#!/bin/bash

# k3d Install
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v4.4.4 bash

# Install keptn cli
curl -sL https://get.keptn.sh | bash

# Create k3d cluster
k3d cluster create mykeptn \
  -p "8082:80@agent[0]" \
  --k3s-server-arg '--no-deploy=traefik' \
  --agents 7

# Install keptn into k3d cluster
# https://github.com/keptn/keptn#developing-keptn
keptn install \
  --use-case=continuous-delivery \
  --yes

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
keptn create project podtatohead --shipyard=podtato-head/delivery/keptn/shipyard.yaml

# Onboard a Keptn service
keptn onboard service helloservice --project=podtatohead --chart=./podtato-head/delivery/keptn/helm-charts/helloserver

# Trigger the delivery sequence with Keptn
keptn trigger delivery \
  --project=podtatohead \
  --service=helloservice \
  --image=ghcr.io/podtato-head/podtatoserver \
  --tag=v0.1.0

# Troubleshooting
https://keptn.sh/docs/0.9.x/troubleshooting/

# Delete Cluster
k3d cluster delete mykeptn
