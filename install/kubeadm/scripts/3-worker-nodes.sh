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
  --token htdes2.41ao8r8pn3ut7up3 \
  --discovery-token-ca-cert-hash sha256:1d5cb183874a17ac07ed23617ab29e8876c8c2e11c76724696f7cad6f348e9c6 \
  --v 3
