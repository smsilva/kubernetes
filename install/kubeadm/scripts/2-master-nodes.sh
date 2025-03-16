# Configure Bash Completion
cat <<EOF | tee --append ~/.bashrc

source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF
source ~/.bashrc

# WARNING: We should run these commands ONLY on master-1
kubernetes_desired_version='1.32' && \
kubernetes_version="$(apt-cache madison kubeadm \
| grep ${kubernetes_desired_version} \
| head -1 \
| awk '{ print $3 }')" && \
kubernetes_base_version="${kubernetes_version%-*}" && \
node_name=$(hostname --short) && \
local_ip_address=$(grep $(hostname --short) /etc/hosts | awk '{ print $1 }') && \
load_balancer_port='6443' && \
load_balancer_name='loadbalancer.silvios.me' && \
control_plane_endpoint="${load_balancer_name}:${load_balancer_port}" && \
control_plane_endpoint_test=$(nc -d ${load_balancer_name} ${load_balancer_port} && echo "OK" || echo "FAIL") && \
clear && \
echo "" && \
echo "node_name..................: ${node_name}" && \
echo "local_ip_address...........: ${local_ip_address}" && \
echo "control_plane_endpoint.....: ${control_plane_endpoint} [${control_plane_endpoint_test}]" && \
echo "kubernetes_base_version....: ${kubernetes_base_version}" && \
echo ""

# Initialize master-1 (=~ 1 minute 30 seconds) - check: http://loadbalancer.example.com/stats
# Use with --pod-network-cidr "10.244.0.0/16" with Flannel CNI
kubeadm_log_file="${HOME}/kubeadm-init.log" && \
sudo kubeadm init \
  --v 3 \
  --node-name "${node_name?}" \
  --apiserver-advertise-address "${local_ip_address?}" \
  --kubernetes-version "${kubernetes_base_version?}" \
  --control-plane-endpoint "${control_plane_endpoint?}" \
  --pod-network-cidr "10.244.0.0/16" \
  --upload-certs \
| tee "${kubeadm_log_file?}"

# Config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Watch Nodes and Pods from kube-system namespace
watch -n 3 'kubectl get nodes -o wide; echo; kubectl -n kube-system get pods -o wide; echo; kubectl get services -A'

# (Another Terminal) Watch Interfaces and Route information
./watch-for-interfaces-and-routes.sh

# Check iptables
sudo iptables --table nat --verbose --numeric --list

# Install CNI Plugin
# kubectl apply -f "https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml"
# kubectl apply -f "https://projectcalico.docs.tigera.io/manifests/calico.yaml"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl --namespace kube-flannel wait --for condition=ready pod --selector app=flannel
kubectl --namespace kube-flannel logs --selector app=flannel --follow

# Retrieve token information from log file
kubeadm_log_file="${HOME}/kubeadm-init.log" && \
grep '\-\-certificate-key' "${kubeadm_log_file?}" --before 2 | grep \
  --only-matching \
  --extended-regexp '\-\-.*' | sed \
    -e 's/\-\-control-plane //' \
    -e 's/^\-\-//' \
    -e 's/ \\$//' \
    -e 's/^.* /\U&/' \
    -e 's/\-/_/g' \
    -e 's/ /=/' \
    -e 's/^/export KUBEADM_/'

# [PASTE HERE] Execute it on masters and workers
cat <<EOF > kubeadm-tokens
export KUBEADM_TOKEN=prku4u.xxxxxxxxxxxxxxxxxxxx
export KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH=sha256:xxxxxxxxxxxxxxxxxxxxxxxxxx
export KUBEADM_CERTIFICATE_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
EOF

# Join Command Variables
source kubeadm-tokens

node_name=$(hostname --short) && \
local_ip_address=$(grep ${node_name} /etc/hosts | head -1 | awk '{ print $1 }') && \
load_balancer_port='6443' && \
load_balancer_name='loadbalancer' && \
control_plane_endpoint="${load_balancer_name}:${load_balancer_port}" && \
control_plane_endpoint_test=$(curl -Is ${load_balancer_name}:${load_balancer_port} &> /dev/null && echo "OK" || echo "FAIL") && \
clear && \
echo "" && \
echo "node_name....................: ${node_name}" && \
echo "local_ip_address.............: ${local_ip_address}" && \
echo "control_plane_endpoint.......: ${control_plane_endpoint} [${control_plane_endpoint_test}]" && \
echo "TOKEN........................: ${KUBEADM_TOKEN}" && \
echo "DISCOVERY_TOKEN_CA_CERT_HASH.: ${KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH}" && \
echo ""

sudo kubeadm join "${control_plane_endpoint?}" \
  --v 0 \
  --control-plane \
  --node-name "${node_name?}" \
  --apiserver-advertise-address "${local_ip_address?}" \
  --token "${KUBEADM_TOKEN?}" \
  --discovery-token-ca-cert-hash "${KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH?}" \
  --certificate-key "${KUBEADM_CERTIFICATE_KEY?}" && \
./watch-for-interfaces-and-routes.sh
