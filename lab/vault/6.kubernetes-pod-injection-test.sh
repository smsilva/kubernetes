kubectl --namespace default apply deploy/annotations/

kubectl logs app -c vault-agent-init

kubectl exec app -c app -- cat /vault/secrets/credentials.yaml
