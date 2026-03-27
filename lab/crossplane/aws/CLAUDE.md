# Crossplane AWS EKS Lab

Este lab provisiona um cluster EKS na AWS usando Crossplane como camada de IaC, gerenciando recursos AWS diretamente via CRDs no Kubernetes local (k3d).

## Arquitetura

```
k3d cluster (local)
└── Crossplane (crossplane-system)
    ├── provider-family-aws v2.5.1   → autenticação base
    ├── provider-aws-vpc v2.5.1      → VPC, Subnets, IGW, NATGateway, Routes
    ├── provider-aws-ec2 v2.5.1      → EIP
    ├── provider-aws-iam v2.5.1      → Roles, RolePolicyAttachments
    ├── provider-aws-eks v2.5.1      → Cluster, NodeGroup, AccessEntry, ClusterAuth
    └── provider-kubernetes v0.15.0  → Objects (recursos dentro do EKS)
```

**Rede (us-east-1):**
- VPC `172.16.0.0/16`
- Subnets públicas: `172.16.1.0/24` (1a), `172.16.2.0/24` (1b) — tag `kubernetes.io/role/elb`
- Subnets privadas: `172.16.3.0/24` (1a), `172.16.4.0/24` (1b) — tag `kubernetes.io/role/internal-elb`
- Internet Gateway → route table pública
- NAT Gateway (subnet pública 1a) + EIP → route table privada

**Cluster EKS:**
- Nome: `eks-cluster`, versão `1.32`
- `authenticationMode: API_AND_CONFIG_MAP`
- Endpoint público e privado habilitados
- Node group: 2x `t3.medium` nas subnets **privadas** (min 1, max 3)

## Pré-requisitos

- `k3d`, `kubectl`, `helm` e `aws` CLI instalados
- `AWS_ACCESS_KEY` e `AWS_SECRET_KEY` exportados
- Sessão AWS CLI válida (`aws sts get-caller-identity` deve retornar sem erro)

## Ordem de execução

### 1. Instalar Crossplane
```bash
lab/crossplane/install
```
Cria cluster k3d com 3 servidores e instala Crossplane v2.2.0 via Helm.

### 2. Criar Secret com credenciais AWS
```bash
lab/crossplane/aws/create-secret
```
Cria o Secret `aws-secret` no namespace `crossplane-system` com as credenciais AWS.

### 3. Instalar providers e ProviderConfig
```bash
lab/crossplane/aws/eks/create-providers
```
Instala os 5 providers AWS (todos v2.5.1) e cria o `ProviderConfig` `default` apontando para o `aws-secret`.

### 4. Provisionar VPC e subnets
```bash
lab/crossplane/aws/eks/configure-network
```
Cria a VPC e 4 subnets com as tags necessárias para o EKS reconhecer subnets públicas e privadas.

### 5. Provisionar acesso à rede
```bash
lab/crossplane/aws/eks/configure-network-access
```
Cria Internet Gateway, EIP, NAT Gateway, route tables e associações.

> O NAT Gateway leva alguns minutos para ficar `Ready` (timeout: 300s).

### 6. Criar roles IAM
```bash
lab/crossplane/aws/eks/create-iam
```
- `eks-cluster-role` (trust: `eks.amazonaws.com`) + `AmazonEKSClusterPolicy`
- `eks-node-role` (trust: `ec2.amazonaws.com`) + `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKS_CNI_Policy`

### 7. Criar o cluster EKS
```bash
lab/crossplane/aws/eks/create-cluster
```
Leva 10-15 minutos. Timeout configurado em 900s.

### 8. Criar o node group
```bash
lab/crossplane/aws/eks/create-nodegroup
```
Leva alguns minutos. Timeout configurado em 600s.

### 9. Configurar acesso ao cluster
```bash
lab/crossplane/aws/eks/configure-access
```
Obtém o ARN do usuário atual via `aws sts get-caller-identity`, cria `AccessEntry` + `AmazonEKSClusterAdminPolicy` e executa `aws eks update-kubeconfig`.

> Para usar um grupo IAM: crie uma Role com `sts:AssumeRole` para o grupo, e use o ARN dessa role no `AccessEntry` em vez do usuário direto.

### 10. Configurar provider-kubernetes e criar recursos no EKS
```bash
lab/crossplane/aws/eks/configure-kubernetes-provider
```
- Instala o `provider-kubernetes` v0.15.0
- Cria `ClusterAuth` com `refreshPeriod: 9m` (renova token antes dos 10m máximos do EKS)
- Cria `ProviderConfig` `eks-cluster` apontando para o Secret gerado pelo `ClusterAuth`
- Cria o namespace `delta` no EKS via `Object`

## Destruir todos os recursos
```bash
lab/crossplane/aws/eks/destroy
```
Remove todos os recursos na ordem inversa de criação, respeitando dependências. Aguarda a confirmação de deleção em cada etapa antes de prosseguir.

## Comandos úteis

```bash
# Todos os managed resources e seus status
kubectl get managed

# Status dos providers
kubectl get providers

# Inspecionar erro em um recurso específico
kubectl describe <kind>.<group>/<name>

# Alternar contexto entre k3d e EKS
kubectl config use-context k3d-k3s-default
kubectl config use-context arn:aws:eks:us-east-1:<account-id>:cluster/eks-cluster
```

## Pegadinhas conhecidas

| Problema | Causa | Solução |
|---|---|---|
| `no matches for kind "NatGateway"` | Kind incorreto | Usar `NATGateway` (maiúsculas) |
| `unknown field "resourcesVpcConfig"` | Campo errado no Cluster | Usar `vpcConfig` (objeto, não lista) |
| `unknown field "assumeRolePolicyDocument"` | Campo errado na Role IAM | Usar `assumeRolePolicy` |
| `unknown field "scalingConfig[0]"` | scalingConfig é objeto, não lista | Remover o `-` e alinhar como objeto |
| `unknown field "accessScope[0]"` | accessScope é objeto, não lista | Remover o `-` e alinhar como objeto |
| `kubectl wait` aponta para o EKS | Contexto trocado após `update-kubeconfig` | Voltar para `k3d-k3s-default` antes de operar o Crossplane |
| Token do ClusterAuth expira | Token EKS dura 15min | `refreshPeriod: 9m` garante renovação antes do vencimento |
