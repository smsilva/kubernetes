# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token jzmmxw.9n9snti5mbjdg2q6 \
  --discovery-token-ca-cert-hash sha256:44a541f3ec63fb72385352a13abe5ce4c9b0b2aac60cf7ba61148f8e2a51785f \
  --v 1

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
