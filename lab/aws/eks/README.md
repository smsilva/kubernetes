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

**[fluxo-autenticacao-multitenant.md](fluxo-autenticacao-multitenant.md)**

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

### 07. Configurar ALB via Ingress

```bash
./07-configure-alb-ingress
```

Cria o ALB usando Ingress clássico do Kubernetes:
- `IngressClass` com `controller: ingress.k8s.aws/alb`
- `Ingress` com redirecionamento HTTP→HTTPS, TLS terminado via ACM
- Roteamento de `*.wasp.silvios.me` para o Istio IngressGateway

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
├── 07-configure-alb-ingress   # Ingress clássico (IngressClass + Ingress → ALB)
├── 08-deploy-sample-app       # httpbin + Istio Gateway + VirtualService
├── 09-configure-waf           # WAF WebACL + associação ao ALB
└── destroy                    # deleção na ordem inversa
```

## Decisões técnicas e backlog

### Gateway API — pendente de validação

O ALB Controller v3.x adicionou suporte à Kubernetes Gateway API (`GatewayClass`, `Gateway`, `HTTPRoute`) a partir da v3.0. Este lab utiliza intencionalmente os recursos clássicos `Ingress` e `IngressClass` por ser mais estável e amplamente validado.

**Por que não usar Gateway API agora:**

A issue [kubernetes-sigs/aws-load-balancer-controller#4674](https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/4674) (aberta em abril de 2026) reporta que o upgrade de `v3.1.0` para `v3.2.1` quebra instalações onde a Gateway API **não está habilitada**, pois os CRDs de `ListenerSet` ficam ausentes. Enquanto esse tipo de problema de compatibilidade não estiver estabilizado, manter `Ingress`/`IngressClass` é a escolha conservadora.

**Quando revisitar:**

- Aguardar resolução da issue #4674 e de outros bugs de compatibilidade na série v3.x
- Avaliar o suporte a `HTTPRoute` → ALB para substituir o `Ingress` atual (`07-configure-alb-ingress`)
- O Istio `Gateway` + `VirtualService` (passo 08) é um recurso do próprio Istio e **não** é afetado por essa limitação do ALB Controller

---

## Revisão de segurança

Análise dos scripts do lab com foco em riscos reais para uso em produção ou como base para outros ambientes.

| ID | Severidade | Arquivo | Problema |
|---|---|---|---|
| [SEC-002](#sec-002-download-de-iam-policy-sem-verificação-de-integridade--médio) | Médio | `04-install-alb-controller` | IAM policy baixada do GitHub sem verificação de hash — risco de supply chain |
| [SEC-003](#sec-003-imagem-de-container-sem-digest-fixo-na-app-de-exemplo--baixo) | Baixo | `08-deploy-sample-app` | Imagem `kennethreitz/httpbin` sem tag/digest fixo — `latest` implícito |
| [SEC-004](#sec-004-permissão-de-admin-concedida-sem-escopo-de-namespace--médio) | Médio | `03-configure-access` | `AmazonEKSClusterAdminPolicy` com escopo de cluster inteiro — cluster-admin irrestrito |
| [SEC-005](#sec-005-ausência-de-security-groups-dedicados-para-o-alb--baixo) | Baixo | `07-configure-alb-ingress` | Security Groups do ALB criados automaticamente — sem restrição de IP de origem |
| [SEC-006](#sec-006-nós-do-cluster-com-imdsv1-habilitado-padrão-do-eksctl--médio) | Médio | `02-create-cluster` | IMDSv1 habilitado por padrão — credenciais do node acessíveis via SSRF ou pod comprometido |
| [SEC-007](#sec-007-waf-sem-rate-limiting--baixo) | Baixo | `09-configure-waf` | WAF sem rate limiting — sem proteção contra força bruta ou flood |

### [SEC-002] Download de IAM policy sem verificação de integridade — Médio

**Arquivo:** `04-install-alb-controller`, linha 19

**Problema:** A IAM policy é baixada diretamente do GitHub com `curl -sL` e aplicada imediatamente na conta AWS, sem verificação de hash ou assinatura:

```bash
curl -sL \
  "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${alb_controller_version}/docs/install/iam_policy.json" \
  -o /tmp/alb-iam-policy.json
```

**Impacto:** Se o conteúdo do arquivo for alterado (comprometimento do repositório upstream, ataque MITM ou uso de versão adulterada), a policy IAM resultante pode conceder permissões excessivas na conta AWS.

**Correção:** Verificar o hash SHA256 do arquivo após o download, comparando com o valor publicado no changelog oficial do release:

```bash
curl -sL "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${alb_controller_version}/docs/install/iam_policy.json" \
  -o /tmp/alb-iam-policy.json

# Verificar hash (obter o valor esperado nas release notes)
echo "<sha256_esperado>  /tmp/alb-iam-policy.json" | sha256sum -c
```

---

### [SEC-003] Imagem de container sem digest fixo na app de exemplo — Baixo

**Arquivo:** `08-deploy-sample-app`, linha 35

**Problema:** A imagem do `httpbin` é referenciada sem digest imutável:

```yaml
image: kennethreitz/httpbin
```

**Impacto:** Em um ambiente real, a tag `latest` implícita pode ser substituída por uma versão diferente entre execuções, quebrando a reprodutibilidade e introduzindo riscos de supply chain.

**Correção:** Fixar a imagem com digest SHA256:

```yaml
image: kennethreitz/httpbin@sha256:<digest>
```

Para um lab, alternativa aceitável é usar uma imagem mantida ativamente, como `docker.io/mccutchen/go-httpbin`.

---

### [SEC-004] Permissão de admin concedida sem escopo de namespace — Médio

**Arquivo:** `03-configure-access`

**Problema:** O caller IAM recebe a policy `AmazonEKSClusterAdminPolicy` com `access-scope type=cluster`, o que equivale a `cluster-admin` no RBAC do Kubernetes — acesso irrestrito a todos os recursos e namespaces:

```bash
aws eks associate-access-policy \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

**Impacto:** Se a role IAM do caller for comprometida, o atacante tem controle total do cluster.

**Correção:** Para uso operacional, preferir `AmazonEKSAdminPolicy` com `access-scope type=namespace` restrito aos namespaces necessários. Para o lab, documentar que esse nível de acesso é intencional apenas para o ambiente de laboratório.

---

### [SEC-005] Ausência de Security Groups dedicados para o ALB — Baixo

**Arquivo:** `07-configure-alb-ingress`

**Problema:** O Ingress não define a annotation `alb.ingress.kubernetes.io/security-groups`, deixando o ALB Controller criar e gerenciar Security Groups automaticamente com regras permissivas por padrão (0.0.0.0/0 nas portas 80 e 443).

**Impacto:** Em produção, isso impede o controle explícito de quais IPs podem acessar o ALB — impossibilitando restrições por IP de origem (ex: acesso apenas de IPs corporativos) ou integração com prefixlists.

**Correção:** Para produção, criar e referenciar Security Groups explícitos:

```yaml
alb.ingress.kubernetes.io/security-groups: sg-xxxx,sg-yyyy
alb.ingress.kubernetes.io/manage-backend-security-group-rules: "true"
```

Para o lab, o comportamento padrão é aceitável dado que o WAF filtra o tráfego na camada 7.

---

### [SEC-006] Nós do cluster com IMDSv1 habilitado (padrão do eksctl) — Médio

**Arquivo:** `02-create-cluster`

**Problema:** O `eksctl` não desabilita IMDSv1 no node group. Com IMDSv1 ativo, qualquer processo dentro de um pod (via `hostNetwork: true` ou em caso de SSRF) pode acessar `http://169.254.169.254/latest/meta-data/iam/security-credentials/` sem token de sessão e obter as credenciais temporárias da role do nó.

**Impacto:** Escalada de privilégios: credenciais do IAM role do nó (`AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`) acessíveis sem autenticação via SSRF ou pod comprometido.

**Correção:** Forçar IMDSv2 (token obrigatório) no node group:

```yaml
managedNodeGroups:
  - name: ${cluster_name}-nodes
    # ... demais configs ...
    instanceMetadataOptions:
      httpTokens: required          # força IMDSv2
      httpPutResponseHopLimit: 1    # bloqueia acesso ao IMDS de dentro de containers
```

Com `httpPutResponseHopLimit: 1`, o token IMDSv2 não atravessa o hop adicional do overlay de rede dos pods, bloqueando o acesso ao IMDS mesmo com IMDSv2.

---

### [SEC-007] WAF sem rate limiting — Baixo

**Arquivo:** `09-configure-waf`

**Problema:** A WebACL usa apenas regras gerenciadas de detecção de padrões (CRS, KnownBadInputs, IP Reputation), mas não configura regras de rate limiting. O Shield Standard não protege contra ataques de aplicação de alto volume.

**Impacto:** A aplicação fica vulnerável a ataques de força bruta em endpoints de autenticação ou flood de requisições legítimas de um único IP.

**Correção:** Adicionar uma regra de rate limit à WebACL:

```json
{
  "Name": "RateLimitRule",
  "Priority": 0,
  "Action": {"Block": {}},
  "Statement": {
    "RateBasedStatement": {
      "Limit": 2000,
      "AggregateKeyType": "IP"
    }
  },
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "RateLimitRule"
  }
}
```
