#!/bin/bash
source ${HOME}/.bashrc

ISTIO_VERSION=$(grep -Eo "istio.*" <<< ${ISTIO_BASE_DIR} | sed 's/istio-//')

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
    echo "istiod doesn't exists"
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
  name: istio-1-7-1
spec:
  profile: default
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        replicaCount: 1
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

# Cert Manager Integartion
#   https://istio.io/latest/docs/ops/integrations/certmanager/

# Uninstall
kubectl delete ns istio-operator --grace-period=0 --force

istioctl manifest generate | kubectl delete -f -

kubectl delete ns istio-system --grace-period=0 --force

# Example
cd "kubernetes/lab/istio"

eval $(minikube -p minikube docker-env)

docker build -t demo-health:1.0 demo/docker/

kubectl create namespace dev

kubectl label namespace dev istio-injection=enabled

kubectl get namespaces -L istio-injection

# Generate a Public IP - as we use minikube, use minikube tunnel on another terminal
minikube tunnel

watch 'kubectl -n dev get deploy,pods,svc,gw,vs'

ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP=$(kubectl -n istio-system get service -l istio=ingressgateway -o jsonpath='{.items[].status.loadBalancer.ingress[0].ip}')

echo ${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}

sudo sed -i '/services.example.com/d' /etc/hosts

sudo sed -i "1i${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP} services.example.com" /etc/hosts

kubectl -n dev apply -f demo/

curl -is services.example.com
curl -is services.example.com/health
curl -is services.example.com/info

# Visualizing Metrics with Grafana
# https://istio.io/latest/docs/tasks/observability/metrics/using-istio-dashboard/

# Grafana
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/addons/grafana.yaml

# Prometheus
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.7/samples/addons/prometheus.yaml

# Access Dashboard
istioctl dashboard grafana
