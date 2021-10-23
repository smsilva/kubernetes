#!/bin/bash
CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME="$(kubectl get pods -n crossplane-system -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | grep crossplane-provider-terraform)" && \
kubectl -n crossplane-system wait pod "${CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME?}" \
  --for=condition=Ready \
  --timeout=120s && \
kubectl -n crossplane-system logs -f "${CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME?}"
