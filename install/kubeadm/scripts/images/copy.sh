#!/bin/bash

# Optional - Copy and Load Images
# vagrant plugin install vagrant-scp
# https://blog.scottlowe.org/2020/01/25/manually-loading-container-images-with-containerd/

# Create a directory for image files
mkdir images

# Copy files to Masters and/or to Workers
MASTERS=$(vgs | grep running | grep -E "master" | awk '{ print $1 }')
WORKERS=$(vgs | grep running | grep -E "worker" | awk '{ print $1 }')
IMAGES_DIRECTORY="/home/silvios/ssd-1/containers/images"
IMAGES_FOR_ALL="kube-proxy|pause|weave"
IMAGES_FOR_WORKERS="${IMAGES_FOR_ALL}|nginx|yauritux|(jcmoraisjr.*).*(haproxy-ingress)"
IMAGES_FOR_MASTERS="kube-apiserver|kube-controller-manager|kube-scheduler|etcd|coredns|${IMAGES_FOR_ALL}"
IMAGE_FILES=$(ls ${IMAGES_DIRECTORY}/*.tar)

for FILE in ${IMAGE_FILES}; do
  FILE_NAME="${FILE##*/}"
  echo "[${FILE_NAME}]"
  if grep -q -E "${IMAGES_FOR_MASTERS}" <<< "${FILE_NAME}"; then
    for SERVER in ${MASTERS}; do
      echo "  ${SERVER}..."
      vagrant scp ${FILE} ${SERVER}:~/images/ &> /dev/null
    done
  fi

  if grep -q -E "${IMAGES_FOR_WORKERS}" <<< "${FILE_NAME}"; then
    for SERVER in ${WORKERS}; do
      echo "  ${SERVER}..."
      vagrant scp ${FILE} ${SERVER}:~/images/ &> /dev/null
    done
  fi
  echo ""
done

# Import Images
ls | while read line; do
  FILE=${line}
  BASE_NAME=$(awk -F "#" '{ print $1 }' <<< ${FILE##*_})
  echo "${FILE} --> ${BASE_NAME}"
  sudo ctr -n=k8s.io images import --base-name "${BASE_NAME}" "${FILE}"
done

# Preloading Container Images
if hostname -s | grep "master" &> /dev/null; then
  sudo kubeadm config images pull --v 3
else
  sudo crictl pull "k8s.gcr.io/kube-proxy:v${KUBERNETES_BASE_VERSION}"
fi

sudo ctr -n=k8s.io images ls
