#!/bin/bash
source ${HOME}/.bashrc && \
echo "ISTIO_VERSION..: ${ISTIO_VERSION}" && \
echo "ISTIO_BASE_DIR.: ${ISTIO_BASE_DIR}"

# Create Istio CRDs
kubectl apply -f "${ISTIO_BASE_DIR}/manifests/charts/istio-operator/crds/"

# Install Istio Operator Components using Helm
helm template "${ISTIO_BASE_DIR}/manifests/charts/istio-operator/" \
  --set hub="docker.io/istio" \
  --set tag="${ISTIO_VERSION}" \
  --set operatorNamespace="istio-operator" \
  --set watchedNamespaces="istio-system" | kubectl apply -f -

# Create istio-system Namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: disabled
  name: istio-system
spec:
  finalizers:
  - kubernetes
EOF

# Create IstioOperator Resource
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-operator
  namespace: istio-system
spec:
  profile: default
  values:
    global:
      proxy:
        autoInject: enabled
        privileged: true
    gateways:
      istio-ingressgateway:
        serviceAnnotations:
          service.beta.kubernetes.io/azure-dns-label-name: silvios-dev
EOF

# Add Ons
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/prometheus.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/grafana.yaml"
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/kiali.yaml"; sleep 1
kubectl apply -f "${ISTIO_BASE_DIR}/samples/addons/kiali.yaml"

# Wait until all Deployments become Available
for DEPLOYMENT_NAME in $(kubectl -n istio-system get deploy -o jsonpath='{range .items[*].metadata}{.name}{"\n"}{end}'); do
  kubectl -n istio-system \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done

for n in {001..100}; do
  STATUS=$(kubectl -n istio-system get iop istio-operator -o jsonpath='{.status.status}')
  echo "[${n}] Istio Operator Status: ${STATUS}"
  if [ "${STATUS}" == "HEALTHY" ]; then
    break
  else
    sleep 10
  fi
done
