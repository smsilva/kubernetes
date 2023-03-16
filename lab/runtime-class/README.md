# RuntimeClass

```bash
kubectl label node k3d-k3s-default-agent-1 reserved=true
kubectl label node k3d-k3s-default-agent-2 reserved=true

kubectl apply -f runtime-class.yaml
kubectl apply -f deployment.yaml
```
