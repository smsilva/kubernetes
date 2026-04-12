# EKS com ALB + Istio Gateway

## Objetivo

Provisionar um cluster EKS com VPC pública e privada, onde o tráfego de entrada é entregue por um ALB ao Istio IngressGateway, com WAF e IRSA configurados.

## Componentes provisionados

| Componente | Tipo | Descrição |
|---|---|---|
| VPC `10.0.0.0/16` | AWS | Rede isolada com 2 subnets públicas e 2 privadas em AZs distintas |
| Internet Gateway | AWS | Permite tráfego de entrada e saída nas subnets públicas |
| NAT Gateway + EIP | AWS | Permite tráfego de saída das subnets privadas. O EIP (Elastic IP) garante um IP público fixo para o NAT Gateway |
| Route Tables | AWS | Roteamento público (via IGW) e privado (via NAT GW) |
| EKS Cluster | AWS | Control plane gerenciado, versão `1.34`, OIDC provider habilitado para IRSA |
| Managed Node Group | AWS | 2–5 nós `t3.medium` nas subnets privadas, IMDSv2 obrigatório |
| IAM Access Entry | AWS | Permissão `cluster-admin` para o caller IAM via EKS Access API |
| AWS Load Balancer Controller `v3.2.1` | Kubernetes | Operador que provisiona e gerencia o ALB a partir de recursos `Ingress` e `IngressClass` |
| IAM Role (IRSA) | AWS | Role vinculada ao service account do ALB Controller via OIDC |
| ALB | AWS | Load balancer internet-facing, TLS terminado via ACM, redireciona HTTP→HTTPS |
| ACM Certificate | AWS | Certificado Let's Encrypt importado para `*.wasp.silvios.me` |
| Istio (`istio-base`) | Kubernetes | CRDs do Istio |
| Istio (`istiod`) | Kubernetes | Control plane do service mesh (Pilot, Citadel, Galley) |
| Istio IngressGateway | Kubernetes | Gateway de entrada como `ClusterIP`, recebe tráfego do ALB via `target-type: ip` |
| WAF WebACL | AWS | Regras gerenciadas AWS (CRS, KnownBadInputs, IP Reputation) associadas ao ALB |
| httpbin | Kubernetes | App de exemplo para validação do fluxo completo ALB → Istio → app |

> **Nota:** Os Security Groups (cluster, nodes e ALB) são criados automaticamente pelo `eksctl` e pelo ALB Controller — nenhum SG é definido explicitamente nos scripts. Ver [SEC-005](#sec-005-ausência-de-security-groups-dedicados-para-o-alb--baixo) na revisão de segurança.

## Arquitetura

### Fluxo de tráfego

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

### Topologia

```
           sara@customer1.com                        motoko@customer2.com
                    │                                          │
                    └─────────────────────┬────────────────────┘
                                          ▼
                                   wasp.silvios.me
                                          │
                                Global Accelerator
                                          │
                    ┌─────────────────────┴────────────────────┐
                    ▼                                          ▼
         platform-us-east-1-wasp                  platform-eu-central-1-wasp
              (us-east-1)                              (eu-central-1)
                    │                                          │
                    ▼                                          ▼
            discovery-service                          discovery-service
                    │                                          │
                    ▼                                          ▼
       customer1.wasp.silvios.me                 customer2.wasp.silvios.me
                    │                                          │
         ┌──────────┴─────────┐                                │
         ▼                    ▼                                ▼
customer1-us-east-1  customer1-us-west-1             customer2-ap-east-1
```

### Fluxo de autenticação multi-tenant

O design do fluxo de login, incluindo suporte a múltiplos IdPs por tenant (Google SSO, Microsoft, Okta, Auth0, Keycloak), arquitetura de dados no DynamoDB e integração com Cognito e Istio, está documentado em:

- **[Arquitetura de Autenticação Multi-tenant](docs/fluxo-autenticacao-multitenant.md)**
- **[Decisões Técnicas e Trade-offs](docs/decisoes-tecnicas.md)**
- **[Onboarding de Novo Customer](docs/onboarding-novo-customer.md)**

**Ferramentas:** 

- `aws cli`
- `eksctl`
- `helm`

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
cluster_name="wasp-calm-crow-ndx4"
domain="wasp.silvios.me"
cert_arn="" # preencher no passo 06 (após importar o cert no ACM)
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

Para este lab, garanta que:
 - O certificado inclui o domínio APEX `wasp.silvios.me` para:
   - Hostname do Global Accelerator
   - Cognito Custom Domain
 - O certificado inclui a SAN `*.wasp.silvios.me` para cobrir o hostname do ALB que será criado no próximo passo e se 

Como verificar:

```shell
openssl x509 -in ~/certificates/config/live/wasp.silvios.me/cert.pem -text -noout | grep -E 'DNS:wasp.silvios.me|DNS:\*\.wasp\.silvios\.me'
```

### 07. Configurar ALB via Ingress

```bash
./07-configure-alb-ingress
```

Cria o ALB usando Ingress clássico do Kubernetes:
- `IngressClass` com `controller: ingress.k8s.aws/alb`
- `Ingress` com redirecionamento HTTP→HTTPS, TLS terminado via ACM
- Roteamento de `*.wasp.silvios.me` para o Istio IngressGateway

Ao final, cria automaticamente o registro CNAME wildcard no Azure DNS:
```
*.wasp.silvios.me → <alb-hostname>.us-east-1.elb.amazonaws.com
```

> **Nota:** o apex `wasp.silvios.me` não pode ser CNAME. O registro A do apex é criado no passo 07b com os IPs estáticos do Global Accelerator.

### 07b. Configurar Global Accelerator

```bash
./07b-configure-global-accelerator
```

Provisiona um Global Accelerator com dois IPs anycast estáticos apontando para o ALB e cria os A records do apex no Azure DNS:

```
wasp.silvios.me → <ip1>, <ip2>  (IPs fixos do Global Accelerator)
```

O nome do accelerator usa `instance_name` (não `cluster_name`) pois é um recurso global — pode sobreviver a trocas de cluster e servir múltiplas regiões no futuro.

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

> **Atenção:** o certificado ACM não é removido pelo script — deletar manualmente via console ou `aws acm delete-certificate --certificate-arn <arn>`.

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
├── 07-configure-alb-ingress   # Ingress clássico (IngressClass + Ingress → ALB) + CNAME wildcard Azure DNS
├── 07b-configure-global-accelerator  # Global Accelerator → ALB + A records apex Azure DNS
├── 08-deploy-sample-app       # httpbin + Istio Gateway + VirtualService
├── 09-configure-waf           # WAF WebACL + associação ao ALB
└── destroy                    # deleção na ordem inversa
```

## Decisões técnicas e backlog

Ver [docs/decisoes-tecnicas.md](docs/decisoes-tecnicas.md) para o registro completo de decisões de design, trade-offs e itens adiados conscientemente.

---

## Revisão de segurança

Análise dos scripts do lab com foco em riscos reais para uso em produção ou como base para outros ambientes.

| ID | Severidade | Script | Problema |
|---|---|---|---|
| [SEC-002](docs/security-issues/sec-002.md) | Médio | `04-install-alb-controller` | IAM policy baixada do GitHub sem verificação de hash — risco de supply chain |
| [SEC-003](docs/security-issues/sec-003.md) | Baixo | `08-deploy-sample-app` | Imagem `kennethreitz/httpbin` sem tag/digest fixo — `latest` implícito |
| [SEC-004](docs/security-issues/sec-004.md) | Médio | `03-configure-access` | `AmazonEKSClusterAdminPolicy` com escopo de cluster inteiro — cluster-admin irrestrito |
| [SEC-005](docs/security-issues/sec-005.md) | Baixo | `07-configure-alb-ingress` | Security Groups do ALB criados automaticamente — sem restrição de IP de origem |
| [SEC-006](docs/security-issues/sec-006.md) | Médio | `02-create-cluster` | IMDSv1 habilitado por padrão — credenciais do node acessíveis via SSRF ou pod comprometido |
| [SEC-007](docs/security-issues/sec-007.md) | Baixo | `09-configure-waf` | WAF sem rate limiting — sem proteção contra força bruta ou flood |
