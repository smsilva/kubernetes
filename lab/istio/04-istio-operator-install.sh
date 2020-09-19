#!/bin/bash
source ${HOME}/.bashrc && \
echo "ISTIO_VERSION..: ${ISTIO_VERSION}" && \
echo "ISTIO_BASE_DIR.: ${ISTIO_BASE_DIR}"

# Check for Istio's Custom Resource Definitions (should not yet installed)
kubectl api-resources | grep -E "NAME|istio"

# Install Istio Operator Components using Helm
#   namespace..........: istio-operator
#   serviceaccount.....: istio-operator
#   clusterrole........: istio-operator
#   clusterrolebinding.: istio-operator
#   service............: istio-operator
#   deployment.apps....: istio-operator
helm template "${ISTIO_BASE_DIR}/manifests/charts/istio-operator/" \
  --set hub="docker.io/istio" \
  --set tag="${ISTIO_VERSION}" \
  --set operatorNamespace="istio-operator" \
  --set watchedNamespaces="istio-system" | kubectl apply -f -

# At this time, there are no Istio Custom Resource Definitions (CRDs)
#   istio-operator controller could not find the IstioOperator, and because of that, any objects of IstioOperator type could be create
kubectl -n istio-operator wait pod -l name=istio-operator --for=condition=Ready && \
kubectl -n istio-operator logs -f -l name=istio-operator

# Create Istio CRDs
kubectl apply -f "${ISTIO_BASE_DIR}/manifests/charts/istio-operator/crds/"

# Monitor Istio Operator Execution
kubectl -n istio-operator wait pod -l name=istio-operator --for=condition=Ready && \
kubectl -n istio-operator logs -f -l name=istio-operator

# Install Istio Control Plane creating one IstioOperator with demo Profile

# Create istio-system Namespace
kubectl create namespace istio-system

# Explicitly label the istio-system namespace to not receive sidecar injection
kubectl label namespace istio-system istio-injection=disabled

# Watch istio-system for Control Plane Components (keep it on a different terminal window or tmux pane)
watch 'kubectl -n istio-system get iop,deploy,pods,svc'

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
done;
kubectl -n istio-system wait pod -l app=istiod --for=condition=Ready && \
kubectl -n istio-system logs -f -l app=istiod

# Create IstioOperator
#   https://istio.io/latest/docs/reference/config/istio.operator.v1alpha1/#IstioComponentSetSpec
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: istio-${ISTIO_VERSION}
spec:
  profile: default
EOF

# Update
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: istio-control-plane
spec:
  profile: default
  components:
    pilot:
      k8s:
        resources:
          requests:
            memory: 3072Mi
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        replicaCount: 3
EOF

# Add Ons
cd ${ISTIO_BASE_DIR}
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/kiali.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/prometheus.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/grafana.yaml"

# Access Dashboards
istioctl dashboard --help | grep "Available Commands:" -B 1 -A 8

# Cert Manager Integartion
#   https://istio.io/latest/docs/ops/integrations/certmanager/

# Uninstall
kubectl delete ns istio-operator --grace-period=0 --force

istioctl manifest generate | kubectl delete -f -

kubectl delete ns istio-system --grace-period=0 --force
