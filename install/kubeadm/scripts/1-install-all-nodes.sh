# Test Connectivity to Loadbalancer
nc -d lb 6443 && echo "OK" || echo "FAIL"

# Check if there are a route that will be used by Services
route -n | grep --quiet "10.96.0.0" && echo "OK" || echo "FAIL"

# Update and Get Google Cloud Apt Key
sudo apt-get update -qq && \
sudo curl --silent "https://packages.cloud.google.com/apt/doc/apt-key.gpg" | sudo apt-key add -

# Add Kubernetes Repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update package list
sudo apt-get update -q

# Set Kubernetes Version
KUBERNETES_DESIRED_VERSION='1.18' && \
KUBERNETES_VERSION="$(apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }')" && \
KUBERNETES_IMAGE_VERSION="${KUBERNETES_VERSION%-*}" && \
clear && \
echo "" && \
echo "KUBERNETES_DESIRED_VERSION.: ${KUBERNETES_DESIRED_VERSION}" && \
echo "KUBERNETES_VERSION.........: ${KUBERNETES_VERSION}" && \
echo "KUBERNETES_IMAGE_VERSION...: ${KUBERNETES_IMAGE_VERSION}" && \
echo ""

# Install Kubelet, Kubeadm and Kubectl
#   all =~ 1 minute 30 seconds
SECONDS=0 && \
if grep --quiet "master" <<< $(hostname --short); then
  sudo apt-get install --yes -qq \
    kubeadm="${KUBERNETES_VERSION}" \
    kubelet="${KUBERNETES_VERSION}" \
    kubectl="${KUBERNETES_VERSION}" | grep --invert-match --extended-regexp "^Hit|^Get|^Selecting|^Preparing|^Unpacking" && \
  sudo apt-mark hold \
    kubelet \
    kubeadm \
    kubectl
else
  sudo apt-get install --yes -qq \
    kubeadm="${KUBERNETES_VERSION}" \
    kubelet="${KUBERNETES_VERSION}" | grep --invert-match --extended-regexp "^Hit|^Get|^Selecting|^Preparing|^Unpacking" && \
  sudo apt-mark hold \
    kubelet \
    kubeadm
fi && \
clear && \
printf 'Elapsed time: %02d:%02d\n' $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60))

# CRI Config
CONTAINERD_SOCK="unix:///var/run/containerd/containerd.sock" && \
sudo crictl config \
  runtime-endpoint "${CONTAINERD_SOCK}" \
  image-endpoint "${CONTAINERD_SOCK}" && \
clear && \
sudo crictl images

# CNI Plugin
#   CIDR.......: 10.32.0.0/16 (https://community.spiceworks.com/tools/subnet-calc/)
#   Start......: 10.32.0.1
#   End........: 10.32.255.254
#   Hosts......: 65.534
WEAVE_NET_CNI_PLUGIN_IPALLOCRANGE="10.32.0.0/16" && \
WEAVE_NET_CNI_PLUGIN_FILE="weave-net-cni-plugin.yaml" && \
WEAVE_NET_CNI_PLUGIN_URL="https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version 2> /dev/null | base64 | tr -d '\n')&env.IPALLOC_RANGE=${WEAVE_NET_CNI_PLUGIN_IPALLOCRANGE}" && \
wget "${WEAVE_NET_CNI_PLUGIN_URL}" \
  --quiet \
  --output-document "${WEAVE_NET_CNI_PLUGIN_FILE}"
clear
ls

# Preloading Container Images
#   masters =~ 1 minute 30 seconds
#   workers < 1 minute
SECONDS=0 && \
if grep --quiet "master" <<< $(hostname --short); then
  sudo kubeadm config images pull --kubernetes-version "${KUBERNETES_IMAGE_VERSION}"
else
  sudo crictl pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_IMAGE_VERSION}"
fi
printf 'Elapsed time: %02d:%02d\n' $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60))
SECONDS=0 && \
grep "image:" "${WEAVE_NET_CNI_PLUGIN_FILE}" | awk -F "'" '{ print "sudo crictl pull " $2 }' | sh
printf 'Elapsed time: %02d:%02d\n' $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60))

# List Images
sudo crictl images && echo "" && \
  sudo crictl images | sed 1d | wc -l

# Script to Watch Interfaces and Route information
cat <<EOF > watch-for-interfaces-and-routes.sh
while true; do
  ip -4 a | sed -e '/valid_lft/d' | awk '{ print \$1, \$2 }' | sed 'N;s/\n/ /' | tr -d ":" | awk '{ print \$2, \$4 }' | sort | sed '1iINTERFACE CIDR' | column -t && \
  echo "" && \
  route -n | sed /^Kernel/d | awk '{ print \$1, \$2, \$3, \$4, \$5, \$8 }' | column -t && echo "" && \
  sleep 3 && \
  clear
done
EOF
chmod +x watch-for-interfaces-and-routes.sh
clear
./watch-for-interfaces-and-routes.sh

# Optional
if grep --quiet "master" <<< $(hostname --short); then
  sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest
else
  sudo crictl pull nginx:1.18 && \
  sudo crictl pull nginx:1.19 && \
  sudo crictl pull yauritux/busybox-curl
fi
