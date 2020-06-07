# Test Connectivity to Loadbalancer
nc -dv lb 6443

# Check if there are a route that will be used by kube-proxy to communicate with API Server on Masters with kubernetes service Cluster IP Address (10.96.0.1)
route -n | grep "10.96.0.0"; if [[ $? == 0 ]]; then echo "OK"; else echo "FAIL"; fi

# Create a directory structure
mkdir images

# Update and Get Google Cloud Apt Key
sudo apt-get update | grep -v -E "^Hit|^Get" && \
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
if hostname -s | grep "master" &> /dev/null; then
  sudo apt-get install -y \
    kubeadm="${KUBERNETES_VERSION}" \
    kubelet="${KUBERNETES_VERSION}" \
    kubectl="${KUBERNETES_VERSION}" && \
  sudo apt-mark hold \
    kubelet \
    kubeadm \
    kubectl
else
  sudo apt-get install -y \
    kubeadm="${KUBERNETES_VERSION}" \
    kubelet="${KUBERNETES_VERSION}" && \
  sudo apt-mark hold \
    kubelet \
    kubeadm
fi

# CRI Config
sudo crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
sudo crictl images

# Preloading Container Images
if hostname -s | grep "master" &> /dev/null; then
  sudo kubeadm config images pull --v 3
else
  sudo crictl pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
fi

sudo crictl images

# Optional - Copy and Load Images
# vagrant plugin install vagrant-scp
# https://blog.scottlowe.org/2020/01/25/manually-loading-container-images-with-containerd/

# Export Images as tar files
docker images | sed '1d' | awk '{ print "docker save " $3 " -o " $1 ":" $2 ".tar" }' | sed 's/\//_/g; s/:/#/g' | sh

# Copy files to Masters and Workers
MASTERS=$(vgs | grep running | grep -E "master" | awk '{ print $1 }')
WORKERS=$(vgs | grep running | grep -E "worker" | awk '{ print $1 }')
IMAGES_DIRECTORY="/home/silvios/ssd-1/containers/images"
IMAGES_FOR_ALL="kube-proxy|pause|weave"
IMAGES_FOR_WORKERS="${IMAGES_FOR_ALL}|nginx|yauritux"
IMAGES_FOR_MASTERS="kube-apiserver|kube-controller-manager|kube-scheduler|etcd|coredns|${IMAGES_FOR_ALL}|(jcmoraisjr.*).*(haproxy-ingress)"
IMAGE_FILES=$(ls ${IMAGES_DIRECTORY}/*.tar)

for FILE in ${IMAGE_FILES}; do
  FILE_NAME="${FILE##*/}"
  echo "[${FILE_NAME}]"
  if grep -q -E "${IMAGES_FOR_MASTERS}" <<< "${FILE_NAME}"; then
    for SERVER in ${MASTERS}; do
      echo "  ${SERVER}..."
      vagrant scp ${FILE} ${SERVER}:~/images/ &> /dev/null
    done
  fi

  if grep -q -E "${IMAGES_FOR_WORKERS}" <<< "${FILE_NAME}"; then
    for SERVER in ${WORKERS}; do
      echo "  ${SERVER}..."
      vagrant scp ${FILE} ${SERVER}:~/images/ &> /dev/null
    done
  fi
  echo ""
done

# Pulling Images
sudo crictl pull k8s.gcr.io/coredns:1.6.7
sudo crictl pull k8s.gcr.io/etcd:3.4.3-0
sudo crictl pull k8s.gcr.io/kube-apiserver:v1.18.3
sudo crictl pull k8s.gcr.io/kube-controller-manager:v1.18.3
sudo crictl pull k8s.gcr.io/kube-proxy:v1.18.3
sudo crictl pull k8s.gcr.io/kube-scheduler:v1.18.3
sudo crictl pull k8s.gcr.io/pause:3.2
sudo crictl pull nginx:1.19
sudo crictl pull nginx:1.18
sudo crictl pull yauritux/busybox-curl
sudo crictl pull weaveworks/weave-npc:2.6.4
sudo crictl pull weaveworks/weave-kube:2.6.4
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest

# Pull for All Platforms
# https://github.com/containerd/containerd/issues/3340
sudo crictl images | awk '{ print "sudo ctr image pull --all-platforms " $1 ":" $2 }' | sed '1d' | sh

# Export images to tar files
sudo crictl images | awk '{ print $1 ":" $2 }' | sed '1d' | while read line; do
FILE_NAME=$(echo $(sed 's/\//_/g; s/:/#/' <<< ${line}).tar)
echo "${line} --> ${FILE_NAME}"
sudo ctr image export ${FILE_NAME} $line
done

# Remove
sudo ctr images ls | sed '1d' | awk '{ print $1 }' | while read line; do sudo ctr images remove ${line}; done
sudo crictl images | sed '1d' | awk '{ print $3 }' | while read line; do sudo crictl rmi ${line}; done
