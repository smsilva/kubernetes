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

# Add Ons
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/prometheus.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/grafana.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/kiali.yaml"

# Watch istio-system for Control Plane Components (keep it on a different terminal window or tmux pane)
watch 'kubectl -n istio-system get iop,deploy,pods,svc'
