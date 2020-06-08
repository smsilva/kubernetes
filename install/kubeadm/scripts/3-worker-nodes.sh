# Optional
sudo crictl pull docker.io/weaveworks/weave-kube:2.6.4
sudo crictl pull docker.io/weaveworks/weave-npc:2.6.4
sudo crictl pull nginx:1.19
sudo crictl pull nginx:1.18
sudo crictl pull yauritux/busybox-curl
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest

# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 5ar6d6.lgqv8j1bqexpwyai \
  --discovery-token-ca-cert-hash sha256:77a3055f05e1dce428a05277d2b9539898ebaa438f3e3e436d493d1e62fd94eb \
  --v 3
