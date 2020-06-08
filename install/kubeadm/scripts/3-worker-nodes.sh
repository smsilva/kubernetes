# Optional
sudo crictl pull nginx:1.19
sudo crictl pull nginx:1.18
sudo crictl pull yauritux/busybox-curl
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest

# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token hjxdra.ce9fbkxc0pz4z2ch \
  --discovery-token-ca-cert-hash sha256:b4415d0eabc5f91825ad5e34eff8b757ae89d415efa2ce36e5db6bdab0ebeeb0 \
  --v 3
