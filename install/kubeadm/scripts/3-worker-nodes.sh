# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token l0xasw.hnc4j8mvm243yn9z \
  --discovery-token-ca-cert-hash sha256:2c8a48062590399dbd4f0412da3d44dc9b783bbe72b9e238508e9adb1e7a2c56 \
  --v 1
