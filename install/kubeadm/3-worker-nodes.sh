# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 43g3tq.eoc7u9mb7t3zxkkx \
  --discovery-token-ca-cert-hash sha256:5aa40a8d2aaaf2af2524561e9efc1d5bf453266cd013362b65b6d3fa9bef47d7 \
  --v 1

######################## Hey!!! Check Container Images after Node Join please!!!

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
