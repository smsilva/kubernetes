# Crossplane AWS EKS Lab

Este lab provisiona um cluster EKS na AWS usando Crossplane como camada de IaC, gerenciando recursos AWS diretamente via CRDs no Kubernetes.

## Visão geral da arquitetura

```
k3d cluster (local)
└── Crossplane (crossplane-system)
    ├── provider-family-aws      → autenticação base
    ├── provider-aws-vpc         → VPC, Subnets, IGW, NAT, Routes
    ├── provider-aws-ec2         → EIP, NATGateway, SecurityGroup
    ├── provider-aws-iam         → Roles, PolicyAttachments
    └── provider-aws-eks         → Cluster, NodeGroup, AccessEntry
```

**Rede provisionada:**
- VPC `172.16.0.0/16` em `us-east-1`
- 2 subnets públicas: `172.16.1.0/24` (1a), `172.16.2.0/24` (1b)
- 2 subnets privadas: `172.16.3.0/24` (1a), `172.16.4.0/24` (1b)
- Internet Gateway + NAT Gateway (na subnet pública 1a) + Elastic IP
- Route tables pública (→ IGW) e privada (→ NAT)

**Cluster EKS:**
- Nome: `eks-cluster`, versão `1.32`, região `us-east-1`
- `authenticationMode: API_AND_CONFIG_MAP`
- Node group com 2x `t3.medium` nas subnets **privadas**

## Pré-requisitos

- k3d, kubectl, helm e aws CLI instalados
- Variáveis de ambiente `AWS_ACCESS_KEY` e `AWS_SECRET_KEY` exportadas

## Ordem de execução

### 1. Instalar Crossplane no cluster local
```bash
lab/crossplane/install
```
Cria cluster k3d com 3 servidores e instala Crossplane v2.2.0 via Helm.

### 2. Criar Secret com credenciais AWS
```bash
lab/crossplane/aws/create-secret
```
Requer `AWS_ACCESS_KEY` e `AWS_SECRET_KEY` exportados. Cria o Secret `aws-secret` no namespace `crossplane-system`.

### 3. Instalar providers e ProviderConfig
```bash
lab/crossplane/aws/eks/create-providers
```
Instala os providers `family-aws`, `vpc`, `ec2`, `iam` e `eks` (todos v2.5.1) e cria o `ProviderConfig` apontando para o `aws-secret`.

### 4. Provisionar a rede (VPC, subnets)
```bash
lab/crossplane/aws/eks/configure-network
```
Cria VPC e 4 subnets (2 públicas + 2 privadas).

### 5. Provisionar acesso à rede (IGW, NAT, routes)
```bash
lab/crossplane/aws/eks/configure-network-access
```
Cria Internet Gateway, Elastic IP, NAT Gateway, route tables e associações de subnets.

> **Atenção:** O NAT Gateway leva alguns minutos para ficar `Ready`. O script aguarda até 300s.

### 6. Criar roles IAM
```bash
lab/crossplane/aws/eks/create-iam
```
Cria `eks-cluster-role` (para o plano de controle) e `eks-node-role` (para os nodes), com as políticas obrigatórias:
- Cluster: `AmazonEKSClusterPolicy`
- Nodes: `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKS_CNI_Policy`

### 7. Criar o cluster EKS
```bash
lab/crossplane/aws/eks/create-cluster
```
O cluster leva em torno de 10-15 minutos para ficar `Ready`. O script aguarda até 600s.

### 8. Criar o node group
```bash
lab/crossplane/aws/eks/create-nodegroup
```
Cria node group com `desiredSize: 2`, `minSize: 1`, `maxSize: 3` usando `t3.medium`. Leva alguns minutos. O script aguarda até 600s.

### 9. Configurar acesso e kubeconfig
```bash
lab/crossplane/aws/eks/configure-access
```
Usa `aws sts get-caller-identity` para obter o ARN do usuário atual, cria um `AccessEntry` e associa a policy `AmazonEKSClusterAdminPolicy`. Por fim, executa `aws eks update-kubeconfig` para configurar o acesso local.

## Comandos úteis para acompanhar o progresso

```bash
# Todos os recursos gerenciados e seus status
kubectl get managed

# Status dos providers
kubectl get providers

# Eventos de um recurso específico (útil para debugar erros)
kubectl describe <kind>.<group>/<name>
```

## Observações importantes

- O `kind` correto para o NAT Gateway é `NATGateway` (maiúsculas), não `NatGateway`.
- O `Cluster` e o `NodeGroup` usam `apiVersion: eks.aws.upbound.io/v1beta2` (não v1beta1).
- Os nodes ficam nas subnets **privadas** — acesso via NAT Gateway, não diretamente pela internet.
- O `configure-access` depende que a sessão AWS CLI esteja autenticada (`aws sts get-caller-identity` deve funcionar).


## Atualização deste arquivo

Este arquivo deve ser atualizado se houverem mudanças significativas no processo de provisionamento, na arquitetura ou nos comandos usados.
