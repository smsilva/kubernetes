#!/bin/bash
source ${HOME}/.bashrc && \
echo "ISTIO_VERSION..: ${ISTIO_VERSION}" && \
echo "ISTIO_BASE_DIR.: ${ISTIO_BASE_DIR}" && \
echo ""

# Wait for Load Balancer IP
for n in {001..100}; do
  ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP=$(kubectl -n istio-system get service -l istio=ingressgateway -o jsonpath='{.items[].status.loadBalancer.ingress[0].ip}')
  if [ -z "${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}" ]; then
    echo "[${n}] Ingress Gateway Load Balancer IP Address not found (try to run minikube tunnel on another Terminal Window)"
    sleep 5
  else
    echo "Ingress Gateway Load Balancer IP Address found: ${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}"
    break
  fi
done

for DOMAIN in {services,httpbin,ntest}.example.com; do
  sudo sed -i "/${DOMAIN}/d" /etc/hosts
  sudo sed -i "1i${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP} ${DOMAIN}" /etc/hosts
done && \
echo "" && \
echo "file /etc/hosts contents:" && \
echo "" && \
grep "${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}" /etc/hosts && \
echo "" && \

sleep 10

# Create a Namespace
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

# Monitor demo namespace
watch 'kubectl -n demo get deploy,pods,svc,gw,vs'
