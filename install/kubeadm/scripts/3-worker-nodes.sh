source kubeadm-tokens

LOCAL_IP_ADDRESS=$(grep $(hostname --short) /etc/hosts | awk '{ print $1 }') && \
NODE_NAME=$(hostname --short) && \
LOAD_BALANCER_PORT='6443' && \
LOAD_BALANCER_NAME='loadbalancer' && \
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
  --v 0 \
  --node-name "${NODE_NAME?}" \
  --token "${KUBEADM_TOKEN?}" \
  --discovery-token-ca-cert-hash "${KUBEADM_DISCOVERY_TOKEN_CA_CERT_HASH?}" \
| tee "kubeadm-join.log"

# Example
kubectl create deploy nginx \
  --image nginx \
  --replicas 4

kubectl expose deploy nginx \
  --port 80 \
  --type NodePort \
  --dry-run=client \
  --override-type 'merge' \
  --overrides '{ "spec": { "ports": [ { "protocol": "TCP", "port": 80, "targetPort": 80, "nodePort": 32080 } ] } }' \
  --output yaml \
| kubectl apply -f -
