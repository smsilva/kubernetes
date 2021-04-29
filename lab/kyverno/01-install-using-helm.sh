#!/bin/bash

# Add the Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/

# Scan your Helm repositories to fetch the latest available charts.
helm repo update

# Install the Kyverno Helm chart into a new namespace called "kyverno"
helm install kyverno \
  --namespace kyverno kyverno/kyverno \
  --create-namespace

for deploymentName in $(kubectl -n kyverno get deploy -o name); do
   echo "Waiting for: ${deploymentName}"

   kubectl \
     -n kyverno \
     wait \
     --for condition=available \
     --timeout=240s \
     ${deploymentName};
done
