#!/bin/bash
source ${HOME}/.bashrc && \
echo "ISTIO_VERSION..: ${ISTIO_VERSION}" && \
echo "ISTIO_BASE_DIR.: ${ISTIO_BASE_DIR}"

# Create Istio CRDs
kubectl apply -f "${ISTIO_BASE_DIR}/manifests/charts/istio-operator/crds/"

# Install Istio Operator Components using Helm
helm template "${ISTIO_BASE_DIR}/manifests/charts/istio-operator/" \
  --set hub="docker.io/istio" \
  --set tag="${ISTIO_VERSION}" \
  --set operatorNamespace="istio-operator" \
  --set watchedNamespaces="istio-system" | kubectl apply -f -

# Create istio-system Namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: disabled
  name: istio-system
spec:
  finalizers:
  - kubernetes
EOF

# Create IstioOperator Resource
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-operator
  namespace: istio-system
spec:
  profile: default
  values:
    global:
      proxy:
        autoInject: enabled
EOF

# Monitor Istio Operator Controller Execution
kubectl -n istio-operator wait pod -l name=istio-operator --for=condition=Ready && \
kubectl -n istio-operator logs -f -l name=istio-operator

# Monitor istio-operator namespace
watch 'kubectl -n istio-operator get deploy,pods,svc -L istio.io/rev'

# Watch istio-system for Control Plane Components (keep it on a different terminal window or tmux pane)
watch 'kubectl -n istio-system get iop,deploy,pods,svc -L istio.io/rev'

# Follow istiod logs (keep it on a different terminal window or tmux pane)
while true; do
  PODS=$(kubectl -n istio-system get pods -l app=istiod --ignore-not-found)
  if [ ${#PODS} -eq 0 ]; then
    echo "istiod pod doesn't exists on istio-system"
    sleep 2
  else
    echo "istiod created"
    break
  fi
done && \
kubectl -n istio-system wait pod -l app=istiod --for=condition=Ready && \
kubectl -n istio-system logs -f -l app=istiod

# Add Ons
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/prometheus.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/grafana.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/kiali.yaml"

# Access Dashboards
istioctl dashboard --help | grep "Available Commands:" -B 1 -A 8

# Cert Manager Integartion
#   https://istio.io/latest/docs/ops/integrations/certmanager/

# Uninstall
kubectl delete ns istio-operator --grace-period=0 --force

istioctl manifest generate | kubectl delete -f -

kubectl delete ns istio-system --grace-period=0 --force

# Update
#   https://istio.io/latest/docs/setup/upgrade/
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
