source kubeadm-tokens

local_ip_address=$(grep $(hostname --short) /etc/hosts | awk '{ print $1 }') && \
node_name=$(hostname --short) && \
load_balancer_port='6443' && \
load_balancer_name='loadbalancer' && \
control_plane_endpoint="${load_balancer_name}:${load_balancer_port}" && \
control_plane_endpoint_test=$(curl -Is ${load_balancer_name}:${load_balancer_port} &> /dev/null && echo "OK" || echo "FAIL") && \
clear && \
echo "" && \
echo "node_name....................: ${node_name}" && \
echo "local_ip_address.............: ${local_ip_address}" && \
echo "control_plane_endpoint.......: ${control_plane_endpoint} [${control_plane_endpoint_test}]" && \
echo "KUBEADM_TOKEN................: ${KUBEADM_TOKEN}" && \
echo "DISCOVERY_TOKEN_CA_CERT_HASH.: ${KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH}" && \
echo ""

sudo kubeadm join "${control_plane_endpoint?}" \
  --v 3 \
  --node-name "${node_name?}" \
  --token "${KUBEADM_TOKEN?}" \
  --discovery-token-ca-cert-hash "${KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH?}" \
| tee "kubeadm-join.log"

# Example
kubectl create deploy nginx \
  --image nginx \
  --replicas 3

kubectl expose deploy nginx \
  --port 80 \
  --type NodePort \
  --dry-run=client \
  --override-type 'merge' \
  --overrides '{ "spec": { "ports": [ { "protocol": "TCP", "port": 80, "targetPort": 80, "nodePort": 32080 } ] } }' \
  --output yaml \
| kubectl apply -f -
