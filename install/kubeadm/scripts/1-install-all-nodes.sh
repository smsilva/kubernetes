# Test Connectivity to Loadbalancer
nc -dv lb 6443

# Check if there are a route that will be used by kube-proxy to communicate with API Server on Masters with kubernetes service Cluster IP Address (10.96.0.1)
route -n | grep "10.96.0.0"; if [[ $? == 0 ]]; then echo "OK"; else echo "FAIL"; fi

# Docker Test
docker images

# Configure Vim to use yaml format a little bit better
cat <<EOF >> .vimrc
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
EOF

# All Nodes
sudo apt update &> /dev/null && \
sudo apt install -y \
  apt-transport-https \
  curl && \
sudo curl -s "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt-get update | grep -v -E "^Hit|^Get"

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.18' && \
KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))" && \
KUBERNETES_BASE_VERSION="${KUBERNETES_VERSION%-*}" && \
echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

# Install Kubelet, Kubeadm and Kubectl
sudo apt-get install -y \
  kubeadm="${KUBERNETES_VERSION}" \
  kubelet="${KUBERNETES_VERSION}" \
  kubectl="${KUBERNETES_VERSION}" && \
sudo apt-mark hold \
  kubelet \
  kubeadm \
  kubectl

# Preloading Container Images
if hostname -s | grep "master" &>/dev/null; then
  kubeadm config images pull
  docker pull quay.io/jcmoraisjr/haproxy-ingress:latest
else
  docker pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
  docker pull nginx:1.17.10
  docker pull nginx:1.18.0
  docker pull yauritux/busybox-curl
fi

# Optional - Ingress HAProxy Controller
# https://github.com/jcmoraisjr/haproxy-ingress
# https://haproxy-ingress.github.io/docs/getting-started/
# https://haproxy-ingress.github.io/docs/configuration/keys/
kubectl create -f https://haproxy-ingress.github.io/resources/haproxy-ingress.yaml

for NODE in master-{1..3}; do
  kubectl label node ${NODE} role=ingress-controller
done
