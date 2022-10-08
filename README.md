# Instalação

## Diferentes maneiras de Instalar o Kubernetes

- [Azure Kubernetes Service (AKS)](install/aks/create-cluster.sh): Cluster na Azure com RBAC e Auto Scaling ativado.
- [Kind](install/kind/): Exemplo criando cluster Kind com 3 Nodes e NGINX Ingress Controller.
- [Kubeadm](install/kubeadm/): Usando Máquinas Virtuais Vagrant ou Multipass.
- [Minikube](install/minikube/): Instala e cria um cluster usando Minikube.

# Lab

Experimentos com tópicos diversos


- [AKS + App Gateway Ingress Controller](lab/azure/app-gateway-ingress-controller) - Tráfego de entrada em um Cluster AKS usando o Azure Application Gateway.
- [Argo Rollouts](lab/argo/argorollouts) - Progressive Delivery.
- [ArgoCD](lab/argo/argocd) - Continuos Deployment.
- [Azure AKS](lab/azure/aks-node-pool-migration) - Atualização de Node Pool.
- [Azure Container Registry (ACR)](lab/azure/azure-container-registry) - Criação de um Azure Container Registry.
- [cert-manager](lab/cert-manager) - Usando cert-manager com um Cluster AKS e Istio gerando Certificados Let's Encrypt válidos.
- [Crossplane](lab/crossplane/terraform-provider) - Usando Crossplane para referenciar Módulos Terraform.
- [ETCD](lab/backup/etcd.sh) - Backup ETCD.
- [Hashicorp Vault](lab/vault) - Exemplo usando Vault em um Cluster Kubernetes com Storage RAFT.
- [Ingress](lab/ingress) - NGINX Ingress Controller em um Cluster Kind.
- [Istio](lab/istio/examples/README.md) - Service Mesh.
- [Kasten](lab/kasten) - Backups com Kasten.
- [Kyverno](lab/kyverno) - Exemplo aplicando políticas em um Cluster usando Kyverno.
- [Open Policy Agent (Gatekeeper)](lab/gatekeeper) - Exemplo aplicando políticas em um Cluster usando OPA.
- [POD Disruption Budget](lab/pod-disruption-budget) - Impedindo que PODs sejam terminadas de uma só vez quando um Node está sendo drenado.
- [Telepresence](lab/telepresence) - Exemplo de uso do Telepresence.
- [Velero](lab/velero) - Backup de Objetos Kubernetes usando Azure Storage.
- [Ingress](lab/ingress) - NGINX Ingress Controller em um Cluster Kind.
