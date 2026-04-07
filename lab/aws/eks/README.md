# EKS com ALB + Istio Gateway

## Objetivo

Provisionar um cluster EKS com VPC pública e privada, onde o tráfego de entrada é entregue por um ALB ao Istio IngressGateway, com WAF e IRSA configurados.

## Arquitetura

```
Internet
   │
   ▼
AWS ALB  (subnets públicas, HTTPS terminado via ACM)
   │       WAF WebACL: CRS + KnownBadInputs + IP Reputation
   │       Shield Standard: ativo por padrão
   ▼
Istio IngressGateway  (namespace: istio-ingress, ClusterIP)
   │       pods nas subnets privadas, tráfego via target-type ip
   ▼
Aplicações  (namespaces com sidecar injection habilitado)
```

**Ferramentas:** `aws cli` · `eksctl` · `helm`

## Pré-requisitos

- `aws` CLI configurado com permissões suficientes
- `eksctl` instalado
- `helm` instalado
- `kubectl` instalado
- Certificado para `*.wasp.silvios.me` disponível em `~/certificates/config/live/wasp.silvios.me/`

## Configuração

Edite `env.conf` antes de executar os scripts:

```bash
# Variáveis que precisam ser revisadas antes de começar
aws_region="us-east-1"
cluster_name="eks-cluster"
domain="wasp.silvios.me"
cert_arn=""     # preencher no passo 06 (após importar o cert no ACM)
```

## Passo a passo

### 01. Criar VPC

```bash
./01-create-vpc
```

Cria a VPC `10.0.0.0/16` com:
- 2 subnets públicas (`10.0.1.0/24`, `10.0.2.0/24`) em `us-east-1a` e `us-east-1b`
- 2 subnets privadas (`10.0.3.0/24`, `10.0.4.0/24`) em `us-east-1a` e `us-east-1b`
- Internet Gateway, NAT Gateway (com EIP) e route tables

Os IDs dos recursos são salvos em `.vpc-ids` para uso nos passos seguintes.

### 02. Criar cluster EKS

```bash
./02-create-cluster
```

Cria o cluster EKS via `eksctl` usando a VPC do passo anterior:
- Nodes `t3.medium` nas subnets privadas (managed node group)
- OIDC provider habilitado (`withOIDC: true`) — necessário para IRSA

### 03. Configurar acesso

```bash
./03-configure-access
```

Atualiza o `kubeconfig` local e cria um access entry com permissão de admin no cluster para o caller IAM atual.

### 04. Instalar ALB Controller

```bash
./04-install-alb-controller
```

Instala o AWS Load Balancer Controller com IRSA:
1. Baixa a IAM policy oficial do repositório do controller
2. Cria a IAM policy na conta AWS
3. Cria o IAM service account com IRSA via `eksctl` (trust policy no OIDC provider)
4. Instala o controller via Helm

### 05. Instalar Istio

```bash
./05-install-istio
```

Instala o Istio via Helm na ordem correta:
1. `istio-base` — CRDs
2. `istiod` — control plane
3. `istio-ingressgateway` — gateway como `ClusterIP` (sem NLB próprio)

### 06. Importar certificado no ACM

```bash
./06-import-certificate-acm
```

Importa o certificado Let's Encrypt de `~/certificates/config/live/wasp.silvios.me/` no AWS Certificate Manager e atualiza automaticamente o `cert_arn` em `env.conf`.

### 07. Configurar ALB via Gateway API

```bash
./07-configure-alb-ingress
```

Cria o ALB usando a Kubernetes Gateway API:
- `GatewayClass` com `controllerName: eks.amazonaws.com/alb`
- `Gateway` com listeners HTTP/HTTPS, TLS terminado via ACM
- `HTTPRoute` roteando `*.wasp.silvios.me` para o Istio IngressGateway

Ao final, imprime o hostname do ALB para configurar o CNAME no DNS:
```
*.wasp.silvios.me → <alb-hostname>.us-east-1.elb.amazonaws.com
```

### 08. Deploy da app de exemplo

```bash
./08-deploy-sample-app
```

Faz o deploy do `httpbin` para validar o fluxo completo:
- Namespace `sample` com `istio-injection: enabled`
- Istio `Gateway` + `VirtualService` para `httpbin.wasp.silvios.me`

Validação:
```bash
curl https://httpbin.wasp.silvios.me/get
```

### 09. Configurar WAF

```bash
./09-configure-waf
```

Cria uma WebACL com AWS Managed Rules e associa ao ALB:

| Regra | Proteção |
|---|---|
| `AWSManagedRulesCommonRuleSet` | XSS, SQLi e outros vetores comuns |
| `AWSManagedRulesKnownBadInputsRuleSet` | Inputs maliciosos conhecidos |
| `AWSManagedRulesAmazonIpReputationList` | IPs maliciosos e botnets |

**Shield Standard** está ativo por padrão em todos os recursos AWS sem custo adicional.

## Destruir o lab

```bash
./destroy
```

Remove todos os recursos na ordem inversa. O script aguarda cada etapa antes de prosseguir.

## Estrutura de arquivos

```
lab/aws/eks/
├── env.conf                   # variáveis de configuração
├── 01-create-vpc              # VPC, subnets, IGW, NAT GW, route tables
├── 02-create-cluster          # cluster EKS + node group + OIDC
├── 03-configure-access        # kubeconfig + access entry admin
├── 04-install-alb-controller  # AWS LBC com IRSA
├── 05-install-istio           # istio-base, istiod, istio-ingressgateway
├── 06-import-certificate-acm  # importa cert Let's Encrypt no ACM
├── 07-configure-alb-ingress   # Gateway API (GatewayClass, Gateway, HTTPRoute)
├── 08-deploy-sample-app       # httpbin + Istio Gateway + VirtualService
├── 09-configure-waf           # WAF WebACL + associação ao ALB
└── destroy                    # deleção na ordem inversa
```
