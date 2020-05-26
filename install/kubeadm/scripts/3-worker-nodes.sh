# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token tz04xo.bbtrcbeeqmuxlc9l \
  --discovery-token-ca-cert-hash sha256:4e115444bf73d7c34aab6a7d2131fa51aa1767bde5d9750694fa4b6979ac05e1 \
  --v 5
