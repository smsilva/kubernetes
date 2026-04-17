# Passo a Passo — Infraestrutura

## Pré-requisitos

- `aws` CLI configurado com permissões suficientes (IAM, VPC, EKS, ACM, WAF)
- `eksctl` instalado
- `helm` instalado
- `kubectl` instalado
- Certificado wildcard para `*.wasp.silvios.me` em `~/certificates/config/live/wasp.silvios.me/`

## Configuração inicial

Edite `scripts/env.conf` antes de executar qualquer script:

```bash
aws_region="us-east-1"
instance_name="wasp"           # nome lógico da instância — usado por recursos globais (Global Accelerator, etc.)
cluster_name="wasp-calm-crow-ndx4"  # nome do cluster EKS — usado por recursos provisionados para este cluster
domain="wasp.silvios.me"
az_subscription="wasp-sandbox"    # subscription Azure onde está a DNS zone
az_resource_group="wasp-foundation" # resource group Azure da DNS zone
cert_arn=""  # preencher no passo 06, após importar o cert no ACM
```

Use `scripts/env.conf.example` como ponto de partida.

---

## 01. Criar VPC

```bash
./scripts/01-create-vpc
```

Cria a VPC `10.0.0.0/16` com:

- 2 subnets públicas (`10.0.1.0/24`, `10.0.2.0/24`) em `us-east-1a` e `us-east-1b`
- 2 subnets privadas (`10.0.3.0/24`, `10.0.4.0/24`) em `us-east-1a` e `us-east-1b`
- Internet Gateway, NAT Gateway (com EIP) e route tables

Os IDs dos recursos são salvos em `.vpc-ids` para uso nos passos seguintes.

## 02. Criar cluster EKS

```bash
./scripts/02-create-cluster
```

Cria o cluster via `eksctl` usando a VPC do passo anterior:

- Nodes `t3.medium` nas subnets privadas (managed node group, 2–5 nós)
- OIDC provider habilitado (`withOIDC: true`) — necessário para IRSA

!!! warning "SEC-006"
    Por padrão o `eksctl` não força IMDSv2 nos nodes. Ver [SEC-006](../security-issues/sec-006.md).

## 03. Configurar acesso

```bash
./scripts/03-configure-access
```

Atualiza o `kubeconfig` local e cria um access entry com `AmazonEKSClusterAdminPolicy` para o caller IAM atual.

!!! warning "SEC-004"
    A política `AmazonEKSClusterAdminPolicy` tem escopo de cluster inteiro. Ver [SEC-004](../security-issues/sec-004.md).

## 04. Instalar ALB Controller

```bash
./scripts/04-install-alb-controller
```

1. Baixa a IAM policy oficial do repositório do controller
2. Cria a IAM policy na conta AWS
3. Cria o IAM service account com IRSA via `eksctl`
4. Instala o controller via Helm

!!! warning "SEC-002"
    A IAM policy é baixada sem verificação de hash SHA256. Ver [SEC-002](../security-issues/sec-002.md).

## 05. Instalar Istio

```bash
./scripts/05-install-istio
```

Instala o Istio via Helm na ordem correta:

1. `istio-base` — CRDs
2. `istiod` — control plane
3. `istio-ingressgateway` — gateway como `ClusterIP` (sem NLB próprio)

## 06. Importar certificado no ACM

```bash
./scripts/06-import-certificate-acm
```

Importa o certificado Let's Encrypt de `~/certificates/config/live/wasp.silvios.me/` no ACM e atualiza automaticamente o `cert_arn` em `env.conf`.

## 07. Configurar ALB via Ingress

```bash
./scripts/07-configure-alb-ingress
```

Cria o ALB via Ingress clássico do Kubernetes:

- `IngressClass` com `controller: ingress.k8s.aws/alb`
- `Ingress` com redirecionamento HTTP→HTTPS, TLS terminado via ACM
- Roteamento de `*.wasp.silvios.me` para o Istio IngressGateway

Ao final, cria automaticamente o registro CNAME wildcard no Azure DNS:

```
*.wasp.silvios.me → <alb-hostname>.us-east-1.elb.amazonaws.com
```

!!! info "Apex não é coberto pelo wildcard"
    O registro do apex `wasp.silvios.me` é criado no passo 07b com IPs estáticos do Global Accelerator (CNAME no apex é inválido pelo RFC 1034; Azure DNS não suporta ALIAS para ALBs externos).

!!! warning "SEC-005"
    Security Groups do ALB criados automaticamente pelo controller, sem restrição de IP de origem. Ver [SEC-005](../security-issues/sec-005.md).

## 07b. Configurar Global Accelerator

```bash
./scripts/07b-configure-global-accelerator
```

Provisiona o Global Accelerator (`${instance_name}-ga`) apontando para o ALB e cria os A records do apex no Azure DNS:

```
wasp.silvios.me → <ip1>, <ip2>  (IPs anycast estáticos do Global Accelerator)
```

O nome do accelerator usa `instance_name` (não `cluster_name`) pois é um recurso global — pode sobreviver a trocas de cluster e, futuramente, servir múltiplas regiões. O ARN é salvo automaticamente em `env.conf` para uso pelo `destroy`.

## 08. Deploy da app de exemplo

```bash
./scripts/08-deploy-sample-app
```

Deploy do `httpbin` para validar o fluxo completo:

- Namespace `sample` com `istio-injection: enabled`
- Istio `Gateway` + `VirtualService` para `httpbin.wasp.silvios.me`

Validação:

```bash
curl https://httpbin.wasp.silvios.me/get
```

!!! warning "SEC-003"
    A imagem `kennethreitz/httpbin` é usada sem digest fixo. Ver [SEC-003](../security-issues/sec-003.md).

## 09. Configurar WAF

```bash
./scripts/09-configure-waf
```

Cria uma WebACL com AWS Managed Rules e associa ao ALB:

| Regra | Proteção |
|---|---|
| `AWSManagedRulesCommonRuleSet` | XSS, SQLi e outros vetores comuns |
| `AWSManagedRulesKnownBadInputsRuleSet` | Inputs maliciosos conhecidos |
| `AWSManagedRulesAmazonIpReputationList` | IPs maliciosos e botnets |

!!! info "SEC-007 (Resolvido)"
    Rate limiting não está incluído neste script — é adicionado no passo 15. Ver [SEC-007](../security-issues/sec-007.md).

## 10. Criar tabela DynamoDB

```bash
./scripts/10-create-dynamodb
```

Cria a tabela `tenant-registry` e insere o item de exemplo para `customer1.com`.

## 11. Criar Cognito User Pool

```bash
export GOOGLE_CLIENT_ID="..."
export GOOGLE_CLIENT_SECRET="..."
./scripts/11-create-cognito
```

Cria o User Pool com:

- Google como Identity Provider (OIDC)
- App Client com client credentials
- Lambda Pre-Token Generation (customização de claims)

!!! info "Google redirect URI"
    Adicionar `https://idp.wasp.silvios.me/oauth2/idpresponse` em **Authorized redirect URIs** no Google Cloud Console (não em JavaScript origins — o flow é server-side redirect).

## 12. Configurar DNS do Cognito

```bash
./scripts/12-configure-dns-cognito
```

Configura o custom domain `idp.wasp.silvios.me` para o Cognito Hosted UI e cria o CNAME no Azure DNS.

## 13. Deploy dos serviços

```bash
export COGNITO_CLIENT_SECRET_CUSTOMER1="..."   # aws cognito-idp describe-user-pool-client --query UserPoolClient.ClientSecret
export STATE_JWT_SECRET="..."        # openssl rand -hex 32
./scripts/13-deploy-services
```

- Build e push das imagens Docker Hub (tag = git short SHA)
- Cria o IRSA para o discovery service (`dynamodb:GetItem`)
- Deploy dos 4 namespaces: `platform`, `auth`, `discovery`, `customer1`

## 14. Configurar autenticação Istio

```bash
./scripts/14-configure-istio-auth
```

Aplica no namespace `customer1`:

- `RequestAuthentication` — valida JWT via JWKS URI do Cognito
- `AuthorizationPolicy` — rejeita requests sem JWT válido

## 15. Configurar rate limiting WAF

```bash
./scripts/15-configure-waf-ratelimit
```

Adiciona regras de rate limiting à WebACL existente:

- `/login` — 100 requests/5 min por IP
- `/callback` — 100 requests/5 min por IP

## 16. Registrar IdP e tenant

```bash
echo "${AZURE_CLIENT_SECRET}" | ./scripts/configure-idps \
  --tenant customer2 \
  --provider microsoft \
  --domain msn.com \
  --client-id "${AZURE_CLIENT_ID}" \
  --client-secret-stdin
```

Registra IdP (Google ou Microsoft) + App Client Cognito + item DynamoDB para um tenant.
Usar `--provider google` para tenants com Google IdP.

## 17. Deploy do customer2

```bash
./scripts/17-deploy-customer2
```

Deploy do namespace `customer2` com:

- `RequestAuthentication` + `AuthorizationPolicy` configurados para o tenant
- Callback handler atualizado com o client secret do customer2

---

## Variáveis de ambiente obrigatórias

Scripts 11 e 13 requerem variáveis de ambiente que **não entram** no `env.conf`:

| Variável | Usado em | Como obter |
|---|---|---|
| `GOOGLE_CLIENT_ID` | `11-create-cognito` | Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client ID |
| `GOOGLE_CLIENT_SECRET` | `11-create-cognito` | Mesmo lugar do Client ID |
| `COGNITO_CLIENT_SECRET_CUSTOMER1` | `13-deploy-services` | `aws cognito-idp describe-user-pool-client --query UserPoolClient.ClientSecret` |
| `STATE_JWT_SECRET` | `13-deploy-services` | `openssl rand -hex 32` |
