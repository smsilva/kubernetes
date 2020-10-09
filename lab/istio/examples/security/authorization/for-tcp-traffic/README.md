# Authorization for TCP traffic

Reference [here](https://istio.io/latest/docs/tasks/security/authorization/authz-tcp/).

## Setup

Run the ```setup.sh``` script:

```bash
cd kubernetes/lab/istio/examples/security/authorization/for-tcp-traffic

../../../setup.sh
```

## Deploy

```bash
kubectl create ns foo

kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/tcp-echo/tcp-echo.yaml) -n foo

kubectl apply -f <(istioctl kube-inject -f ${ISTIO_BASE_DIR}/samples/sleep/sleep.yaml) -n foo

for DEPLOYMENT_NAME in $(kubectl -n foo get deploy -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n foo \
    wait \
      --timeout=3600s \
      --for condition=Available \
      deployment ${DEPLOYMENT_NAME}
done
```

Port **9000** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9000" | nc tcp-echo 9000' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
hello port 9000
connection succeeded
```

Port **9001** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9001" | nc tcp-echo 9001' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
hello port 9001
connection succeeded
```

Port **9002** test (this port is not present on the Service)

```bash
TCP_ECHO_IP=$(kubectl get pod "$(kubectl get pod -l app=tcp-echo -n foo -o jsonpath={.items..metadata.name})" -n foo -o jsonpath="{.status.podIP}")
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c "echo \"port 9002\" | nc $TCP_ECHO_IP 9002" | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
hello port 9002
connection succeeded
```

## Configure access control for a TCP workload

### 1. Create the tcp-policy authorization policy

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tcp-policy
  namespace: foo
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: ALLOW
  rules:
  - to:
    - operation:
       ports: ["9000", "9001"]
EOF
```

Port **9000** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9000" | nc tcp-echo 9000' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
hello port 9000
connection succeeded
```

Port **9001** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9001" | nc tcp-echo 9001' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
hello port 9001
connection succeeded
```

Port **9002** test (this port is not present on the Service)

```bash
TCP_ECHO_IP=$(kubectl get pod "$(kubectl get pod -l app=tcp-echo -n foo -o jsonpath={.items..metadata.name})" -n foo -o jsonpath="{.status.podIP}")
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c "echo \"port 9002\" | nc $TCP_ECHO_IP 9002" | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
connection rejected
```

### 2. Add an HTTP-only field

Update the policy to add an HTTP-only field named methods for port 9000 using the following command:

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tcp-policy
  namespace: foo
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: ALLOW
  rules:
  - to:
    - operation:
        methods: ["GET"]
        ports: ["9000"]
EOF
```

Port **9000** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9000" | nc tcp-echo 9000' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
connection rejected
```

Port **9001** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9001" | nc tcp-echo 9001' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
connection rejected
```

Port **9002** test (this port is not present on the Service)

```bash
TCP_ECHO_IP=$(kubectl get pod "$(kubectl get pod -l app=tcp-echo -n foo -o jsonpath={.items..metadata.name})" -n foo -o jsonpath="{.status.podIP}")
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c "echo \"port 9002\" | nc $TCP_ECHO_IP 9002" | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
connection rejected
```

### 3. Update the policy to a DENY policy

Update the policy to a DENY policy using the following command:

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tcp-policy
  namespace: foo
spec:
  selector:
    matchLabels:
      app: tcp-echo
  action: DENY
  rules:
  - to:
    - operation:
        methods: ["GET"]
        ports: ["9000"]
EOF
```

Port **9000** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9000" | nc tcp-echo 9000' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
connection rejected
```

Port **9001** test

```bash
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c 'echo "port 9001" | nc tcp-echo 9001' | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
hello port 9001
connection succeeded
```

Port **9002** test (this port is not present on the Service)

```bash
TCP_ECHO_IP=$(kubectl get pod "$(kubectl get pod -l app=tcp-echo -n foo -o jsonpath={.items..metadata.name})" -n foo -o jsonpath="{.status.podIP}")
kubectl exec "$(kubectl get pod -l app=sleep -n foo -o jsonpath={.items..metadata.name})" -c sleep -n foo -- sh -c "echo \"port 9002\" | nc $TCP_ECHO_IP 9002" | grep "hello" && echo 'connection succeeded' || echo 'connection rejected'
```

Expected result:

```bash
hello port 9002
connection succeeded
```

### Clean up

```bash
kubectl delete namespace foo
```

## Examples Index

Click [here](../../../README.md) to go back to Examples Index.
