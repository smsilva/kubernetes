# CLAUDE.md — EKS Lab Context

> Guia de contexto para Claude Code em sessões futuras neste diretório.

---

## Identificadores principais

| Recurso | Valor |
|---|---|
| **Cluster EKS** | `wasp-calm-crow-ndx4` |
| **Região** | `us-east-1` |
| **Domínio** | `wasp.silvios.me` (wildcard `*.wasp.silvios.me`) |
| **ACM Certificate ARN** | `arn:aws:acm:us-east-1:221047292361:certificate/59ab7614-fa1b-4dba-9f43-7c775cfa5bac` |
| **VPC ID** | `vpc-03cb9d83815b52ee1` |
| **AWS Account ID** | `221047292361` |

---

## Projeto relacionado: waspctl

O projeto `waspctl` em `~/git/waspctl` é a CLI que vai automatizar o provisionamento desta mesma infraestrutura. Este lab documenta a **Fase 1** (cluster único + Auth Service manual). O waspctl cobre as fases 1-3, incluindo expansão multi-região com Global Accelerator. Consultar `~/git/waspctl/README.md` para referências externas (artigos AWS) e especificação completa da CLI.

---

## Fluxo de tráfego

```
Internet → ALB (TLS termination, ACM cert)
         → WAF (managed rules + rate limiting)
         → Istio IngressGateway (ClusterIP, private subnet)
         → Istio Gateway + VirtualService
         → Aplicação (namespace com sidecar injection)
```

---

## Estrutura dos scripts

Scripts em `scripts/`, documentos em `docs/`. Configurações globais em `scripts/env.conf`.

| Script | O que faz |
|---|---|
| `scripts/01-create-vpc` | VPC, subnets, IGW, NAT Gateway, route tables |
| `scripts/02-create-cluster` | Cluster EKS + node group via eksctl |
| `scripts/03-configure-access` | EKS Access API + AmazonEKSClusterAdminPolicy |
| `scripts/04-install-alb-controller` | Helm + IRSA para ALB Controller |
| `scripts/05-install-istio` | Helm: istio/base + istiod + gateway |
| `scripts/06-import-certificate-acm` | Importa cert Let's Encrypt no ACM |
| `scripts/07-configure-alb-ingress` | Ingress resource + IngressClass |
| `scripts/08-deploy-sample-app` | httpbin no namespace `sample` |
| `scripts/09-configure-waf` | WAF WebACL + regras gerenciadas + associação ao ALB |
| `scripts/10-create-dynamodb` | Tabela DynamoDB `tenant-registry` + item customer1 |
| `scripts/11-create-cognito` | User Pool, Google IdP, App Client, Lambda Pre-Token Generation |
| `scripts/12-configure-dns-cognito` | Custom domain Cognito (`idp.wasp.silvios.me`) + CNAME no Azure DNS |
| `scripts/13-deploy-services` | Build/push Docker Hub, IRSA discovery, deploy K8s dos 4 namespaces |
| `scripts/14-configure-istio-auth` | Istio `RequestAuthentication` + `AuthorizationPolicy` no namespace `customer1` |
| `scripts/15-configure-waf-ratelimit` | Rate limiting WAF para `/login` e `/callback` |
| `scripts/destroy` | Destrói tudo na ordem inversa (ACM deve ser removido manualmente) |

**Script pendente:** `scripts/07b-configure-global-accelerator` — deve ser criado entre os scripts 07 e 08. Provisiona dois IPs anycast estáticos (Global Accelerator → ALB) para substituir os A records frágeis do apex `wasp.silvios.me`, cujos IPs de ALB são rotativos.

---

## Documentação de referência

| Documento | Conteúdo |
|---|---|
| `docs/fluxo-autenticacao-multitenant.md` | Arquitetura do fluxo de autenticação multi-tenant |
| `docs/decisoes-tecnicas.md` | Decisões de design, trade-offs e itens adiados conscientemente |
| `docs/onboarding-novo-customer.md` | Passos para cadastrar novo tenant: IdP, DynamoDB, K8s, domínios compartilhados |

---

## DNS

O domínio `wasp.silvios.me` é gerenciado em **Azure DNS** (subscription `wasp-sandbox`, resource group `wasp-foundation`), não no Route 53. Scripts usam `az network dns record-set` em vez de `aws route53`.

---

## Subdomínios e roteamento

| Subdomínio | Destino | Via |
|---|---|---|
| `wasp.silvios.me` | platform-frontend (ns: `platform`) | ALB → Istio |
| `idp.wasp.silvios.me` | Cognito Hosted UI | CloudFront (Azure DNS CNAME) |
| `auth.wasp.silvios.me` | callback-handler (ns: `auth`) | ALB → Istio |
| `discovery.wasp.silvios.me` | discovery service (ns: `discovery`) | ALB → Istio |
| `customer1.wasp.silvios.me` | httpbin / app tenant (ns: `customer1`) | ALB → Istio |

---

## Credenciais — variáveis de ambiente obrigatórias

Scripts 11 e 13 requerem env vars (não entram no `env.conf`):

| Variável | Usado em | Como obter |
|---|---|---|
| `GOOGLE_CLIENT_ID` | `11-create-cognito` | Google Cloud Console → OAuth 2.0 credentials |
| `GOOGLE_CLIENT_SECRET` | `11-create-cognito` | Google Cloud Console → OAuth 2.0 credentials |
| `COGNITO_CLIENT_SECRET` | `13-deploy-services` | `aws cognito-idp describe-user-pool-client --query UserPoolClient.ClientSecret` |
| `STATE_JWT_SECRET` | `13-deploy-services` | `openssl rand -hex 32` |

Google redirect URI obrigatório: `https://idp.wasp.silvios.me/oauth2/idpresponse` em **Authorized redirect URIs** (não em JavaScript origins — nosso flow é server-side redirect).

---

## Serviços Python (`services/`)

Stack: Python 3.12 + FastAPI + Jinja2 + PyJWT + httpx. Cada serviço tem `.venv` próprio.

```bash
cd lab/aws/eks/services/<serviço>
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest tests/ -v
```

### Variáveis de ambiente por serviço

| Serviço | Variável | Valor |
|---|---|---|
| `callback-handler` | `COGNITO_DOMAIN` | `idp.wasp.silvios.me` (só hostname, sem `https://`) |
| `callback-handler` | `COGNITO_CLIENT_ID` | App Client ID do tenant (ConfigMap) |
| `callback-handler` | `COGNITO_CLIENT_SECRET` | Via Secret `callback-handler-secret` |
| `callback-handler` | `STATE_JWT_SECRET` | Chave compartilhada com `platform-frontend` |
| `platform-frontend` | `COGNITO_DOMAIN` | `idp.wasp.silvios.me` (só hostname, sem `https://`) |
| `platform-frontend` | `DISCOVERY_URL` | `https://discovery.wasp.silvios.me` |
| `platform-frontend` | `CALLBACK_URL` | `https://auth.wasp.silvios.me/callback` |
| `platform-frontend` | `STATE_JWT_SECRET` | Chave compartilhada com `callback-handler` |

Imagens Docker Hub (build com `--platform linux/amd64`; tag = git short SHA, nunca `:latest`):

| Serviço | Repositório |
|---|---|
| `discovery` | `silviosilva/wasp-discovery` |
| `platform-frontend` | `silviosilva/wasp-platform-frontend` |
| `callback-handler` | `silviosilva/wasp-callback-handler` |

---

## Issues de segurança documentadas (SEC-*)

| ID | Severidade | Problema |
|---|---|---|
| [SEC-002](docs/security-issues/sec-002.md) | Médio | IAM policy baixada sem verificação de hash |
| [SEC-003](docs/security-issues/sec-003.md) | Baixo | Imagem do container sem digest fixo |
| [SEC-004](docs/security-issues/sec-004.md) | Médio | Permissão cluster-admin sem escopo de namespace |
| [SEC-005](docs/security-issues/sec-005.md) | Baixo | Sem Security Groups dedicados para o ALB |
| [SEC-006](docs/security-issues/sec-006.md) | Médio | IMDSv1 habilitado nos nodes |

---

## Gotchas operacionais

### `tenants.json` deve ter valores reais do Cognito

`services/discovery/app/data/tenants.json` é fonte de dados estática. Ao reprovisionar o Cognito, atualizar `client_id` e `cognito_pool_id` antes do build, fazer commit e rebuild com nova tag SHA.

### `COGNITO_DOMAIN` sem `https://`

No ConfigMap `platform-frontend-config`, o campo `COGNITO_DOMAIN` deve ser só o hostname (`idp.wasp.silvios.me`). O código em `auth.py` já adiciona o scheme — colocar a URL completa gera `https://https://idp...`.

### DynamoDB — palavras reservadas em `--update-expression`

Atributos com nomes reservados (ex: `auth`, `name`, `status`) causam `ValidationException`. Usar `--expression-attribute-names` com alias `#`:

```bash
--update-expression 'SET #auth.field = :val' \
--expression-attribute-names '{"#auth": "auth"}'
```

### WAFv2 — `--id` exige UUID, não name

```bash
# CORRETO — $NF extrai o UUID (último segmento do ARN)
web_acl_id="$(echo "${web_acl_arn}" | awk -F'/' '{print $NF}')"
```

### Pipe + heredoc Python — conflito de stdin

Pipe (`|`) e heredoc (`<<EOF`) disputam o stdin. O heredoc vence. Gravar a variável em arquivo temporário e ler via `open()`.
