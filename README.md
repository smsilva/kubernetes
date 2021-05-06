# Instalação

## Diferentes maneira de Instalar o Kubernetes

- [Azure Kubernetes Service (AKS)](install/aks/create-cluster.sh): Cluster na Azure com RBAC e Auto Scaling ativado.
- [Kubeadm](install/kubeadm/): Usando Máquinas Virtuais Vagrant ou Multipass.
- [Kind](install/kind/): Exemplo criando cluster Kind com 3 Nodes e NGINX Ingress Controller.
- [Minikube](install/minikube/): Instala e cria um cluster usando Minikube.

# Lab

Experimentos com tópicos diversos

- [Istio](lab/istio/examples/README.md) - Service Mesh.
- [ArgoCD](lab/argo/argocd) - Continuos Deployment.
- [Argo Rollouts](lab/argo/argorollouts) - Progressive Delivery.
- [Azure AKS](lab/azure/aks-node-pool-migration) - Atualização de Node Pool.
- [Azure AKS + App Gateway Ingress Controller](lab/azure/app-gateway-ingress-controller) - Tráfego de entrada em um Cluster AKS usando o Azure Application Gateway.
- [Azure Container Registry (ACR)](lab/azure/azure-container-registry) - Criação de um Azure Container Registry.
- [ETCD](lab/backup/etcd.sh) - Backup ETCD.
- [cert-manager](lab/cert-manager) - Usando cert-manager com um Cluster AKS e Istio gerando Certificados Let's Encrypt válidos.
- [Open Policy Agent (Gatekeeper)](lab/gatekeeper) - Exemplo aplicando políticas em um Cluster usando OPA.

- [Kasten](lab/kasten) - Backups com Kasten.
- [Kyberno](lab/kyverno) - Exemplo aplicando políticas em um Cluster usando Kyverno.
- [POD Disruption Budget](lab/pod-disruption-budget) - Impedindo que PODs sejam terminadas de uma só vez quando um Node está sendo drenado.
- [Telepresence](lab/telepresence) - Exemplo de uso do Telepresence.
- [Hashicorp Vault](lab/vault) - Exemplo usando Vault em um Cluster Kubernetes com Storage RAFT.
- [Velero](lab/velero) - Backup de Objetos Kubernetes usando Azure Storage.
