#!/bin/bash

# Check if Minikube is Installed
if ! which minikube > /dev/null; then
  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube && \
  sudo mkdir -p /usr/local/bin/ && \
  sudo mv minikube /usr/local/bin/
else
  MINIKUBE_INSTALLED_VERSION=$(minikube version --short | awk '{ print $3 }')
  echo "minikube ${MINIKUBE_INSTALLED_VERSION} version currently installed"
fi

# Retrieve lastest Kubernetes Version
KUBERNETES_BASE_VERSION=$(apt-cache madison kubeadm | head -1 | awk -F '|' '{ print $2 }' | tr -d ' ')
KUBERNETES_VERSION="${KUBERNETES_BASE_VERSION%-*}"

# Check if there isn't a minikube context created
if ! kubectl config get-contexts minikube > /dev/null; then
  # Start Minikube using Docker Driver
  export MINIKUBE_IN_STYLE=false && \
  minikube start \
    --kubernetes-version "v${KUBERNETES_VERSION}" \
    --driver=docker \
    --network-plugin=cni

  # Configure minikube context as default context  
  kubectl config use-context minikube
  
  # Configure Weave CNI Plugin
  kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
  
  # Wait for Deployments in kube-system become ready
  for deploymentName in $(kubectl -n kube-system get deploy -o name); do
     echo "Waiting for: ${deploymentName}"
  
     kubectl \
       -n kube-system \
       wait \
       --for condition=available \
       --timeout=90s \
       ${deploymentName};
  done
fi

# Retrieve the latest Istio Version
ISTIO_VERSION=$(curl -sL https://github.com/istio/istio/releases | grep -o 'releases/[0-9]*.[0-9]*.[0-9]*/' | sort --version-sort | tail -1 | awk -F'/' '{ print $2}')

ISTIO_BASE_DIR="istio-${ISTIO_VERSION}"

# Download Istio Release
if ! [ -e ${ISTIO_BASE_DIR} ]; then
  curl -L https://istio.io/downloadIstio | sh -
fi

# Access Istio Directory
cd ${ISTIO_BASE_DIR}

# Check if istioctl is installed
if ! which istioctl > /dev/null; then
  echo "create a symbolic link from $PWD/bin/istioctl for /usr/local/bin/istioctl (you should have a sudo permission)"
  sudo ln --symbolic $PWD/bin/istioctl /usr/local/bin/istioctl
else
  ISTIOCTL_INSTALLED_VERSION=$(istioctl version --remote=false)
  echo "istioctl ${ISTIOCTL_INSTALLED_VERSION} version currently installed"
fi

# Check if Helm is installed
if ! which helm > /dev/null; then
  echo "install"
  VERSION="3.3.1"
  TAR_FILE_NAME="helm-v${VERSION}-linux-amd64.tar.gz"
  wget https://get.helm.sh/${TAR_FILE_NAME}
  tar -zxvf ${TAR_FILE_NAME}
  sudo mv linux-amd64/helm /usr/local/bin/helm
  rm -rf linux-amd64
  rm -rf ${TAR_FILE_NAME}
else
  HELM_INSTALLED_VERSION=$(helm version --short)
  echo "istioctl ${HELM_INSTALLED_VERSION} version currently installed"
fi

# Check for Istio's Custom Resource Definitions (should not yet installed)
kubectl api-resources | grep -E "NAME|istio"

# Install Istio Operator Components using Helm
#   namespace..........: istio-operator
#   serviceaccount.....: istio-operator
#   clusterrole........: istio-operator
#   clusterrolebinding.: istio-operator
#   service............: istio-operator
#   deployment.apps....: istio-operator
helm template "manifests/charts/istio-operator/" \
  --set hub="docker.io/istio" \
  --set tag="${ISTIO_VERSION}" \
  --set operatorNamespace="istio-operator" \
  --set watchedNamespaces="istio-system" | kubectl apply -f -

# At this time, there are no Istio Custom Resource Definitions (CRDs)
#   istio-operator controller could not find the IstioOperator, and because of that, any objects of IstioOperator type could be create
kubectl -n istio-operator wait pod -l name=istio-operator --for=condition=Ready && \
kubectl -n istio-operator logs -f -l name=istio-operator

# Create Istio CRDs
kubectl apply -f "manifests/charts/istio-operator/crds/"

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
  name: istio-control-plane
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
eval $(minikube -p minikube docker-env)

docker build -t demo-health:1.0 ../demo-health

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
