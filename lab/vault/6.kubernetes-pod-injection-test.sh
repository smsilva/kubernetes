kubectl apply \
  --namespace default \
  --filename deploy/annotations/ && \
kubectl wait \
  pod app \
  --for condition=Ready \
  --timeout 360s && \
kubectl logs app -c vault-agent-init && \
echo "" && \
kubectl exec app -c app -- cat /vault/secrets/credentials.yaml
