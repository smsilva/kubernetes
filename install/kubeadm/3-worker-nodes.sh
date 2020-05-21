# first, check if there are a route that will be used by kube-proxy to communicate with API Server on Masters with kubernetes service Cluster IP Address (10.96.0.1)
route -n | grep "10.96.0.0"; if [[ $? == 0 ]]; then echo "OK"; else echo "FAIL"; fi

# The parameters below are getting from the first Contol Plane Config
#   - token
#   - discovery-token-ca-cert-hash
sudo kubeadm join lb:6443 \
  --token 7ers7r.gpa3s5c1qzruju7l \
  --discovery-token-ca-cert-hash sha256:2ccab60fa1c058dd1ab716e0508d408996ddddbd7a98280776ddad7f15484442 \
  --v 5
