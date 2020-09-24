#!/bin/bash
grep -E "^export ISTIO_VERSION" ~/.bashrc

sed -i '/^export ISTIO_VERSION/ s/1.7.1/1.7.2/' ~/.bashrc

source ${HOME}/.bashrc && \
echo "ISTIO_VERSION..: ${ISTIO_VERSION}" && \
echo "ISTIO_BASE_DIR.: ${ISTIO_BASE_DIR}"

# Generate a Public IP - as we use minikube, use minikube tunnel on another terminal
minikube tunnel

# Example
cd "kubernetes/lab/istio"

eval $(minikube -p minikube docker-env)

docker build -t demo-health:1.0 demo/docker/

kubectl create namespace dev

kubectl label namespace dev istio-injection=enabled

kubectl get namespaces -L istio-injection

watch 'kubectl -n dev get deploy,pods,svc,gw,vs -L istio.io/rev'

ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP=$(kubectl -n istio-system get service -l istio=ingressgateway -o jsonpath='{.items[].status.loadBalancer.ingress[0].ip}')

echo ${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP}

sudo sed -i '/services.example.com/d' /etc/hosts
sudo sed -i '/ntest.example.com/d' /etc/hosts
sudo sed -i '/httpbin.example.com/d' /etc/hosts

sudo sed -i "1i${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP} services.example.com" /etc/hosts
sudo sed -i "2i${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP} ntest.example.com" /etc/hosts
sudo sed -i "3i${ISTIO_INGRESS_GATEWAY_LOADBALANCER_IP} httpbin.example.com" /etc/hosts

kubectl -n dev apply -f demo/
kubectl -n dev apply -f ntest/

while true; do
curl -is services.example.com
curl -is services.example.com
curl -is services.example.com
curl -is services.example.com/health
curl -is services.example.com/info
curl -is ntest.example.com
curl -is services.example.com/wrong
sleep 2
done

# Configuring X-Forwarded-For Headers
#  https://istio.io/latest/docs/ops/configuration/traffic-management/network-topologies/#configuring-x-forwarded-for-headers
curl -H 'X-Forwarded-For: 56.5.6.7, 72.9.5.6, 98.1.2.3' http://httpbin.example.com/get?show_env=true

# Authentication Policy
# - Auto mutual TLS
# - Globally enabling Istio mutual TLS in STRICT mode
# - Enable mutual TLS per namespace or workload
# - End-user authentication
#  https://istio.io/latest/docs/tasks/security/authentication/authn-policy/

# Globally enabling Istio mutual TLS in STRICT mode
#   https://istio.io/latest/docs/tasks/security/authentication/authn-policy/#globally-enabling-istio-mutual-tls-in-strict-mode
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
EOF
