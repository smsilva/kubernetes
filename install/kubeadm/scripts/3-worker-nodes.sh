# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token u32c89.1p22tpar81a64oip \
  --discovery-token-ca-cert-hash sha256:6a4667711975b74b7dec401c8c389b83278a28722ed5cead4e60166630938e8c \
  --v 5

######################## Hey!!! Check Container Images after Node Join please!!!

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
