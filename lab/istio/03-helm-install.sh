#!/bin/bash

# Check if Helm is installed
if ! which helm > /dev/null; then
  VERSION=$(curl -sL https://github.com/helm/helm/releases | grep -oP 'releases/tag/\K[^\"]+' | sort --version-sort | tail -1)

  TAR_FILE_NAME="helm-${VERSION}-linux-amd64.tar.gz"
  
  wget https://get.helm.sh/${TAR_FILE_NAME}
  
  tar -zxvf ${TAR_FILE_NAME}

  sudo mv linux-amd64/helm /usr/local/bin/helm

  rm -rf linux-amd64
  rm -rf ${TAR_FILE_NAME}
else
  HELM_INSTALLED_VERSION=$(helm version --short)

  echo "istioctl ${HELM_INSTALLED_VERSION} version currently installed"
fi
