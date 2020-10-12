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

# Create demo Namespace
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: demo
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
  components:
    ingressGateways:
    - name: istio-ingressgateway
      namespace: istio-system
      enabled: true
    - name: istio-ingressgateway-demo
      namespace: demo
      enabled: false
      k8s:
        service:
          type: ClusterIP
          ports:
          - name: status-port
            port: 15021
          - name: http2
            port: 80
            targetPort: 8080
          - name: https
            port: 443
            targetPort: 8443
          - name: tls
            port: 15443
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

wait-for-operator.sh

echo "run `minikube tunnel` in another terminal and then run: examples/setup.sh"
