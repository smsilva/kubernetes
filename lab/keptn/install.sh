#!/bin/bash

curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v4.4.4 bash

k3d cluster create mykeptn -p "8082:80@agent[0]" --k3s-server-arg '--no-deploy=traefik' --agents 3

curl -sL https://get.keptn.sh | bash

keptn install

kubectl -n keptn port-forward service/api-gateway-nginx 8080:80

keptn auth --endpoint=http://localhost:8080/api --api-token=$(kubectl get secret keptn-api-token -n keptn -ojsonpath={.data.keptn-api-token} | base64 --decode)

curl -SL https://raw.githubusercontent.com/keptn/keptn.github.io/master/content/docs/quickstart/exposeKeptnConfigureIstio.sh | bash

curl -SL https://raw.githubusercontent.com/keptn/keptn.github.io/master/content/docs/quickstart/get-demo.sh | bash

k3d cluster stop mykeptn

k3d cluster start mykeptn

k3d cluster delete mykeptn
