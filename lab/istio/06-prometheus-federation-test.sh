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
