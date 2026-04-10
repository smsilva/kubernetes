# CLAUDE.md — EKS Lab Context

> Guia de contexto para Claude Code em sessões futuras neste diretório.

---

## O que está provisionado

Este lab implanta um cluster EKS na AWS com ALB + Istio Gateway + WAF, acessível via `*.wasp.silvios.me`.

### Identificadores principais

| Recurso | Valor |
|---|---|
| **Cluster EKS** | `wasp-calm-crow-ndx4` |
| **Região** | `us-east-1` |
| **Domínio** | `wasp.silvios.me` (wildcard `*.wasp.silvios.me`) |
| **ACM Certificate ARN** | `arn:aws:acm:us-east-1:221047292361:certificate/f34e8fc8-fda5-42af-82e1-eee316f81d0e` |
| **VPC ID** | `vpc-03cb9d83815b52ee1` |
| **AWS Account ID** | `221047292361` |

### Rede (VPC 10.0.0.0/16)

| Subnet | CIDR | AZ | Tipo |
|---|---|---|---|
| `subnet-0d11908e3d3ac35ba` | 10.0.1.0/24 | us-east-1a | Pública (ALB/NAT) |
| `subnet-01b8a77128b10757f` | 10.0.2.0/24 | us-east-1b | Pública (ALB/NAT) |
| `subnet-0f4bcf85d2c59f868` | 10.0.3.0/24 | us-east-1a | Privada (EKS nodes) |
| `subnet-01a17ca1086c1e995` | 10.0.4.0/24 | us-east-1b | Privada (EKS nodes) |

---

## Componentes instalados

### AWS Load Balancer Controller
- **Namespace:** `kube-system`
- **Versão:** `v3.2.1`
- **IRSA:** Habilitado (`aws-load-balancer-controller` service account)
- **IAM Policy:** `AWSLoadBalancerControllerIAMPolicy`

### Istio
- **Versão:** `1.24.3`
- **Control plane:** namespace `istio-system`
- **IngressGateway:** namespace `istio-ingress`, tipo `ClusterIP`
- **Health check:** porta `15021`, path `/healthz/ready`

### ALB Ingress
- **Namespace:** `istio-ingress`
- **Host pattern:** `*.wasp.silvios.me`
- **Backend:** `istio-ingressgateway:80`
- **TLS:** terminado no ALB via ACM — certificado wildcard `*.wasp.silvios.me` cobre todos os subdomínios; um único CNAME `*.wasp.silvios.me → ALB hostname` no Azure DNS é suficiente. Exceção: `idp.wasp.silvios.me` aponta para o CloudFront do Cognito (script 12).
- **HTTP→HTTPS redirect:** habilitado
- **Target type:** `ip` (aponta direto para pods)

### WAF
- **WebACL:** `wasp-calm-crow-ndx4-web-acl`
- **Scope:** REGIONAL, associado ao ALB
- **Regras ativas:** `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet`, `AWSManagedRulesAmazonIpReputationList`
- **Gap documentado (SEC-007):** sem rate limiting

### Aplicação de exemplo (httpbin)
- **Namespace:** `sample` (com `istio-injection: enabled`)
- **URL:** `https://httpbin.wasp.silvios.me/get`
- **Gateway:** `httpbin-gateway` (HTTP/80, host `httpbin.wasp.silvios.me`)
- **VirtualService:** roteia para `httpbin:8000`

---

## Fluxo de tráfego

```
Internet → ALB (TLS termination, ACM cert)
         → WAF (managed rules)
         → Istio IngressGateway (ClusterIP, private subnet)
         → Istio Gateway + VirtualService
         → Aplicação (namespace com sidecar injection)
```

---

## Estrutura dos scripts

Scripts em `scripts/`, documentos em `docs/`.

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
| `scripts/destroy` | Destrói tudo na ordem inversa (ACM deve ser removido manualmente) |

Configurações globais em `scripts/env.conf`. Variáveis preenchidas automaticamente pelos scripts:
- `cert_arn` (script 06), `cognito_user_pool_id`, `cognito_app_client_id`, `cognito_cloudfront_domain` (scripts 11/12)

---

## DNS

O domínio `wasp.silvios.me` é gerenciado em **Azure DNS**, não no Route 53:

| Campo | Valor |
|---|---|
| **Subscription** | `wasp-sandbox` |
| **Resource Group** | `wasp-foundation` |
| **Zone** | `wasp.silvios.me` |

Scripts que criam registros DNS usam `az network dns record-set` em vez de `aws route53`.

---

## Tagging AWS

Todos os recursos têm:
- `project: eks-lab`
- `env: lab`

---

## Issues de segurança documentadas (SEC-*)

| ID | Severidade | Problema |
|---|---|---|
| SEC-002 | Médio | IAM policy baixada sem verificação de hash |
| SEC-003 | Baixo | Imagem do container sem digest fixo |
| SEC-004 | Médio | Permissão cluster-admin sem escopo de namespace |
| SEC-005 | Baixo | Sem Security Groups dedicados para o ALB |
| SEC-006 | Médio | IMDSv1 habilitado nos nodes |
| SEC-007 | Baixo | WAF sem rate limiting |

---

## Fluxo de autenticação multi-tenant

Plano detalhado em `docs/plano-autenticacao-multitenant.md`.

- **Email de teste:** `smsilva@gmail.com`
- **Tenant esperado:** `customer1.wasp.silvios.me`
- **IdP:** Google SSO via Cognito
- **Fluxo:** `wasp.silvios.me` → discovery → `idp.wasp.silvios.me` (Cognito) → `auth.wasp.silvios.me` (callback) → tenant subdomain

### Subdomínios e roteamento

| Subdomínio | Destino | Via |
|---|---|---|
| `wasp.silvios.me` | platform-frontend (ns: `platform`) | ALB → Istio |
| `idp.wasp.silvios.me` | Cognito Hosted UI | CloudFront (Azure DNS CNAME) |
| `auth.wasp.silvios.me` | callback-handler (ns: `auth`) | ALB → Istio |
| `discovery.wasp.silvios.me` | discovery service (ns: `discovery`) | ALB → Istio |
| `customer1.wasp.silvios.me` | httpbin / app tenant (ns: `customer1`) | ALB → Istio |

### Credenciais — variáveis de ambiente obrigatórias

Scripts 11 e 13 requerem env vars (não entram no `env.conf`):

| Variável | Usado em | Como obter |
|---|---|---|
| `GOOGLE_CLIENT_ID` | `11-create-cognito` | Google Cloud Console → OAuth 2.0 credentials |
| `GOOGLE_CLIENT_SECRET` | `11-create-cognito` | Google Cloud Console → OAuth 2.0 credentials |
| `COGNITO_CLIENT_SECRET` | `13-deploy-services` | `aws cognito-idp describe-user-pool-client --query UserPoolClient.ClientSecret` |
| `STATE_JWT_SECRET` | `13-deploy-services` | `openssl rand -hex 32` |

Google redirect URI obrigatório no Google Cloud Console: `https://idp.wasp.silvios.me/oauth2/idpresponse`

### Cognito

| Recurso | Valor |
|---|---|
| **User Pool** | `wasp-platform` |
| **Custom domain** | `idp.wasp.silvios.me` |
| **App Client** | `customer1` |
| **Callback URL** | `https://auth.wasp.silvios.me/callback` |
| **Pre-Token Lambda** | `wasp-pre-token-generation` — injeta `custom:tenant_id` no JWT via DynamoDB GSI |
| **Lambda IAM Role** | `wasp-pre-token-lambda-role` |

### IRSA — discovery

| Recurso | Valor |
|---|---|
| **IAM Role** | `wasp-discovery-irsa` |
| **Service Account** | `discovery/discovery` |
| **Permissões** | `dynamodb:GetItem`, `dynamodb:Query` em `tenant-registry` e seus índices |

### Imagens Docker Hub

| Serviço | Imagem |
|---|---|
| `discovery` | `silviosilva/wasp-discovery:latest` |
| `platform-frontend` | `silviosilva/wasp-platform-frontend:latest` |
| `callback-handler` | `silviosilva/wasp-callback-handler:latest` |

Build com `--platform linux/amd64` (nodes EKS são x86_64).

### Serviços implementados (`services/`)

| Serviço | Porta | Testes | Status |
|---|---|---|---|
| `discovery` | 8000 | 6/6 | committed |
| `platform-frontend` | 8000 | 5/5 | committed |
| `callback-handler` | 8000 | 10/10 | committed |

Cada serviço tem: `app/`, `tests/`, `requirements.txt`, `requirements-dev.txt`, `Dockerfile`, `.gitignore`.

**Stack:** Python 3.12 + FastAPI + Jinja2 + PyJWT + httpx  
**Frontend:** Material Design 3, Roboto, dark mode via `data-theme` + `localStorage`  
**Testes:** pytest + `TestClient` + `app.dependency_overrides`

---

## Lições aprendidas — AWS CLI

### WAFv2 — formato do ARN e parâmetro `--id`

O ARN de um WebACL tem o formato:
```
arn:aws:wafv2:<region>:<account>:regional/webacl/<name>/<uuid>
```

O parâmetro `--id` do `aws wafv2 get-web-acl` (e outros comandos WAFv2) exige o **UUID** (último segmento), não o `name`. Usar `$(NF-1)` com `awk -F'/'` retorna o `name` — o correto é `$NF`:

```bash
# CORRETO — extrai o UUID
web_acl_id="$(echo "${web_acl_arn}" | awk -F'/' '{print $NF}')"

# ERRADO — extrai o name, causa ValidationException
web_acl_id="$(echo "${web_acl_arn}" | awk -F'/' '{print $(NF-1)}')"
```

---

## Lições aprendidas — serviços Python/FastAPI

### Starlette TemplateResponse — API nova (≥0.36)

A assinatura mudou. Usar sempre com keyword arguments:

```python
# CORRETO
templates.TemplateResponse(
    request=request,
    name="login.html",
    context={"error": error, "email": email},  # request NÃO entra no context
)

# ERRADO — causa TypeError: unhashable type: 'dict'
templates.TemplateResponse("login.html", {"request": request, "error": error})
```

### Starlette — casing do SameSite cookie

Starlette serializa `samesite="lax"` como `SameSite=lax` (minúsculo). Testar com lowercase:

```python
assert "SameSite=lax" in cookie   # correto
assert "SameSite=Lax" in cookie   # falha
```

### TDD com FastAPI — padrão de dependency injection

Todas as dependências externas (repositório, cliente HTTP, Cognito) são injetadas via `Depends()` e substituídas nos testes com `app.dependency_overrides`:

```python
# conftest.py
@pytest.fixture
def api_client(mock_repository):
    app.dependency_overrides[get_repository] = lambda: mock_repository
    yield TestClient(app)
    app.dependency_overrides.clear()
```

O `TestClient` nunca faz chamadas de rede reais. Fixtures de mock substituem apenas o que cada teste precisa.

### .gitignore por serviço

Cada serviço tem `.gitignore` próprio com:
```
.venv/
__pycache__/
*.pyc
.pytest_cache/
```

Sem isso, `git add .` captura o `.venv/` inteiro (3000+ arquivos).

### CSS em arquivo separado

CSS nunca inline no template HTML. Servir via `StaticFiles`:

```python
app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")
```

Template referencia com `<link rel="stylesheet" href="/static/login.css">`.

### State JWT — proteção CSRF no OAuth flow

O parâmetro `state` do OAuth é um JWT assinado (HS256) contendo:

```python
{
    "tenant_id": "customer1",
    "return_url": "https://customer1.wasp.silvios.me",
    "nonce": secrets.token_urlsafe(16),
    "exp": now + timedelta(minutes=10),
}
```

Segredo compartilhado via env var `STATE_JWT_SECRET` entre `platform-frontend` e `callback-handler`.

### Dados de teste — conftest vs JSON de produção

Os dados de `conftest.py` são **fixos e controlados** para os testes. Não carregar o JSON de produção (`app/data/tenants.json`) no conftest — os testes devem ser independentes de dados de seed.

```python
# conftest.py — dados explícitos, previsíveis
CUSTOMER1 = TenantConfig(tenant_id="customer1", tenant_url="customer1.wasp.silvios.me", ...)
```

### Próximos passos (docs/plano-autenticacao-multitenant.md)

- [x] **10.1** Cognito User Pool + App Client + Google IdP → `scripts/11-create-cognito`
- [x] **10.2** DNS do Cognito Hosted UI (`idp.wasp.silvios.me`) → `scripts/12-configure-dns-cognito`
- [x] **10.3** DynamoDB `tenant-registry` → `scripts/10-create-dynamodb`
- [x] **10.7** Deployments Kubernetes para os três serviços → `scripts/13-deploy-services`
- [x] **10.8** Istio `RequestAuthentication` (validar JWT Cognito) → `scripts/14-configure-istio-auth`
- [x] **10.9** Istio `AuthorizationPolicy` (bloquear sem JWT válido) → `scripts/14-configure-istio-auth`
- [x] **10.10** WAF rate limiting → `scripts/15-configure-waf-ratelimit`
- [ ] **10.11** Teste end-to-end com `smsilva@gmail.com`
