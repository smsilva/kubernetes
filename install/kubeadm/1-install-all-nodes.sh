# Docker Test
docker ps

# All Nodes
sudo apt update && \
sudo apt install -y \
  apt-transport-https \
  curl && \
sudo curl -s "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt update

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.18'
KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))"
KUBERNETES_BASE_VERSION="$(echo ${KUBERNETES_VERSION} | cut -d- -f 1)"

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
  echo 'source <(kubectl completion bash)' >> ~/.bashrc
  echo 'alias k=kubectl' >> ~/.bashrc
  echo 'complete -F __start_kubectl k' >> ~/.bashrc
  source ~/.bashrc

  kubeadm config images pull
else
  docker pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
fi
