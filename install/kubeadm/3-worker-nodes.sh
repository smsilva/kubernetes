# first, check if there are a route that will be used by kube-proxy to communicate with API Server on Masters with kubernetes service Cluster IP Address (10.96.0.1)
route -n | grep "10.96.0.0"; if [[ $? == 0 ]]; then echo "OK"; else echo "FAIL"; fi

# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
sudo kubeadm join lb:6443 \
  --token f0818g.r9fakwhksxmbj0ui \
  --discovery-token-ca-cert-hash sha256:5037f60906c7dd6ff1fa7fa606ab8d7b62ab164bcf2e52b19f19acd929b7d651 \
  --v 5
