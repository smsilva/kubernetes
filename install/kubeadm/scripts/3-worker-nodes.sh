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
  --token srmffa.43ahrenjxt3hsxor \
  --discovery-token-ca-cert-hash sha256:ade4239dce6272f7eeb27ed1fd5df7678b5c1ffb1c9ca16dcc4ebbdc141ede59 \
  --v 3
