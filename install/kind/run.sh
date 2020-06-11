#!/bin/bash
CLUSTER_NAME=$1

if [ -e ${CLUSTER_NAME} ]; then
  echo ""
  echo "try to run:"
  echo ""
  echo "  ./run.sh cluster-name-you-wish"
  echo ""

  exit 1
fi

SECONDS=0

kind create cluster \
  --config kind-example-config.yaml \
  --name ${CLUSTER_NAME}

elapsed ${SECONDS}
