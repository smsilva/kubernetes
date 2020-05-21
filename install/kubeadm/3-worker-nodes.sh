# first, check if there are a route that will be used by kube-proxy to communicate with API Server on Masters with kubernetes service Cluster IP Address (10.96.0.1)
route -n | grep "10.96.0.0"; if [[ $? == 0 ]]; then echo "OK"; else echo "FAIL"; fi

# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token eql8x7.frxy06rj6ijbry3w \
  --discovery-token-ca-cert-hash sha256:c9fba29f17ccd845fb065491f10b9472faac23c2f59d6f9754c63ca00e8b3121 \
  --v 3

# Reset Node Config
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d && \
sudo rm -rf ${HOME}/.kube/config
