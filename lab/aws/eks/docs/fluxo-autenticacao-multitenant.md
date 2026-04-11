# Arquitetura de Autenticação Multi-tenant

> **Status:** Em revisão  
> **Contexto:** Complementa o lab EKS com ALB + Istio Gateway (`README.md`), descrevendo o design do fluxo de login para uma plataforma SaaS multi-tenant com suporte a múltiplos provedores de identidade (IdP).

---

## Visão geral

A plataforma `wasp.silvios.me` serve múltiplos tenants, cada um com seu próprio subdomínio e, potencialmente, seu próprio método de autenticação. O desafio central é: **como emitir um token padronizado para a plataforma independente de qual IdP o tenant usa?**

**Solução:** Cognito como camada de federação e normalização. Toda autenticação passa pelo Cognito, que federa com o IdP do tenant (Google, Microsoft, Okta, Auth0, Keycloak). A plataforma sempre recebe um JWT Cognito com claims padronizados — nunca o token do IdP upstream.

---

## Componentes adicionais ao lab

| Componente | Tipo | Papel |
|---|---|---|
| AWS Cognito User Pool | AWS | Hub de federação e normalização de tokens |
| Cognito App Client (por tenant) | AWS | Configuração do IdP por tenant |
| Cognito Hosted UI | AWS | UI de login em `auth.wasp.silvios.me` |
| Cognito Pre-Token Generation Lambda | AWS | Injeta `tenant_id` no JWT com base no App Client — não pode ser forjado pelo cliente |
| DynamoDB Global Table `tenant-registry` | AWS | Lookup: domínio de e-mail → config do tenant |
| DynamoDB Global Table `tenant-idp-config` | AWS | Configuração sensível do IdP por tenant |
| AWS Secrets Manager | AWS | Client secrets dos IdPs externos |
| Discovery Service | Kubernetes | Microserviço que consulta o DynamoDB via IRSA |
| Callback Handler | Kubernetes/Lambda | Troca code por tokens, emite cookie de sessão |

---

## Arquitetura do Cognito como IdP hub

```
                    ┌─────────────────────────────────┐
                    │         Cognito User Pool       │
                    │                                 │
                    │  App Client: customer1  ────────┼──► Google OIDC
                    │  App Client: customer2  ────────┼──► Microsoft OIDC/SAML
                    │  App Client: customer3  ────────┼──► Okta OIDC
                    │  App Client: customer4  ────────┼──► Auth0 OIDC
                    │  App Client: customer5  ────────┼──► Keycloak OIDC/SAML
                    │  App Client: customer6  ────────┼──► Cognito nativo
                    └─────────────────────────────────┘
                                    │
                          JWT Cognito (normalizado)
                                    │
                    ┌───────────────▼──────────────────┐
                    │   Istio RequestAuthentication    │
                    │   JWKS: Cognito (único issuer)   │
                    └──────────────────────────────────┘
```

---

## Topologia da plataforma

```
           sarah@customer1.com                        motoko@customer2.com
            (California, USA)                            (Tokyo, Japan)
                    │                                          │
                    └─────────────────────┬────────────────────┘
                                          ▼
                                   wasp.silvios.me
                                          │
                                Global Accelerator
                                          │
                    ┌─────────────────────┴────────────────────┐
                    ▼                                          ▼
           platform-us-east-1                         platform-ap-south-1
                    │                                          │
                    ▼                                          ▼
            discovery-service                          discovery-service
                    │                                          │
                    ▼                                          ▼
       customer1.wasp.silvios.me                    customer2.wasp.silvios.me
                    │                                          │
         ┌──────────┴─────────┐                                │
         ▼                    ▼                                ▼
customer1-us-east-1  customer1-us-west-1             customer2-ap-northeast-1
```

---

## Fluxo de autenticação

### Resumido

```
motoko@customer1.com (Tokyo, Japan)

GET https://wasp.silvios.me                  - Global Accelerator
  - platform-us-east-1.wasp.silvios.me       - US East (N. Virginia)
  - platform-sa-east-1.wasp.silvios.me       - South America (São Paulo)
  - platform-eu-central-1.wasp.silvios.me    - Europe (Frankfurt)
  > platform-ap-south-1.wasp.silvios.me      - Asia Pacific (Mumbai)

GET https://discovery.wasp.silvios.me/tenant?email=motoko@customer1.com
  - customer1.wasp.silvios.me

GET https://customer1.wasp.silvios.me        - Global Accelerator
  - customer1-ap-east-1.wasp.silvios.me      - Asia Pacific (Hong Kong)
  > customer1-ap-northeast-1.wasp.silvios.me - Asia Pacific (Tokyo)
```

### Expandido

```
1. GET https://wasp.silvios.me

   - Sem cookie → redirect /login


2. Usuário digita sarah@customer1.com

   - Frontend extrai domínio "customer1.com"


3. GET https://discovery.wasp.silvios.me/tenant?domain=customer1.com

   - DynamoDB lookup por "domain#customer1.com"

   - Retorna:

       {
         "client_id": "abc123",
         "tenant_url": "customer1.wasp.silvios.me",
         "idp_name": "Google",
         "idp_issuer": "https://accounts.google.com"
       }


4. Frontend monta URL do Cognito Hosted UI:

   POST https://auth.wasp.silvios.me/oauth2/authorize
     ?client_id=abc123
     &identity_provider=Google
     &redirect_uri=https://auth.wasp.silvios.me/callback
     &response_type=code
     &scope=openid+email+profile
     &state=<JWT assinado: tenant_id + nonce + return_url>


5. Cognito redireciona para o IdP configurado (Google/Microsoft/Okta/etc.)
   
   - O usuário autentica no IdP dele (UI do próprio IdP)


6. IdP retorna para Cognito com code

   - Cognito valida, mapeia atributos, emite tokens próprios

   - Cognito redireciona para auth.wasp.silvios.me/callback?code=...


7. Callback handler:

   - Troca code por tokens (POST /oauth2/token no Cognito)

   - Decodifica state → extrai tenant_id e return_url

   - set-cookie: session=<JWT> Domain=.wasp.silvios.me HttpOnly Secure SameSite=Lax

   - redirect para customer1.wasp.silvios.me


8. customer1.wasp.silvios.me recebe request com cookie

   - Istio RequestAuthentication valida JWT (JWKS do Cognito)

   - Istio AuthorizationPolicy exige JWT válido

   - App recebe claims: sub, email, custom:tenant_id, custom:groups
```

---

## Estrutura de dados — DynamoDB

### Tabela `tenant-registry` (DynamoDB Global Table)

Lookup rápido de domínio de e-mail para configuração do tenant. Replicada em todas as regiões do Global Accelerator para leitura local com latência mínima.

```json
// Google SSO
{
  "pk": "domain#customer1.com",
  "tenant_id": "customer1",
  "url": "customer1.wasp.silvios.me",
  "regions": ["us-east-1", "us-west-1"],
  "auth": {
    "type": "google_sso",
    "cognito_user_pool_id": "us-east-1_XXXXXX",
    "cognito_app_client_id": "abc123",
    "cognito_idp_name": "Google"
  },
  "status": "active"
}

// Microsoft Azure AD
{
  "pk": "domain#customer2.com",
  "tenant_id": "customer2",
  "url": "customer2.wasp.silvios.me",
  "regions": ["eu-central-1"],
  "auth": {
    "type": "microsoft",
    "cognito_app_client_id": "def456",
    "cognito_idp_name": "MicrosoftAD-Customer2",
    "idp_issuer": "https://login.microsoftonline.com/<azure-tenant-id>/v2.0"
  },
  "status": "active"
}

// Okta
{
  "pk": "domain#customer3.com",
  "tenant_id": "customer3",
  "url": "customer3.wasp.silvios.me",
  "regions": ["us-east-1"],
  "auth": {
    "type": "okta",
    "cognito_app_client_id": "ghi789",
    "cognito_idp_name": "Okta-Customer3",
    "idp_issuer": "https://customer3.okta.com"
  },
  "status": "active"
}

// Auth0
{
  "pk": "domain#customer4.com",
  "tenant_id": "customer4",
  "url": "customer4.wasp.silvios.me",
  "regions": ["us-east-1"],
  "auth": {
    "type": "auth0",
    "cognito_app_client_id": "jkl012",
    "cognito_idp_name": "Auth0-Customer4",
    "idp_issuer": "https://customer4.us.auth0.com"
  },
  "status": "active"
}

// Keycloak self-hosted
{
  "pk": "domain#customer5.com",
  "tenant_id": "customer5",
  "url": "customer5.wasp.silvios.me",
  "regions": ["us-east-1"],
  "auth": {
    "type": "keycloak",
    "cognito_app_client_id": "mno345",
    "cognito_idp_name": "Keycloak-Customer5",
    "idp_issuer": "https://auth.customer5.com/realms/prod"
  },
  "status": "active"
}
```

### Tabela `tenant-idp-config`

Dados sensíveis do IdP, separados para controle de acesso IAM granular. Apenas o callback handler tem permissão de leitura.

```json
{
  "pk": "tenant#customer3",
  "type": "okta",
  "client_id": "0oaXXXXXXX",
  "client_secret_arn": "arn:aws:secretsmanager:us-east-1:XXXX:secret:customer3-okta-secret",
  "scopes": ["openid", "email", "profile", "groups"],
  "attribute_mapping": {
    "email": "email",
    "name": "name",
    "groups": "custom:groups"
  }
}
```

---

## Integração com o lab existente

| Componente do lab | Papel no fluxo de autenticação |
|---|---|
| **ALB + `*.wasp.silvios.me`** | Roteia `auth.wasp.silvios.me` e `discovery.wasp.silvios.me` sem alteração no Ingress |
| **Istio `VirtualService`** | Configura CORS para chamadas cross-origin entre subdomínios |
| **Istio `RequestAuthentication`** | Valida JWT Cognito — JWKS único independente do IdP upstream |
| **Istio `AuthorizationPolicy`** | Bloqueia requisições sem JWT válido **e** rejeita JWTs de outros tenants via claim `custom:tenant_id` |
| **WAF** | Rate limiting em `/login` e `/callback` (endereça [SEC-007](security-issues/sec-007.md)) |
| **IRSA** | Discovery service com permissão de leitura no DynamoDB; callback handler com acesso ao Secrets Manager |

### Configuração do Istio RequestAuthentication

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: cognito-jwt
  namespace: istio-ingress
spec:
  jwtRules:
    - issuer: "https://cognito-idp.us-east-1.amazonaws.com/<pool-id>"
      jwksUri: "https://cognito-idp.us-east-1.amazonaws.com/<pool-id>/.well-known/jwks.json"
      forwardOriginalToken: true
```

---

## Isolamento de tenant via JWT claims

A validação da assinatura do JWT (`RequestAuthentication`) garante que o token é legítimo, mas **não impede** que um JWT válido de `customer2` seja usado para tentar acessar recursos de `customer1`. O isolamento real é aplicado em duas camadas complementares.

### 1. Injeção do `tenant_id` no JWT — Cognito Pre-Token Generation Lambda

Cada App Client no Cognito está associado a exatamente um tenant. Um Lambda trigger de pré-geração de token injeta o `tenant_id` correto no JWT com base no `clientId` usado na autenticação — o cliente não tem como forjar esse valor:

```python
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tenant-registry')

def handler(event, context):
    client_id = event['callerContext']['clientId']

    # Busca tenant_id pelo App Client ID (GSI na tabela)
    response = table.query(
        IndexName='client-id-index',
        KeyConditionExpression='cognito_app_client_id = :cid',
        ExpressionAttributeValues={':cid': client_id}
    )

    tenant_id = response['Items'][0]['tenant_id']

    event['response']['claimsOverrideDetails'] = {
        'claimsToAddOrOverride': {
            'custom:tenant_id': tenant_id
        }
    }
    return event
```

### 2. Enforcement no Istio — AuthorizationPolicy por namespace

Cada namespace de tenant tem sua própria `AuthorizationPolicy` que exige que o claim `tenant_id` do JWT corresponda ao tenant do namespace. Quando existe pelo menos uma `AuthorizationPolicy` num namespace, o Istio nega tudo que não for explicitamente permitido.

```yaml
# namespace: customer1
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
          values: ["customer1"]  # só JWTs com custom:tenant_id=customer1 são aceitos
```

```yaml
# namespace: customer2 — mesma estrutura, valor diferente
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-tenant-jwt
  namespace: customer2
spec:
  action: ALLOW
  rules:
    - when:
        - key: request.auth.claims[custom:tenant_id]
          values: ["customer2"]
```

### Cenário de ataque mitigado

```
sarah@customer1.com autentica → recebe JWT com tenant_id=customer1

Tentativa de acesso cruzado:
  GET https://customer2.wasp.silvios.me/api/data
  Cookie: session=<JWT de customer1>

Camadas de defesa:
  1. ALB roteia customer2.wasp.silvios.me → Istio IngressGateway  ✓
  2. RequestAuthentication valida assinatura do JWT               ✓ (JWT é válido)
  3. AuthorizationPolicy verifica tenant_id == "customer2"        ✗ BLOQUEADO
     → HTTP 403
```

O token é criptograficamente válido — mas o `tenant_id` errado o torna inútil fora do namespace do próprio tenant.

### Defesa em profundidade

| Camada | Mecanismo | O que valida |
|---|---|---|
| ALB | Host-based routing | Subdomínio correto chega ao cluster |
| Istio IngressGateway | `VirtualService` por Host | Roteamento para o namespace do tenant correto |
| Istio `RequestAuthentication` | JWKS do Cognito | Assinatura e expiração do JWT |
| Istio `AuthorizationPolicy` | Claim `tenant_id` | JWT pertence ao tenant dono do namespace |

---

## Desafios por tipo de IdP

### Google e Microsoft
- Configuração mais simples — suporte OIDC nativo no Cognito
- Microsoft: cada empresa tem seu próprio Azure AD tenant com `issuer` diferente (`https://login.microsoftonline.com/<tenant-id>/v2.0`) — cada App Client aponta para o issuer correto

### Okta e Auth0
- Funcionam como OIDC providers completos — Cognito os vê como IdP externo via OIDC federation
- Auth0 pode agregar outros IdPs internamente — o Cognito vê só o Auth0, não o IdP upstream
- Mapeamento de custom claims (grupos, roles) requer configuração de attribute mapping no Cognito

### Keycloak self-hosted
- Suporte OIDC ou SAML — OIDC é preferível
- **Risco crítico:** requer conectividade de rede entre AWS e o servidor do customer
  - Opção 1: Customer expõe Keycloak publicamente com TLS
  - Opção 2: AWS PrivateLink + VPN site-to-site
  - Opção 3: Customer migra para Keycloak Cloud (managed)
- Se o Keycloak do customer ficar indisponível, o login do tenant inteiro quebra — **SLA da plataforma fica acoplado à infra do customer**

---

## Desafios e resoluções

| Desafio | Impacto | Resolução |
|---|---|---|
| CORS entre `wasp.silvios.me` e `customer1.wasp.silvios.me` | Requisições AJAX bloqueadas | Redirecionamentos OAuth não sofrem CORS; para AJAX, configurar `Access-Control-Allow-Origin` no Istio `VirtualService` |
| Redirect URI do Google/Microsoft requer pré-cadastro | Não escala com N tenants | Callback centralizado `auth.wasp.silvios.me/callback` — única URI registrada em todos os IdPs |
| Cognito: limite de 300 IdPs externos por User Pool | Teto de ~300 tenants por pool | Múltiplos User Pools por região ou tier |
| Atributos customizados variam por IdP | JWT com campos inconsistentes | Attribute mapping no Cognito + schema fixo de claims na plataforma |
| Renovação de tokens cross-domain | Cookie `.wasp.silvios.me` expira, refresh transparente necessário | Callback handler centralizado gerencia refresh; aplicação não precisa implementar |
| Keycloak/IdP indisponível | Login quebrado para o tenant | Health check do IdP no discovery + página de erro contextualizada por tenant |
| JWT de customer1 usado para acessar customer2 | Vazamento de dados entre tenants | `AuthorizationPolicy` por namespace valida `tenant_id` claim — JWT válido mas de tenant errado recebe HTTP 403 |
| Onboarding de novo tenant | Criar App Client + configurar IdP + registrar no DynamoDB | API de onboarding (Lambda + DynamoDB + Cognito SDK) — ponto mais operacional do sistema |

---

## Contratos de API

### Discovery Service — `GET /tenant`

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

### Callback Handler — `GET /callback`

```
GET /callback?code=<code>&state=<state-jwt>

1. Decodifica state JWT → { tenant_id, nonce, return_url }
2. POST https://idp.wasp.silvios.me/oauth2/token
     grant_type=authorization_code
     code=<code>
     client_id=<app-client-id>
     redirect_uri=https://auth.wasp.silvios.me/callback
3. Recebe id_token (JWT Cognito com custom:tenant_id)
4. Valida que token.tenant_id == state.tenant_id
5. Set-Cookie: session=<id_token>; Domain=.wasp.silvios.me; HttpOnly; Secure; SameSite=Lax
6. 302 → https://<return_url>
```

---

## Decisões em aberto

Ver [decisoes-tecnicas.md](decisoes-tecnicas.md) para o registro detalhado de cada decisão pendente e os trade-offs considerados.
