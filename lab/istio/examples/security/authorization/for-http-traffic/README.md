# Authorization for HTTP traffic

Reference [here](https://istio.io/latest/docs/tasks/security/authorization/authz-http/).

## Setup

Run the ```setup.sh``` script:

```bash
cd kubernetes/lab/istio/examples/security/authorization/for-http-traffic

../../../setup.sh && \
../../../bookinfo-application-deploy.sh
```

## Bookinfo Application Product Page

Access the Bookinfo Web Site

http://bookinfo.local/productpage

## Tests

```bash
curl -Is http://bookinfo.local/productpage
```

Expected result: 

```bash
HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
content-length: 4183
server: istio-envoy
date: Fri, 09 Oct 2020 14:39:56 GMT
x-envoy-upstream-service-time: 20
```

### 1. Create a deny-all policy

Run the following command to create a deny-all policy in the default namespace:

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  {}
EOF
```

Test again

```bash
curl -Is http://bookinfo.local/productpage
```

Expected result: 

```bash
HTTP/1.1 403 Forbidden
content-length: 19
content-type: text/plain
date: Fri, 09 Oct 2020 14:40:38 GMT
server: istio-envoy
x-envoy-upstream-service-time: 41
```

Access the Bookinfo Web Site

http://bookinfo.local/productpage

## 2. Create a productpage-viewer policy

Allow access with GET method to the productpage workload:

```bash
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "productpage-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - to:
    - operation:
        methods: ["GET"]
EOF
```

Access the Bookinfo Web Site

http://bookinfo.local/productpage

## 3. Create a details-viewer policy

Allow the productpage workload, which issues requests using the `cluster.local/ns/default/sa/bookinfo-productpage` service account, to access the details workload through `GET` methods:

```bash
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "details-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: details
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
    to:
    - operation:
        methods: ["GET"]
EOF
```

## 4. Create a reviews-viewer policy

Allow the productpage workload, which issues requests using the `cluster.local/ns/default/sa/bookinfo-productpage` service account, to access the reviews workload through `GET` methods:

```bash
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "reviews-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-productpage"]
    to:
    - operation:
        methods: ["GET"]
EOF
```
## 5. Create the ratings-viewer policy

Allow the reviews workload, which issues requests using the `cluster.local/ns/default/sa/bookinfo-reviews` service account, to access the ratings workload through `GET` methods:

```bash
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "ratings-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: ratings
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/bookinfo-reviews"]
    to:
    - operation:
        methods: ["GET"]
EOF
```

### Clean up Bookinfo Application

```bash
kubectl delete authorizationpolicy.security.istio.io/deny-all
kubectl delete authorizationpolicy.security.istio.io/productpage-viewer
kubectl delete authorizationpolicy.security.istio.io/details-viewer
kubectl delete authorizationpolicy.security.istio.io/reviews-viewer
kubectl delete authorizationpolicy.security.istio.io/ratings-viewer

${ISTIO_BASE_DIR}/samples/bookinfo/platform/kube/cleanup.sh
```

## Examples Index

Click [here](../../../README.md) to go back to Examples Index.
