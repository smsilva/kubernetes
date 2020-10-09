# Request Timeouts

Reference [here](https://istio.io/latest/docs/tasks/traffic-management/request-timeouts/).

## Setup

Run the ```setup.sh``` script:

```bash
../../setup.sh
```

## Deploy

### Bookinfo Application

```bash
kubectl label namespace default istio-injection=enabled

kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/bookinfo/platform/kube/bookinfo.yaml

for DEPLOYMENT_NAME in $(kubectl -n default get deploy -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n default \
    wait --for condition=Available deployment ${DEPLOYMENT_NAME} --timeout=3600s
done
```

### Bookinfo Application Gateway, VirtualServices and Destination Rules

```bash
kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/bookinfo/networking/destination-rule-all.yaml
```

### Check if Bookinfo Application is running

```bash
  kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -s productpage:9080/productpage | grep -o "<title>.*</title>"
```

### Bookinfo Application Product Page

http://demo.example.com/productpage

### Configure All Virtual Services to route to only v1

```bash
kubectl -n default apply -f ${ISTIO_BASE_DIR}/samples/bookinfo/networking/virtual-service-all-v1.yaml
```

## Creating Request Timeout

#### 1. Route requests to v2 of the reviews service, i.e., a version that calls the ratings service:

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
EOF
```

#### 2. Add a 2 second delay to calls to the ratings service:

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percent: 100
        fixedDelay: 2s
    route:
    - destination:
        host: ratings
        subset: v1
EOF
```

#### 3. Request Timeout

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
    timeout: 0.5s
EOF
```

### Clean up Bookinfo Application

```bash
${ISTIO_BASE_DIR}/samples/bookinfo/platform/kube/cleanup.sh
```

## Examples Index

Click [here](../../README.md) to go back to Examples Index.
