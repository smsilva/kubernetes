#!/bin/bash

# Deploy NodeJS App to Receive New Orders POST and then Store it into statestore
kubectl apply --filename ~/dapr/quickstarts/hello-kubernetes/deploy/node.yaml

# Deploy Python App to POST New Orders to Dapr nodeapp using neworder method
kubectl apply --filename ~/dapr/quickstarts/hello-kubernetes/deploy/python.yaml

kubectl wait deployment nodeapp \
  --for condition=Available \
  --timeout 3600s

kubectl port-forward service/nodeapp 8080:80

curl --silent localhost:8080/ports

kubectl wait deployment pythonapp \
  --for condition=Available \
  --timeout 3600s

kubectl logs \
  --selector app=node \
  --container node \
  --tail=-1

curl --silent localhost:8080/order
