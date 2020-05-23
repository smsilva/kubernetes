# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 7u4s03.43wgc0blrfqjs71n \
  --discovery-token-ca-cert-hash sha256:8eba5ee02bfb846ad418ad425c908eb3cf726ece25dca48b8b4333b163059ae5 \
  --v 5

######################## Hey!!! Check Container Images after Node Join please!!!

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
