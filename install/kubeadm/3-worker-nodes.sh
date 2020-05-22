# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 69qawj.xcghgjhqkx4ifwd4 \
  --discovery-token-ca-cert-hash sha256:5b995e595271f940bc3c7198ff05048aa43cae5522e47b9baa8ba13d5d730975 \
  --v 1

######################## Hey!!! Check Container Images after Node Join please!!!

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
