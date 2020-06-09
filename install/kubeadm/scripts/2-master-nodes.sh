# Configure Bash Completion
cat <<EOF | tee --append ~/.bashrc

source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF

source ~/.bashrc

# WARNING: We should run these commands ONLY on master-1
KUBERNETES_DESIRED_VERSION='1.18' && \
KUBERNETES_VERSION="$(sudo apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }')" && \
KUBERNETES_BASE_VERSION="${KUBERNETES_VERSION%-*}" && \
LOCAL_IP_ADDRESS=$(grep $(hostname --short) /etc/hosts | awk '{ print $1 }') && \
LOAD_BALANCER_PORT='6443' && \
LOAD_BALANCER_NAME='lb' && \
CONTROL_PLANE_ENDPOINT="${LOAD_BALANCER_NAME}:${LOAD_BALANCER_PORT}" && \
echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo "CONTROL_PLANE_ENDPOINT.....: ${CONTROL_PLANE_ENDPOINT}" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

# Initialize master-1 (less than 1 minute)
SECONDS=0 && \
KUBEADM_LOG_FILE="${HOME}/kubeadm-init.log" && \
NODE_NAME=$(hostname --short) && \
sudo kubeadm init \
  --v 3 \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION}" \
  --control-plane-endpoint "${CONTROL_PLANE_ENDPOINT}" \
  --upload-certs | tee "${KUBEADM_LOG_FILE}" && \
printf '%d hour %d minute %d seconds\n' $((${SECONDS}/3600)) $((${SECONDS}%3600/60)) $((${SECONDS}%60))

# Config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Watch Nodes and Pods from kube-system namespace
watch -n 3 'kubectl get nodes,pods,services -o wide -n kube-system'

# Install CNI Plugin
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
# https://medium.com/google-cloud/understanding-kubernetes-networking-pods-7117dd28727
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Retrieve token information from log file
KUBEADM_LOG_FILE="${HOME}/kubeadm-init.log" && \
grep "\-\-certificate-key" "${KUBEADM_LOG_FILE}" --before 2 | grep \
  --only-matching \
  --extended-regexp "\-\-.*" | sed 's/\-\-control-plane //; s/^/  /'

# Adding a Control Plane Node
NODE_NAME=$(hostname --short) && \
LOCAL_IP_ADDRESS=$(grep ${NODE_NAME} /etc/hosts | head -1 | awk '{ print $1 }') && \
echo "" && \
echo "NODE_NAME..................: ${NODE_NAME}" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
sudo kubeadm join lb:6443 \
  --v 3 \
  --control-plane \
  --node-name "${NODE_NAME}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS}" \
  --token zqvyzl.gvjyh9biqqzi02c9 \
  --discovery-token-ca-cert-hash sha256:288b39766f30e89f7c68740d7e33e3a669dac97648358472b634f880448cd7b4 \
  --certificate-key 8650849e8edb18eefffc684f29d8a4e46419cc00ea87fd50b66c7cbe6a13eeff

# Optional - Configure Vim to use yaml format a little bit better
cat <<EOF >> .vimrc
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
EOF

# Optional - bat
BAT_VERSION="0.15.1" && \
BAT_DEB_FILE="bat_${BAT_VERSION}_amd64.deb" && \
wget "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${BAT_DEB_FILE}" \
  --output-document "${BAT_DEB_FILE}" && \
sudo dpkg -i "${BAT_DEB_FILE}" && rm "${BAT_DEB_FILE}" && \
echo "alias cat='bat -p'" >> ~/.bash_aliases && source ~/.bash_aliases && bat --version

# Optional - jq
sudo apt install jq --yes

# Optional - yq
sudo snap install yq

echo "alias yq='yq -C -P'" >> ~/.bashrc && source ~/.bashrc
