#!/bin/bash

# Retrieve the latest Istio Version
export ISTIO_VERSION=$(curl -sL https://github.com/istio/istio/releases \
| grep -o 'releases/[0-9]*.[0-9]*.[0-9]*/' \
| sort --version-sort \
| tail -1 \
| awk -F'/' '{ print $2}')

export ISTIO_BASE_DIR="${HOME}/istio-${ISTIO_VERSION}"

# Download Istio Release
if ! [ -e ${ISTIO_BASE_DIR} ]; then
  curl -L https://istio.io/downloadIstio | sh -

  mv istio-${ISTIO_VERSION} ${HOME}/
fi

# Check if istioctl is installed
if ! which istioctl > /dev/null; then
  echo "create a symbolic link from ${ISTIO_BASE_DIR}/bin/istioctl for /usr/local/bin/istioctl (you should have a sudo permission)"
  sudo ln --symbolic ${ISTIO_BASE_DIR}/bin/istioctl /usr/local/bin/istioctl
else
  ISTIOCTL_INSTALLED_VERSION=$(istioctl version --remote=false)
  echo "istioctl ${ISTIOCTL_INSTALLED_VERSION} version currently installed"
fi

sed -i '/export ISTIO_VERSION/d' ${HOME}/.bash_config
sed -i '/export ISTIO_BASE_DIR/d' ${HOME}/.bash_config

echo "export ISTIO_VERSION=${ISTIO_VERSION}" >> ${HOME}/.bash_config
echo "export ISTIO_BASE_DIR=\${HOME}/istio-\${ISTIO_VERSION}" >> ${HOME}/.bash_config
