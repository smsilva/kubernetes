# Highly Available Vault Cluster with Integrated Storage (Raft)
# https://www.vaultproject.io/docs/platform/k8s/helm/examples/ha-with-raft

helm repo add hashicorp https://helm.releases.hashicorp.com

helm search repo hashicorp/vault -l

helm install vault hashicorp/vault \
  --version '0.10.0' \
  --namespace 'vault' \
  --create-namespace \
  --set='server.ha.enabled=true' \
  --set='server.ha.replicas=3' \
  --set='server.ha.raft.enabled=true' \
  --set='ui.enabled=false' \
  --set='ui.serviceType=NodePort'
