#!/bin/bash
source ${HOME}/.bashrc && \
echo "ISTIO_VERSION..: ${ISTIO_VERSION}" && \
echo "ISTIO_BASE_DIR.: ${ISTIO_BASE_DIR}"

# Add Ons
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/kiali.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/prometheus.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/grafana.yaml"

# Access Dashboards
istioctl dashboard --help | grep "Available Commands:" -B 1 -A 8

# Prometheus Federation
cd ${HOME}/git/kubernetes/lab/istio/prometheus

ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP=$(kubectl -n istio-system get service -l istio=ingressgateway -o jsonpath='{.items[].status.loadBalancer.ingress[0].ip}')
ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP_OLD=$(grep -oP "targets.*\[\K[^\]]+" $PWD/config/prometheus.yml | tr -d "'")

echo "ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP_OLD.: ${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP_OLD}" && \
echo "ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP.....: ${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}"

sed -i "/targets.*/  s/${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP_OLD}/${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}/" $PWD/config/prometheus.yml

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
