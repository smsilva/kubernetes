# Test Connectivity to Loadbalancer
nc -dv lb 6443

# Check if there are a route that will be used by kube-proxy to communicate with API Server on Masters with kubernetes service Cluster IP Address (10.96.0.1)
route -n | grep "10.96.0.0"; if [[ $? == 0 ]]; then echo "OK"; else echo "FAIL"; fi

# Docker Test
docker ps

# All Nodes
sudo apt update &> /dev/null && \
sudo apt install -y \
  apt-transport-https \
  curl &> /dev/null && \
sudo curl -s "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt-get update | grep -v -E "^Hit|^Get"

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.18'
KUBERNETES_VERSION="$(echo -n $(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }'))"
KUBERNETES_BASE_VERSION="${KUBERNETES_VERSION%-*}"

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

# Preloading Container Images and Install some Tools on Master Nodes
if hostname -s | grep "master" &>/dev/null; then
  echo 'source <(kubectl completion bash)' >> ~/.bashrc
  echo 'alias k=kubectl' >> ~/.bashrc
  echo 'complete -F __start_kubectl k' >> ~/.bashrc
  source ~/.bashrc

  kubeadm config images pull

  sudo apt-get install -y jq
  sudo snap install yq
  wget https://github.com/sharkdp/bat/releases/download/v0.15.1/bat_0.15.1_amd64.deb -O bat_amd64.deb
  sudo dpkg -i bat_amd64.deb && rm bat_amd64.deb
  echo "alias cat='bat -p'" >> ~/.bash_aliases && source ~/.bash_aliases 
else
  docker pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
fi
