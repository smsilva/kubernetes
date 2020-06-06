# The parameters below are getting from the first Contol Plane Config
NODE_NAME=$(hostname -s) && \
sudo kubeadm join lb:6443 \
  --node-name "${NODE_NAME}" \
  --token 5cwx97.qhdguv30e2puhl8e \
  --discovery-token-ca-cert-hash sha256:b87f95ddde0c93f2ec2059079e1f73eed16f6f2e1251eb15ea224259ac676d42 \
  --v 3

# Optional - Copy and Load Images
# vagrant plugin install vagrant-scp
# https://blog.scottlowe.org/2020/01/25/manually-loading-container-images-with-containerd/

# Export Images as tar files
docker images | sed '1d' | awk '{ print "docker save " $3 " -o " $1 ":" $2 ".tar" }' | sed 's/\//_/g; s/:/#/g' | sh

# docker load --quiet --input yauritux_busybox-curl#latest.tar | awk -F ':' '{ print $3 }'
# ctr image import

FILES=$(ls /home/silvios/ssd-1/containers/images/*.tar)
SERVERS=$(vgs | grep running | grep -E "master|worker" | awk '{ print $1 }')

for FILE in ${FILES}; do
  for SERVER in ${SERVERS}; do
    echo "Copying ${FILE} to ${SERVER}..."
    vagrant scp ${FILE} ${SERVER}:~/images/ &> /dev/null
  done
done

# Optional 
sudo crictl pull nginx:1.17
sudo crictl pull nginx:1.18
sudo crictl pull yauritux/busybox-curl
