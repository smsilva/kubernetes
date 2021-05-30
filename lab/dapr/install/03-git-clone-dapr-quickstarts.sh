#!/bin/bash

# Hello Kubernetes
# https://github.com/dapr/quickstarts/tree/v1.0.0/hello-kubernetes

LATEST_RELEASE_VERSION=$(curl --silent "https://api.github.com/repos/dapr/dapr/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

git clone -b ${LATEST_RELEASE_VERSION?} https://github.com/dapr/quickstarts.git ~/dapr/quickstarts

cd ~/dapr/quickstarts
