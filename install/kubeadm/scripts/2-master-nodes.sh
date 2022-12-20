# Configure Bash Completion
cat <<EOF | tee --append ~/.bashrc

source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF
source ~/.bashrc

# WARNING: We should run these commands ONLY on master-1
KUBERNETES_DESIRED_VERSION='1.25' && \
KUBERNETES_VERSION="$(apt-cache madison kubeadm | grep ${KUBERNETES_DESIRED_VERSION} | head -1 | awk '{ print $3 }')" && \
KUBERNETES_BASE_VERSION="${KUBERNETES_VERSION%-*}" && \
LOCAL_IP_ADDRESS=$(grep $(hostname --short) /etc/hosts | awk '{ print $1 }') && \
LOAD_BALANCER_PORT='6443' && \
LOAD_BALANCER_NAME='lb' && \
CONTROL_PLANE_ENDPOINT="${LOAD_BALANCER_NAME}:${LOAD_BALANCER_PORT}" && \
CONTROL_PLANE_ENDPOINT_TEST=$(nc -d ${LOAD_BALANCER_NAME} ${LOAD_BALANCER_PORT} && echo "OK" || echo "FAIL") && \
clear && \
echo "" && \
echo "LOCAL_IP_ADDRESS...........: ${LOCAL_IP_ADDRESS}" && \
echo "CONTROL_PLANE_ENDPOINT.....: ${CONTROL_PLANE_ENDPOINT} [${CONTROL_PLANE_ENDPOINT_TEST}]" && \
echo "KUBERNETES_BASE_VERSION....: ${KUBERNETES_BASE_VERSION}" && \
echo ""

# Watch Interfaces and Route information
./watch-for-interfaces-and-routes.sh

# Initialize master-1 (=~ 1 minute 30 seconds) - check: http://loadbalancer.example.com/stats
SECONDS=0 && \
KUBEADM_LOG_FILE="${HOME}/kubeadm-init.log" && \
NODE_NAME=$(hostname --short) && \
sudo kubeadm init \
  --v 3 \
  --node-name "${NODE_NAME?}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS?}" \
  --kubernetes-version "${KUBERNETES_BASE_VERSION?}" \
  --control-plane-endpoint "${CONTROL_PLANE_ENDPOINT?}" \
  --upload-certs | tee "${KUBEADM_LOG_FILE?}" && \
printf 'Elapsed time: %02d:%02d\n' $((${SECONDS} % 3600 / 60)) $((${SECONDS} % 60))

# Config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Watch Nodes and Pods from kube-system namespace
watch -n 3 'kubectl get nodes,pods,services -o wide -n kube-system'

# Install CNI Plugin
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
# https://medium.com/google-cloud/understanding-kubernetes-networking-pods-7117dd28727
# 
# kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl apply -f weave-net-cni-plugin.yaml

# Retrieve token information from log file
KUBEADM_LOG_FILE="${HOME}/kubeadm-init.log" && \
grep '\-\-certificate-key' "${KUBEADM_LOG_FILE?}" --before 2 | grep \
  --only-matching \
  --extended-regexp '\-\-.*' | sed \
    -e 's/\-\-control-plane //' \
    -e 's/^\-\-//' \
    -e 's/ \\$//' \
    -e 's/^.* /\U&/' \
    -e 's/\-/_/g' \
    -e 's/ /=/' \
    -e 's/^/export KUBEADM_/'

# [PASTE HERE] Execute on master-2 and master-3 and on all workers
export KUBEADM_TOKEN=o7r9z1.vokk4lh8ff2k7osf
export KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH=sha256:bde0c0f86d6d8e6935cda2878243ca85923d34e9d64e3ca84cb530a54a770cfb
export KUBEADM_CERTIFICATE_KEY=db4f9f97c879938a1a1a8eb3081562104dbfa144291fb0ceaf40fce5f0ad214e

# Join Command
NODE_NAME=$(hostname --short) && \
LOCAL_IP_ADDRESS=$(grep ${NODE_NAME} /etc/hosts | head -1 | awk '{ print $1 }') && \
LOAD_BALANCER_PORT='6443' && \
LOAD_BALANCER_NAME='lb' && \
CONTROL_PLANE_ENDPOINT="${LOAD_BALANCER_NAME}:${LOAD_BALANCER_PORT}" && \
CONTROL_PLANE_ENDPOINT_TEST=$(curl -Is ${LOAD_BALANCER_NAME}:${LOAD_BALANCER_PORT} &> /dev/null && echo "OK" || echo "FAIL") && \
clear && \
echo "" && \
echo "NODE_NAME....................: ${NODE_NAME}" && \
echo "LOCAL_IP_ADDRESS.............: ${LOCAL_IP_ADDRESS}" && \
echo "CONTROL_PLANE_ENDPOINT.......: ${CONTROL_PLANE_ENDPOINT} [${CONTROL_PLANE_ENDPOINT_TEST}]" && \
echo "TOKEN........................: ${KUBEADM_TOKEN}" && \
echo "DISCOVERY_TOKEN_CA_CERT_HASH.: ${KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH}" && \
echo ""

sudo kubeadm join "${CONTROL_PLANE_ENDPOINT?}" \
  --v 3 \
  --control-plane \
  --node-name "${NODE_NAME?}" \
  --apiserver-advertise-address "${LOCAL_IP_ADDRESS?}" \
  --token "${KUBEADM_TOKEN?}" \
  --discovery-token-ca-cert-hash "${KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH?}" \
  --certificate-key "${KUBEADM_CERTIFICATE_KEY?}" && \
./watch-for-interfaces-and-routes.sh

# Monitoring during presentation (narrow screen space)
cat <<EOF > namespace-info.sh
kubectl get nodes -o wide | sed "s/Ubuntu.*LTS/Ubuntu/g" | awk '{ print \$1,\$2,\$5,\$6,\$10 }' | column -t
echo ""
kubectl get ds -o wide | sed 's/NODE SELECTOR/NODE_SELECTOR/' | awk '{ print \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$11 }' | column -t
echo ""
kubectl get cm,deploy -o wide
echo ""
kubectl get rs -o wide | awk '{ print \$1, \$2, \$3, \$4, \$5, \$6, \$7 }' | column -t
echo ""
kubectl get pods -o wide | awk '{ print \$1, \$2, \$3, \$4, \$5, \$6, \$7 }' | column -t
echo ""
kubectl get svc,ep,ing,pv,pvc -o wide
EOF
chmod +x *.sh
clear
ls
