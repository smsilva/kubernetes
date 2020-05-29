# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token f2a6s5.j5t5bgjfwqh8orps \
  --discovery-token-ca-cert-hash sha256:a2387ed5fa157093f99fc4cf3eabd8104de2ce99fff1c624dffb3f149901d4b2 \
  --v 1
