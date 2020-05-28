# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token tbbn9r.uc4nztyv6ysuckzw \
  --discovery-token-ca-cert-hash sha256:e817afb87e1a3e9372ce6e9e1b689cec4425458036433eccee6a19ed754daf8c \
  --v 1
