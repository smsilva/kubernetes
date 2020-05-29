# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token g0lt0m.dx5orzp4tp45h7xh \
  --discovery-token-ca-cert-hash sha256:142294b72aaf62b2b2662fafda9d6b1848df755409e5418790e92150720f9c18 \
  --v 1
