# Test Connectivity to Loadbalancer
nc -d loadbalancer 6443 && echo "OK" || echo "FAIL"

# Update
sudo apt-get update --quiet && \
sudo apt-get install --yes \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg

# Get Google Cloud Apt Key
sudo mkdir --parents --mode 755 /etc/apt/keyrings

# Set Kubernetes Version
kubernetes_desired_version="1.32"

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --url "https://pkgs.k8s.io/core:/stable:/v${kubernetes_desired_version?}/deb/Release.key" \
| sudo gpg \
  --dearmor \
  --yes \
  --output /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Allow unprivileged APT programs to read this keyring
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kubernetes_desired_version?}/deb/ /
EOF

# Update package list
sudo apt update --quiet

kubernetes_version="$(apt-cache madison kubeadm \
| grep ${kubernetes_desired_version} \
| head -1 \
| awk '{ print $3 }')" && \
kubernetes_image_version="${kubernetes_version%-*}" && \
clear && \
echo "" && \
echo "kubernetes_desired_version.: ${kubernetes_desired_version}" && \
echo "kubernetes_version.........: ${kubernetes_version}" && \
echo "kubernetes_image_version...: ${kubernetes_image_version}" && \
echo ""

# Install and Mark Hold: kubelet, kubeadm and kubectl
sudo apt-get install --yes --quiet \
  kubeadm="${kubernetes_version?}" \
  kubelet="${kubernetes_version?}" \
  kubectl="${kubernetes_version?}" \
| grep --invert-match --extended-regexp "^Hit|^Get|^Selecting|^Preparing|^Unpacking" && \
sudo apt-mark hold \
  kubelet \
  kubeadm \
  kubectl

cat <<EOF > k8s.conf
kubernetes_desired_version="${kubernetes_desired_version?}"
kubernetes_version="${kubernetes_version?}"
kubernetes_image_version="${kubernetes_image_version?}"
EOF

# crictl configuration
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

sudo groupadd containerd

sudo chgrp containerd /run/containerd/containerd.sock

sudo usermod \
  --append \
  --groups containerd \
  ${USER}

crictl images

source k8s.conf

# Preloading Container Images
if grep --quiet "master" <<< $(hostname --short); then
  sudo kubeadm config images pull --kubernetes-version "${kubernetes_image_version?}"
else
  crictl pull "registry.k8s.io/kube-proxy:v${kubernetes_image_version?}"
fi

crictl images
