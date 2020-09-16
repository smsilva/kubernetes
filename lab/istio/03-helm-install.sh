#!/bin/bash

# Check if Helm is installed
if ! which helm > /dev/null; then
  echo "install"
  VERSION="3.3.1"
  TAR_FILE_NAME="helm-v${VERSION}-linux-amd64.tar.gz"
  wget https://get.helm.sh/${TAR_FILE_NAME}
  tar -zxvf ${TAR_FILE_NAME}
  sudo mv linux-amd64/helm /usr/local/bin/helm
  rm -rf linux-amd64
  rm -rf ${TAR_FILE_NAME}
else
  HELM_INSTALLED_VERSION=$(helm version --short)
  echo "istioctl ${HELM_INSTALLED_VERSION} version currently installed"
fi
