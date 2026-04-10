# Plano de Implementação — Autenticação Multi-tenant

> **Contexto:** Implementação passo a passo do fluxo de autenticação descrito em `fluxo-autenticacao-multitenant.md`, adaptado para o cluster único já provisionado.
>
> **Email de teste:** `smsilva@gmail.com`  
> **Tenant esperado:** `customer1` → `customer1.wasp.silvios.me`  
> **IdP:** Google SSO via Cognito

---

## Serviços a desenvolver

Três aplicações Python serão criadas em `services/`:

```
services/
├── platform-frontend/     # Página inicial em wasp.silvios.me — coleta email, aciona discovery
├── discovery/             # API REST: email domain → config do tenant (DynamoDB)
└── callback-handler/      # Troca OAuth code por tokens Cognito, emite cookie de sessão
```

**Stack:** Python 3.12 + [FastAPI](https://fastapi.tiangolo.com/) para `discovery` e `callback-handler`; HTML/JS puro (servido pelo FastAPI) para `platform-frontend`.

FastAPI foi escolhido por ser o framework Python mais popular para APIs, ter suporte nativo a async, validação automática com Pydantic e servidor ASGI (Uvicorn) embutido.

---

## Visão geral das etapas

```
[10.1] Cognito User Pool + App Client (customer1 → Google)
[10.2] Cognito Hosted UI em auth.wasp.silvios.me
[10.3] DynamoDB tenant-registry (gmail.com → customer1)
[10.4] Discovery Service              ← services/discovery/
[10.5] Callback Handler               ← services/callback-handler/
[10.6] Platform Frontend              ← services/platform-frontend/
[10.7] Namespace customer1 + aplicação de teste (httpbin)
[10.8] Istio RequestAuthentication (JWKS do Cognito)
[10.9] Istio AuthorizationPolicy por namespace (tenant_id claim)
[10.10] WAF rate limiting em /login e /callback
[10.11] Teste end-to-end do fluxo completo
```

---

## Etapa 10.1 — Cognito User Pool + App Client

### O que fazer

1. Criar um **Cognito User Pool** (`wasp-platform`) em `us-east-1`
2. Configurar o domínio do Hosted UI: `auth.wasp.silvios.me`
3. Criar um **App Client** para o tenant `customer1` com Google como IdP externo
4. Configurar o **Identity Provider Google** no Cognito com as credenciais OAuth do Google Cloud
5. Configurar o **Pre-Token Generation Lambda** para injetar `tenant_id` no JWT

### Pré-requisitos

- Google Cloud Console: criar OAuth 2.0 credentials com redirect URI:
  ```
  https://auth.wasp.silvios.me/oauth2/idpresponse
  ```
- Salvar `client_id` e `client_secret` do Google

### Recursos a criar

```
Cognito User Pool: wasp-platform
  ├── Custom attribute: custom:tenant_id (string, imutable)
  ├── Custom attribute: custom:groups (string)
  ├── Domain: auth.wasp.silvios.me (custom domain com ACM cert)
  ├── Identity Provider: Google
  │     client_id: <google-oauth-client-id>
  │     client_secret: <google-oauth-client-secret>
  │     scopes: openid email profile
  │     attribute_mapping:
  │       email: email
  │       name: name
  └── App Client: customer1
        Allowed IdPs: Google
        Callback URL: https://auth.wasp.silvios.me/callback
        Logout URL: https://customer1.wasp.silvios.me/logout
        OAuth flows: Authorization code grant
        OAuth scopes: openid email profile
```

### Pre-Token Generation Lambda

Injeta `tenant_id` no JWT com base no `clientId` do App Client. O `tenant_id` não pode ser forjado pelo cliente.

```python
# lambda/pre_token_generation.py
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tenant-registry')

def handler(event, context):
    client_id = event['callerContext']['clientId']

    response = table.query(
        IndexName='client-id-index',
        KeyConditionExpression='cognito_app_client_id = :cid',
        ExpressionAttributeValues={':cid': client_id}
    )

    if not response['Items']:
        raise Exception(f"No tenant found for client_id: {client_id}")

    tenant_id = response['Items'][0]['tenant_id']

    event['response']['claimsOverrideDetails'] = {
        'claimsToAddOrOverride': {
            'custom:tenant_id': tenant_id
        }
    }
    return event
```

**Permissões IAM necessárias para a Lambda:**
- `dynamodb:Query` na tabela `tenant-registry` (GSI `client-id-index`)

---

## Etapa 10.2 — Hosted UI em auth.wasp.silvios.me

### O que fazer

1. Configurar o custom domain no Cognito apontando para `auth.wasp.silvios.me`
2. Criar registro DNS `auth.wasp.silvios.me` → CloudFront distribution do Cognito
3. Verificar que `https://auth.wasp.silvios.me/oauth2/authorize` responde

### Nota sobre DNS

O Cognito custom domain cria uma distribuição CloudFront. O DNS precisa de um registro `CNAME` ou `ALIAS` no Route 53 apontando `auth.wasp.silvios.me` para esse CloudFront.

**Atenção:** O ACM certificate para o custom domain do Cognito **deve estar em `us-east-1`** (região global do CloudFront) — que já é o caso neste lab.

---

## Etapa 10.3 — DynamoDB tenant-registry

### O que fazer

Criar tabela `tenant-registry` com os dados do tenant `customer1`.

```bash
# Criar tabela
aws dynamodb create-table \
  --table-name tenant-registry \
  --attribute-definitions \
    AttributeName=pk,AttributeType=S \
    AttributeName=cognito_app_client_id,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH \
  --global-secondary-indexes '[
    {
      "IndexName": "client-id-index",
      "KeySchema": [{"AttributeName":"cognito_app_client_id","KeyType":"HASH"}],
      "Projection": {"ProjectionType":"ALL"},
      "ProvisionedThroughput": {"ReadCapacityUnits":5,"WriteCapacityUnits":5}
    }
  ]' \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

```bash
# Inserir registro do customer1 (gmail.com → customer1)
aws dynamodb put-item \
  --table-name tenant-registry \
  --item '{
    "pk": {"S": "domain#gmail.com"},
    "tenant_id": {"S": "customer1"},
    "url": {"S": "customer1.wasp.silvios.me"},
    "regions": {"L": [{"S": "us-east-1"}]},
    "auth": {"M": {
      "type": {"S": "google_sso"},
      "cognito_user_pool_id": {"S": "<pool-id>"},
      "cognito_app_client_id": {"S": "<app-client-id>"},
      "cognito_idp_name": {"S": "Google"}
    }},
    "status": {"S": "active"}
  }' \
  --region us-east-1
```

---

## Etapa 10.4 — Discovery Service

**Localização:** `services/discovery/`

Microserviço FastAPI que consulta o DynamoDB via IRSA e retorna a configuração do tenant a partir do domínio de e-mail.

### Estrutura

```
services/discovery/
├── app/
│   ├── main.py          # FastAPI app, rota GET /tenant
│   ├── dynamo.py        # Consulta DynamoDB (boto3 via IRSA)
│   └── models.py        # Pydantic response model
├── Dockerfile
└── requirements.txt
```

### Contrato da API

```
GET /tenant?domain=gmail.com

200 OK
{
  "tenant_id": "customer1",
  "tenant_url": "customer1.wasp.silvios.me",
  "client_id": "<cognito-app-client-id>",
  "idp_name": "Google",
  "cognito_pool_id": "<pool-id>"
}

404 Not Found
{
  "detail": "Tenant not found for domain: gmail.com"
}
```

### Recursos Kubernetes

```
Namespace: discovery (istio-injection: enabled)
  ├── ServiceAccount: discovery (com IRSA annotation)
  ├── Deployment: discovery (imagem: services/discovery)
  ├── Service: discovery (ClusterIP, porta 8000)
  ├── Gateway: discovery-gateway (host: discovery.wasp.silvios.me)
  └── VirtualService: discovery → discovery:8000
```

**IAM Role para IRSA:**
- `dynamodb:GetItem`, `dynamodb:Query` na tabela `tenant-registry`

---

## Etapa 10.5 — Callback Handler

**Localização:** `services/callback-handler/`

Microserviço FastAPI que recebe o redirect do Cognito após autenticação, troca o `code` por tokens, emite o cookie de sessão e redireciona o usuário para o subdomínio do tenant.

### Estrutura

```
services/callback-handler/
├── app/
│   ├── main.py          # FastAPI app, rota GET /callback
│   ├── cognito.py       # Troca code por tokens (httpx)
│   ├── state.py         # Encode/decode do JWT de state (python-jose)
│   └── models.py        # Pydantic models
├── Dockerfile
└── requirements.txt
```

### Fluxo do /callback

```
GET /callback?code=<code>&state=<state-jwt>

1. Decodifica state JWT → { tenant_id, nonce, return_url }
2. POST https://auth.wasp.silvios.me/oauth2/token
     grant_type=authorization_code
     code=<code>
     client_id=<app-client-id>
     redirect_uri=https://auth.wasp.silvios.me/callback
3. Recebe id_token (JWT Cognito com custom:tenant_id)
4. Valida que token.tenant_id == state.tenant_id
5. Set-Cookie: session=<id_token>; Domain=.wasp.silvios.me; HttpOnly; Secure; SameSite=Lax
6. 302 → https://<return_url>
```

### Recursos Kubernetes

```
Namespace: auth (istio-injection: enabled)
  ├── ServiceAccount: callback-handler
  ├── Deployment: callback-handler (imagem: services/callback-handler)
  ├── Service: callback-handler (ClusterIP, porta 8000)
  ├── Gateway: auth-gateway (host: auth.wasp.silvios.me)
  └── VirtualService:
        - /callback → callback-handler:8000
```

**Variáveis de ambiente necessárias (via ConfigMap/Secret):**
- `COGNITO_DOMAIN`: `https://auth.wasp.silvios.me`
- `COGNITO_CLIENT_ID`: `<app-client-id>`
- `COGNITO_CLIENT_SECRET`: via Secret
- `STATE_JWT_SECRET`: chave para assinar/verificar o state JWT

---

## Etapa 10.6 — Platform Frontend

**Localização:** `services/platform-frontend/`

Aplicação FastAPI que serve a página inicial em `wasp.silvios.me`. Apresenta o formulário de e-mail, chama o discovery service e monta a URL de autenticação Cognito.

### Estrutura

```
services/platform-frontend/
├── app/
│   ├── main.py          # FastAPI app, rota GET /
│   ├── static/
│   │   └── style.css
│   └── templates/
│       ├── index.html   # Formulário de e-mail
│       └── error.html   # Página de erro (tenant não encontrado)
├── Dockerfile
└── requirements.txt
```

### Fluxo da página inicial

```
GET https://wasp.silvios.me/
  → verifica cookie session
  → se válido: redirect para tenant_url do JWT
  → se ausente/inválido: exibe formulário de e-mail

POST /login (ou JS fetch)
  body: { email: "smsilva@gmail.com" }
  1. Extrai domínio: "gmail.com"
  2. GET https://discovery.wasp.silvios.me/tenant?domain=gmail.com
  3. Monta state JWT: { tenant_id, nonce, return_url }
  4. Redirect → https://auth.wasp.silvios.me/oauth2/authorize
       ?client_id=<client_id>
       &identity_provider=Google
       &redirect_uri=https://auth.wasp.silvios.me/callback
       &response_type=code
       &scope=openid+email+profile
       &state=<state-jwt>
```

### Recursos Kubernetes

```
Namespace: platform (istio-injection: enabled)
  ├── ServiceAccount: platform-frontend
  ├── Deployment: platform-frontend (imagem: services/platform-frontend)
  ├── Service: platform-frontend (ClusterIP, porta 8000)
  ├── Gateway: platform-gateway (host: wasp.silvios.me)
  └── VirtualService: wasp.silvios.me → platform-frontend:8000
```

**Variáveis de ambiente:**
- `DISCOVERY_URL`: `https://discovery.wasp.silvios.me`
- `AUTH_URL`: `https://auth.wasp.silvios.me`
- `CALLBACK_URL`: `https://auth.wasp.silvios.me/callback`
- `STATE_JWT_SECRET`: mesma chave usada pelo callback-handler

---

## Etapa 10.7 — Namespace customer1 + aplicação de teste

### O que fazer

1. Criar namespace `customer1` com `istio-injection: enabled`
2. Implantar `httpbin` (valida headers/claims recebidos do Istio)
3. Criar Gateway e VirtualService para `customer1.wasp.silvios.me`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: customer1
  labels:
    istio-injection: enabled
```

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: customer1-gateway
  namespace: customer1
spec:
  selector:
    app: istio-ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - customer1.wasp.silvios.me
```

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: customer1
  namespace: customer1
spec:
  hosts:
    - customer1.wasp.silvios.me
  gateways:
    - customer1-gateway
  http:
    - route:
        - destination:
            host: httpbin
            port:
              number: 8000
```

---

## Etapa 10.8 — Istio RequestAuthentication

Valida assinatura e expiração do JWT emitido pelo Cognito.

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: cognito-jwt
  namespace: customer1
spec:
  jwtRules:
    - issuer: "https://cognito-idp.us-east-1.amazonaws.com/<pool-id>"
      jwksUri: "https://cognito-idp.us-east-1.amazonaws.com/<pool-id>/.well-known/jwks.json"
      forwardOriginalToken: true
      fromCookies:
        - session
```

**Nota:** `fromCookies: [session]` instrui o Istio a extrair o JWT do cookie `session` (emitido pelo callback handler).

---

## Etapa 10.9 — Istio AuthorizationPolicy

Garante que apenas JWTs com `tenant_id=customer1` acessam o namespace `customer1`.

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-tenant-jwt
  namespace: customer1
spec:
  action: ALLOW
  rules:
    - when:
        - key: request.auth.claims[custom:tenant_id]
          values: ["customer1"]
```

**Comportamento:** Quando existe pelo menos uma `AuthorizationPolicy` no namespace, o Istio nega tudo que não for explicitamente permitido. Sem JWT válido com `tenant_id=customer1` → HTTP 403.

---

## Etapa 10.10 — WAF rate limiting em /login e /callback

Complementa o SEC-007 documentado. Adicionar rate-based rule ao WebACL existente (`wasp-calm-crow-ndx4-web-acl`):

- `/login`: 100 req/5min por IP
- `/callback`: 50 req/5min por IP

```bash
# Adicionar rule ao WebACL existente via AWS CLI
# (detalhar no script quando chegarmos aqui)
```

---

## Etapa 10.11 — Teste end-to-end

### Fluxo esperado com smsilva@gmail.com

```
1. GET https://wasp.silvios.me
   → sem cookie → exibe formulário de e-mail (platform-frontend)

2. Usuário digita smsilva@gmail.com
   → platform-frontend extrai domínio "gmail.com"
   → GET https://discovery.wasp.silvios.me/tenant?domain=gmail.com
   → retorna: { client_id, tenant_url: "customer1.wasp.silvios.me", idp_name: "Google" }

3. platform-frontend monta state JWT e redireciona:
   GET https://auth.wasp.silvios.me/oauth2/authorize
     ?client_id=<abc123>
     &identity_provider=Google
     &redirect_uri=https://auth.wasp.silvios.me/callback
     &response_type=code
     &scope=openid+email+profile
     &state=<JWT: tenant_id=customer1, nonce, return_url=customer1.wasp.silvios.me>

4. Cognito redireciona para Google OAuth
   → usuário autentica com smsilva@gmail.com no Google

5. Google retorna para Cognito com code
   → Cognito valida, aciona Pre-Token Lambda (injeta custom:tenant_id=customer1)
   → Cognito redireciona para https://auth.wasp.silvios.me/callback?code=...

6. callback-handler:
   → troca code por tokens (POST /oauth2/token)
   → decodifica state → tenant_id=customer1, return_url=customer1.wasp.silvios.me
   → Set-Cookie: session=<JWT>; Domain=.wasp.silvios.me; HttpOnly; Secure; SameSite=Lax
   → 302 → https://customer1.wasp.silvios.me

7. customer1.wasp.silvios.me recebe request com cookie
   → Istio RequestAuthentication valida JWT (JWKS do Cognito) ✓
   → Istio AuthorizationPolicy verifica custom:tenant_id == "customer1" ✓
   → httpbin exibe headers: x-forwarded-user, x-auth-request-email, custom:tenant_id
```

### Verificações de segurança

```
Cenário cross-tenant:
  GET https://customer1.wasp.silvios.me com JWT de outro tenant
  → AuthorizationPolicy: custom:tenant_id != "customer1" → HTTP 403 ✓

Cenário sem JWT:
  GET https://customer1.wasp.silvios.me sem cookie
  → AuthorizationPolicy: sem claim → HTTP 403 ✓
```

---

## Dependências e ordem de implementação

```
10.3 DynamoDB
  ├── 10.1 Cognito User Pool + Lambda (usa DynamoDB no Lambda)
  │     └── 10.2 Hosted UI DNS
  │           ├── 10.5 Callback Handler (precisa do Cognito domain + client_id)
  │           └── 10.6 Platform Frontend (precisa do Cognito client_id)
  └── 10.4 Discovery Service (lê DynamoDB)
10.7 Namespace customer1 + App
  └── 10.8 RequestAuthentication (precisa do pool-id do Cognito)
        └── 10.9 AuthorizationPolicy
10.10 WAF (independente, adiciona ao WebACL existente)
10.11 Teste (tudo acima concluído)
```

**Ordem recomendada:** 10.3 → 10.1 → 10.2 → 10.4 → 10.5 → 10.6 → 10.7 → 10.8 → 10.9 → 10.10 → 10.11

---

## Valores a preencher ao longo da implementação

| Variável | Onde usar | Valor |
|---|---|---|
| `<pool-id>` | Cognito, RequestAuthentication | a definir na etapa 10.1 |
| `<app-client-id>` | DynamoDB, Callback Handler, Frontend | a definir na etapa 10.1 |
| `<google-oauth-client-id>` | Cognito IdP config | a definir antes da 10.1 |
| `<google-oauth-client-secret>` | Cognito IdP config | a definir antes da 10.1 |
| `<cloudfront-domain>` | DNS auth.wasp.silvios.me | a definir na etapa 10.2 |
| `<state-jwt-secret>` | platform-frontend + callback-handler | gerar na etapa 10.5 |
