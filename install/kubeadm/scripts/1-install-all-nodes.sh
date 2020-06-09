# Test Connectivity to Loadbalancer
nc -d lb 6443 && echo "OK" || echo "FAIL"

# Check if there are a route that will be used by Services
route -n | grep --quiet "10.96.0.0" && echo "OK" || echo "FAIL"

# Update and Get Google Cloud Apt Key
sudo apt-get update | grep --invert-match --extended-regexp "^Hit|^Get" && \
sudo curl --silent "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt-get update | grep --invert-match --extended-regexp "^Hit|^Get"

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.18' && \
KUBERNETES_VERSION="$(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }')" && \
KUBERNETES_BASE_VERSION="${KUBERNETES_VERSION%-*}" && \
echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

# Install Kubelet, Kubeadm and Kubectl
SECONDS=0 && \
if grep --quiet "master" <<< $(hostname --short); then
  sudo apt-get install --yes \
    kubeadm="${KUBERNETES_VERSION}" \
    kubelet="${KUBERNETES_VERSION}" \
    kubectl="${KUBERNETES_VERSION}" && \
  sudo apt-mark hold \
    kubelet \
    kubeadm \
    kubectl
else
  sudo apt-get install --yes \
    kubeadm="${KUBERNETES_VERSION}" \
    kubelet="${KUBERNETES_VERSION}" && \
  sudo apt-mark hold \
    kubelet \
    kubeadm
fi && \
printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

# CRI Config
sudo crictl config \
  runtime-endpoint unix:///var/run/containerd/containerd.sock \
  image-endpoint   unix:///var/run/containerd/containerd.sock && \
sudo crictl images

# Preloading Container Images
#   masters =~ 1 minute 30 seconds
#   workers < 1 minute
SECONDS=0 && \
if grep --quiet "master" <<< $(hostname --short); then
  sudo kubeadm config images pull
else
  sudo crictl pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
fi
sudo crictl pull docker.io/weaveworks/weave-kube:2.6.4
sudo crictl pull docker.io/weaveworks/weave-npc:2.6.4
printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

# List Images
sudo crictl images
