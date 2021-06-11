#!/bin/bash
KUBERNETES_TARGET_VERSION=$1

./01-install.sh
./02-create-cluster.sh ${KUBERNETES_TARGET_VERSION}
