# first, check if there are a route that will be used by kube-proxy to communicate with API Server on Masters with kubernetes service Cluster IP Address (10.96.0.1)
route -n | grep -E "Destination|10.96.0.0"

# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
sudo kubeadm join lb:6443 \
  --token 46xyy8.pqhgc1823z7gp4h1 \
  --discovery-token-ca-cert-hash sha256:238962e04d9dbe5c78b047a3dc3333cccb91f4ac577e806b4b519ae26b9eb451 \
  --v 5

# Reseting kubeadm config to try again
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
