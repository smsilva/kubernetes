# Mutual TLS Migration

Reference [here](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/).

## Setup

Run the ```setup.sh``` script:

```bash
../../setup.sh
```

## Deploy

```bash
kubectl create ns foo
kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/httpbin/httpbin.yaml) -n foo
kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml) -n foo
kubectl create ns bar
kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/httpbin/httpbin.yaml) -n bar
kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml) -n bar

kubectl create ns legacy
kubectl apply -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml -n legacy

kubectl exec -nfoo "$(kubectl get pod -nfoo -lapp=httpbin -ojsonpath={.items..metadata.name})" -c istio-proxy -- sudo tcpdump dst port 80  -A

for NAMESPACE_ORIGIN in "foo" "bar" "legacy"; do
  for NAMESPACE_TARGET in "foo" "bar"; do
    POD_NAME=$(kubectl get pod -l app=sleep -n ${NAMESPACE_ORIGIN} -o jsonpath={.items..metadata.name})
    kubectl exec "${POD_NAME}" -c sleep -n ${NAMESPACE_ORIGIN} -- curl http://httpbin.${NAMESPACE_TARGET}:8000/ip -s -o /dev/null -w "sleep.${NAMESPACE_ORIGIN} to httpbin.${NAMESPACE_TARGET}: %{http_code}\n";
  done;
done

kubectl get peerauthentication --all-namespaces

kubectl get destinationrule --all-namespaces

kubectl apply -n istio-system -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF
```

## Clean up

```bash
kubectl delete peerauthentication -n istio-system default

kubectl delete ns foo bar legacy
```

## Examples Index

Click [here](../../README.md) to go back to Examples Index.
