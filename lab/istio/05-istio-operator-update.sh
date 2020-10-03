#!/bin/bash
watch 'kubectl -n istio-system get iop,deploy,pods,svc -L istio.io/rev'

# https://istio.io/latest/docs/setup/upgrade/
helm template "${ISTIO_BASE_DIR}/manifests/charts/istio-operator/" \
  --set hub="docker.io/istio" \
  --set tag="${ISTIO_VERSION}" \
  --set revision="1-7-2" \
  --set operatorNamespace="istio-operator" \
  --set watchedNamespaces="istio-system" | kubectl apply -f -

kubectl label namespace dev istio-injection- istio.io/rev=1-7-2 --overwrite

kubectl -n dev rollout restart deployment demo
kubectl -n dev rollout restart deployment ntest

istioctl operator remove --revision default
