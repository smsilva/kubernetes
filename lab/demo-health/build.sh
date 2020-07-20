#!/bin/bash
set -e


mvn clean install

PROJECT_VALUES=$(mvn -q \
  -Dexec.executable=echo \
  -Dexec.args='${project.artifactId}:${project.version}' \
  --non-recursive \
  exec:exec)

echo ${PROJECT_VALUES}

APP_NAME=$(awk -F ':' '{ print $1 }' <<< ${PROJECT_VALUES})
APP_VERSION=$(awk -F ':' '{ print $2 }' <<< ${PROJECT_VALUES})

echo "${APP_NAME}"
echo "${APP_VERSION}"

eval $(minikube docker-env)

docker build -t health-check:1.0 scripts/health-check/
docker build -t "${APP_NAME}:${APP_VERSION}" .

ACTUAL_VERSION=$(grep -E "image: demo-health:" deploy/deploy.yaml | awk -F: '{ print $3 }')

sed -i "s/image: ${APP_NAME}:${ACTUAL_VERSION}/image: ${APP_NAME}:${APP_VERSION}/" deploy/deploy.yaml

kubectl config set-context minikube --namespace dev

if !grep -q -E "^dev" <<< $(kubectl get ns); then 
  kubectl create namespace dev
fi

kubectl apply -f deploy/

watch -n 2 kubectl get deploy,pods,svc,ep -o wide

