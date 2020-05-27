# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token awzwx8.vdt5bzstukgmziyf \
  --discovery-token-ca-cert-hash sha256:b7adba78720b5ca0fed6c03d0bd723980c53f0e158d1a886275af778ab2cc0e2 \
  --v 5
