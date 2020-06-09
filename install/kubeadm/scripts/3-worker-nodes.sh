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
  --token jiyoc2.aqgayeyf8jwt9m6f \
  --discovery-token-ca-cert-hash sha256:554c4354d7d996f4da6fb8a55cf6018116cfe406d60d68329b703d8c90b7d32e \
  --v 3
