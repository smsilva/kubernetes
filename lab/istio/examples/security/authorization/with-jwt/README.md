# Authorization with JWT

Reference [here](https://istio.io/latest/docs/tasks/security/authorization/authz-jwt/).

## Setup

Run the ```setup.sh``` script:

```bash
cd kubernetes/lab/istio/examples/security/authorization/with-jwt

../../../setup.sh
```

## Deploy

```bash
kubectl create ns foo

kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/httpbin/httpbin.yaml) -n foo

kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml) -n foo

for DEPLOYMENT_NAME in $(kubectl -n foo get deploy -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n foo \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done
```

Verify that sleep successfully communicates with `httpbin` using this command:

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl http://httpbin.foo:8000/ip -s -o /dev/null -w "%{http_code}\n"
```

Expected result:

```bash
200
```

## Allow requests with valid JWT and list-typed claims

### 1. Creates the jwt-example request authentication policy for the httpbin workload in the foo namespace

```bash
kubectl apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "RequestAuthentication"
metadata:
  name: "jwt-example"
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.7/security/tools/jwt/samples/jwks.json"
EOF
```

Verify that a request with an invalid JWT is denied:

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin.foo:8000/headers" -s -o /dev/null -H "Authorization: Bearer invalidToken" -w "%{http_code}\n"
```

Expected result:

```bash
401
```

Verify that a request without a JWT is allowed because there is no authorization policy:

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin.foo:8000/headers" -s -o /dev/null -w "%{http_code}\n"
```

Expected result:

```bash
200
```

### 2. Creates the require-jwt authorization policy for the `httpbin` workload

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
EOF
```

Get the JWT that sets the iss and sub keys to the same value, testing@secure.istio.io

```bash
TOKEN=$(curl https://raw.githubusercontent.com/istio/istio/release-1.7/security/tools/jwt/samples/demo.jwt -s) && echo "$TOKEN" | cut -d '.' -f2 - | base64 --decode -
```

Expected result:

```json
{"exp":4685989700,"foo":"bar","iat":1532389700,"iss":"testing@secure.istio.io","sub":"testing@secure.istio.io"}
```

Verify that a request with a valid JWT is allowed:

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin.foo:8000/headers" -s -o /dev/null -H "Authorization: Bearer $TOKEN" -w "%{http_code}\n"
```

Expected result:

```bash
200
```

Verify that a request without a JWT is denied:

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin.foo:8000/headers" -s -o /dev/null -w "%{http_code}\n"
```

Expected result:

```bash
403
```

### 3. Updates the require-jwt authorization policy to also require the JWT to have a claim named groups containing the value group1

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
       requestPrincipals: ["testing@secure.istio.io/testing@secure.istio.io"]
    when:
    - key: request.auth.claims[groups]
      values: ["group1"]
EOF
```

Get the JWT that sets the groups claim to a list of strings: group1 and group2:

```bash
TOKEN_GROUP=$(curl https://raw.githubusercontent.com/istio/istio/release-1.7/security/tools/jwt/samples/groups-scope.jwt -s) && echo "$TOKEN_GROUP" | cut -d '.' -f2 - | base64 --decode -
```

Expected result:

```json
{"exp":3537391104,"groups":["group1","group2"],"iat":1537391104,"iss":"testing@secure.istio.io","scope":["scope1","scope2"],"sub":"testing@secure.istio.io"}
```

Verify that a request with the JWT that includes group1 in the groups claim is allowed:

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin.foo:8000/headers" -s -o /dev/null -H "Authorization: Bearer $TOKEN_GROUP" -w "%{http_code}\n"
```

Expected result:

```bash
200
```

Verify that a request with a JWT, which doesn’t have the groups claim is rejected:

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- curl "http://httpbin.foo:8000/headers" -s -o /dev/null -H "Authorization: Bearer $TOKEN" -w "%{http_code}\n"
```

Expected result:

```bash
200
```

## Clean up

```bash
kubectl delete namespace foo
```

## Examples Index

Click [here](../../../README.md) to go back to Examples Index.
