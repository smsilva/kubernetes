# Test Connectivity to Loadbalancer
nc -d loadbalancer 6443 && echo "OK" || echo "FAIL"

# Update
sudo apt-get update -qq && \
sudo apt-get install --yes \
  apt-transport-https \
  ca-certificates \
  curl

# Get Google Cloud Apt Key
sudo curl \
  --location \
  --output "/usr/share/keyrings/kubernetes-archive-keyring.gpg" \
  "https://packages.cloud.google.com/apt/doc/apt-key.gpg"

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt-get update -q

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.25' && \
KUBERNETES_VERSION="$(apt-cache madison kubeadm \
| grep ${KUBERNETES_DESIRED_VERSION} \
| head -1 \
| awk '{ print $3 }')" && \
KUBERNETES_IMAGE_VERSION="${KUBERNETES_VERSION%-*}" && \
clear && \
echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo "KUBERNETES_IMAGE_VERSION...: ${KUBERNETES_IMAGE_VERSION}" && \
echo ""

# Install and Mark Hold: kubelet, kubeadm and kubectl
sudo apt-get install --yes -q \
  kubeadm="${KUBERNETES_VERSION?}" \
  kubelet="${KUBERNETES_VERSION?}" \
  kubectl="${KUBERNETES_VERSION?}" \
| egrep --invert-match "^Hit|^Get|^Selecting|^Preparing|^Unpacking" && \
sudo apt-mark hold \
  kubelet \
  kubeadm \
  kubectl

# containerd config
CONTAINERD_SOCK="unix:///var/run/containerd/containerd.sock" && \
sudo crictl config \
  runtime-endpoint "${CONTAINERD_SOCK}" \
  image-endpoint "${CONTAINERD_SOCK}" && \
clear && \
sudo crictl images

# Preloading Container Images
if grep --quiet "master" <<< $(hostname --short); then
  sudo kubeadm config images pull --kubernetes-version "${KUBERNETES_IMAGE_VERSION}"
else
  sudo crictl pull "registry.k8s.io/kube-proxy:v${KUBERNETES_IMAGE_VERSION}"
fi

# List Images
sudo crictl images
