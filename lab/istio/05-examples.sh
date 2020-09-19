#!/bin/bash
source ${HOME}/.bashrc && \
echo "ISTIO_VERSION..: ${ISTIO_VERSION}" && \
echo "ISTIO_BASE_DIR.: ${ISTIO_BASE_DIR}"

# Example
cd "kubernetes/lab/istio"

eval $(minikube -p minikube docker-env)

docker build -t demo-health:1.0 demo/docker/

kubectl create namespace dev

kubectl label namespace dev istio-injection=enabled

kubectl get namespaces -L istio-injection

# Generate a Public IP - as we use minikube, use minikube tunnel on another terminal
minikube tunnel

watch 'kubectl -n dev get deploy,pods,svc,gw,vs'

ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP=$(kubectl -n istio-system get service -l istio=ingressgateway -o jsonpath='{.items[].status.loadBalancer.ingress[0].ip}')

echo ${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}

sudo sed -i '/services.example.com/d' /etc/hosts
sudo sed -i '/ntest.example.com/d' /etc/hosts

sudo sed -i "1i${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP} services.example.com" /etc/hosts
sudo sed -i "2i${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP} ntest.example.com" /etc/hosts

kubectl -n dev apply -f demo/

curl -is services.example.com
curl -is services.example.com/health
curl -is services.example.com/info

# Visualizing Metrics with Grafana
# https://istio.io/latest/docs/tasks/observability/metrics/using-istio-dashboard/

# Add Ons
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/kiali.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/prometheus.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/grafana.yaml"

# Access Dashboards
istioctl dashboard --help | grep "Available Commands:" -B 1 -A 8

# Prometheus Federation
docker run \
  -p 9090:9090 \
  -v $PWD/config/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

http://localhost:9090/targets

docker run \
  -d \
  -p 3001:3000 \
  grafana/grafana

http://localhost:3001
