# Onboarding de Novo Customer

Este documento descreve os passos para cadastrar um novo tenant na plataforma, incluindo a configuração do IdP no Cognito, o registro no DynamoDB e o deploy do namespace isolado no cluster.

---

## Visão geral

Cada tenant é identificado por um ou mais domínios de e-mail. Ao fazer login, o `platform-frontend` extrai o domínio do e-mail, consulta o `discovery service` (DynamoDB) e redireciona para o IdP correto via Cognito.

O onboarding envolve três camadas:

```
1. IdP no Cognito     — credenciais OAuth do provedor de identidade do customer
2. DynamoDB           — mapeamento domínio → tenant_id → App Client
3. Kubernetes         — namespace isolado com Istio auth (RequestAuthentication + AuthorizationPolicy)
```

---

## Decisão inicial: IdP novo ou existente?

Antes de começar, responda:

> **O customer usa um IdP já cadastrado na plataforma (mesmo Client ID e Client Secret)?**

| Situação | Caminho |
|---|---|
| IdP novo (credenciais próprias) | Executar todos os passos abaixo |
| IdP compartilhado (mesmo Client ID já cadastrado) | Pular o Passo 1; registrar apenas o domínio adicional no DynamoDB apontando para o App Client existente |

O caso de IdP compartilhado está detalhado na seção [Múltiplos domínios no mesmo IdP](#multiplos-dominios-no-mesmo-idp).

---

## Passo 1 — Configurar o IdP no Cognito

### 1.1 Determinar o tipo de IdP

| Tipo | `provider-type` na AWS CLI | Quando usar |
|---|---|---|
| Google (conta pessoal / Workspace) | `OIDC` com `oidc_issuer=https://accounts.google.com` | Máximo um IdP do tipo `Google` (social) por User Pool — usar OIDC para os demais |
| Microsoft (contas pessoais MSA) | `OIDC` com issuer GUID fixo `9188040d-6c67-4c5b-b112-36a304b66dad` | Ver `docs/decisoes-tecnicas.md` |
| Microsoft (Azure AD corporativo / Google Workspace federado via AD) | `OIDC` com `oidc_issuer=https://login.microsoftonline.com/<tenant-id>/v2.0` | Usar o tenant ID real da organização |
| Qualquer outro provedor OIDC | `OIDC` | Okta, Auth0, Keycloak, etc. |

### 1.2 Pré-requisitos no provedor de identidade

Antes de executar qualquer script, registrar a aplicação no console do provedor e obter:

- `CLIENT_ID`
- `CLIENT_SECRET`
- Redirect URI obrigatória: `https://idp.<domain>/oauth2/idpresponse`

> Para Google, o redirect URI fica em **Authorized redirect URIs** (não em Authorized JavaScript origins). Mudanças levam até 5 minutos para propagar.

### 1.3 Criar o IdP no Cognito

```bash
export CUSTOMER_CLIENT_ID=<client-id do provedor>
export CUSTOMER_CLIENT_SECRET=<client-secret>

idp_name="<NomeIdP-CustomerN>"          # ex: Google-Customer3, AzureAD-Customer4
oidc_issuer="<issuer do provedor>"
tenant_id="customerN"                    # ex: customer3

aws cognito-idp create-identity-provider \
  --region "${aws_region}" \
  --user-pool-id "${cognito_user_pool_id}" \
  --provider-name "${idp_name}" \
  --provider-type OIDC \
  --provider-details \
    "client_id=${CUSTOMER_CLIENT_ID},client_secret=${CUSTOMER_CLIENT_SECRET},authorize_scopes=openid email profile,oidc_issuer=${oidc_issuer},attributes_request_method=GET" \
  --attribute-mapping \
    "email=email,name=name"
```

### 1.4 Criar o App Client no Cognito

```bash
app_client_id=$(
  aws cognito-idp create-user-pool-client \
    --region "${aws_region}" \
    --user-pool-id "${cognito_user_pool_id}" \
    --client-name "${tenant_id}" \
    --generate-secret \
    --supported-identity-providers "${idp_name}" \
    --allowed-o-auth-flows code \
    --allowed-o-auth-scopes openid email profile \
    --callback-urls "https://auth.${domain}/callback" \
    --logout-urls "https://${tenant_id}.${domain}/logout" \
    --allowed-o-auth-flows-user-pool-client \
    --query 'UserPoolClient.ClientId' \
    --output text
)
```

### 1.5 Recuperar o Client Secret do App Client

```bash
export COGNITO_CUSTOMERX_CLIENT_SECRET=$(
  aws cognito-idp describe-user-pool-client \
    --region "${aws_region}" \
    --user-pool-id "${cognito_user_pool_id}" \
    --client-id "${app_client_id}" \
    --query UserPoolClient.ClientSecret \
    --output text
)
```

---

## Passo 2 — Registrar o domínio no DynamoDB

Cada domínio de e-mail recebe um item no `tenant-registry`. A chave primária é `domain#<domínio>`.

```bash
tenant_domain="<domínio do e-mail>"      # ex: empresa.com
tenant_url="${tenant_id}.${domain}"       # ex: customer3.wasp.silvios.me

item=$(cat <<EOF
{
  "pk":                    {"S": "domain#${tenant_domain}"},
  "tenant_id":             {"S": "${tenant_id}"},
  "url":                   {"S": "${tenant_url}"},
  "regions":               {"L": [{"S": "${aws_region}"}]},
  "cognito_app_client_id": {"S": "${app_client_id}"},
  "auth": {"M": {
    "type":                  {"S": "oidc"},
    "cognito_user_pool_id":  {"S": "${cognito_user_pool_id}"},
    "cognito_app_client_id": {"S": "${app_client_id}"},
    "cognito_idp_name":      {"S": "${idp_name}"}
  }},
  "status": {"S": "active"}
}
EOF
)

aws dynamodb put-item \
  --region "${aws_region}" \
  --table-name "tenant-registry" \
  --item "${item}"
```

### Verificar

```bash
curl "https://discovery.${domain}/tenant?domain=${tenant_domain}"
```

---

## Passo 3 — Atualizar o callback-handler

O `callback-handler` precisa conhecer o Client Secret de cada tenant para trocar o code pelo token.

Adicionar a nova chave ao Secret existente:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: callback-handler-secret
  namespace: auth
type: Opaque
stringData:
  COGNITO_CLIENT_SECRET_CUSTOMER1: "${COGNITO_CLIENT_SECRET}"
  COGNITO_CLIENT_SECRET_CUSTOMER2: "${COGNITO_CUSTOMER2_CLIENT_SECRET}"
  COGNITO_CLIENT_SECRET_CUSTOMERX: "${COGNITO_CUSTOMERX_CLIENT_SECRET}"   # novo
  STATE_JWT_SECRET: "${STATE_JWT_SECRET}"
EOF

kubectl -n auth rollout restart deployment/callback-handler
kubectl -n auth rollout status deployment/callback-handler --timeout=180s
```

---

## Passo 4 — Deploy do namespace do tenant

Cada tenant tem um namespace isolado com Istio `RequestAuthentication` + `AuthorizationPolicy`.

```bash
jwt_issuer="https://cognito-idp.${aws_region}.amazonaws.com/${cognito_user_pool_id}"
jwks_uri="${jwt_issuer}/.well-known/jwks.json"

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${tenant_id}
  labels:
    istio-injection: enabled
---
# ... Deployment, Service, Gateway, VirtualService da aplicação do tenant ...
---
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: cognito-jwt
  namespace: ${tenant_id}
spec:
  jwtRules:
    - issuer: "${jwt_issuer}"
      jwksUri: "${jwks_uri}"
      forwardOriginalToken: true
      fromCookies:
        - session
      fromHeaders:
        - name: Authorization
          prefix: "Bearer "
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-tenant-jwt
  namespace: ${tenant_id}
spec:
  action: ALLOW
  rules:
    - when:
        - key: request.auth.claims[custom:tenant_id]
          values: ["${tenant_id}"]
EOF
```

O `AuthorizationPolicy` garante que um JWT emitido para outro tenant seja rejeitado com 403 neste namespace — isolamento cruzado por design.

---

## Verificação end-to-end

```bash
# 1. Sem JWT → deve retornar 403
curl -s -o /dev/null -w '%{http_code}' "https://${tenant_id}.${domain}/get"

# 2. JWT de outro tenant → deve retornar 403
curl -s -o /dev/null -w '%{http_code}' \
  -b "session=<JWT de outro tenant>" \
  "https://${tenant_id}.${domain}/get"

# 3. Fluxo completo via browser
# Acessar https://<domain> → digitar e-mail do novo domínio → autenticar → chegar em <tenant_id>.<domain>
```

---

## Múltiplos domínios no mesmo IdP

Quando dois ou mais domínios compartilham o mesmo provedor de identidade (mesmo Client ID e Client Secret — por exemplo, grupos empresariais onde todas as empresas estão no mesmo diretório corporativo), **não é necessário criar um novo IdP nem um novo App Client no Cognito**.

Neste caso:

### O que muda

| Etapa | Ação |
|---|---|
| Passo 1 (IdP + App Client) | **Pular** — reaproveitar o App Client existente do tenant principal |
| Passo 2 (DynamoDB) | **Executar** — registrar o novo domínio apontando para o `tenant_id` e `app_client_id` existentes |
| Passo 3 (callback-handler) | **Pular** — o secret já existe |
| Passo 4 (namespace) | Depende: se o novo domínio pertence ao **mesmo tenant** (mesma aplicação), pular. Se for um tenant lógico separado com namespace próprio, executar com um novo `tenant_id` |

### Registrar o domínio adicional

```bash
novo_dominio="<segundo domínio>"         # ex: subsidiaria.com
tenant_id_existente="<tenant existente>" # ex: customer3
app_client_id_existente="<client_id>"

item=$(cat <<EOF
{
  "pk":                    {"S": "domain#${novo_dominio}"},
  "tenant_id":             {"S": "${tenant_id_existente}"},
  "url":                   {"S": "${tenant_id_existente}.${domain}"},
  "regions":               {"L": [{"S": "${aws_region}"}]},
  "cognito_app_client_id": {"S": "${app_client_id_existente}"},
  "auth": {"M": {
    "type":                  {"S": "oidc"},
    "cognito_user_pool_id":  {"S": "${cognito_user_pool_id}"},
    "cognito_app_client_id": {"S": "${app_client_id_existente}"},
    "cognito_idp_name":      {"S": "<idp_name do tenant existente>"}
  }},
  "status": {"S": "active"}
}
EOF
)

aws dynamodb put-item \
  --region "${aws_region}" \
  --table-name "tenant-registry" \
  --item "${item}"
```

### Resultado

Usuários de ambos os domínios (`empresa.com` e `subsidiaria.com`) são roteados para o mesmo App Client no Cognito, passam pelo mesmo IdP e chegam ao mesmo namespace de aplicação. A Lambda Pre-Token Generation injeta o `custom:tenant_id` baseado no App Client ID — ambos os domínios recebem o mesmo `tenant_id` no JWT.

> **Atenção:** se os dois domínios precisarem de isolamento lógico (namespaces diferentes, AuthorizationPolicies diferentes), criar um App Client separado para cada tenant lógico, mesmo que compartilhem o IdP. O App Client é a unidade de isolamento no Cognito.

---

## Referência rápida — checklist de onboarding

```
[ ] Registrar a aplicação no console do provedor de identidade
    [ ] Obter CLIENT_ID e CLIENT_SECRET
    [ ] Adicionar redirect URI: https://idp.<domain>/oauth2/idpresponse

[ ] Passo 1 — Cognito (pular se IdP já existe)
    [ ] Criar IdP (create-identity-provider)
    [ ] Criar App Client (create-user-pool-client)
    [ ] Salvar COGNITO_CUSTOMERX_CLIENT_SECRET

[ ] Passo 2 — DynamoDB
    [ ] Registrar cada domínio de e-mail do tenant (put-item)
    [ ] Verificar: curl discovery/tenant?domain=<domínio>

[ ] Passo 3 — callback-handler
    [ ] Adicionar COGNITO_CLIENT_SECRET_CUSTOMERX ao Secret (pular se IdP compartilhado)
    [ ] Reiniciar deployment callback-handler

[ ] Passo 4 — Kubernetes
    [ ] Criar namespace com istio-injection: enabled
    [ ] Deploy da aplicação do tenant
    [ ] RequestAuthentication (validar JWT Cognito)
    [ ] AuthorizationPolicy (custom:tenant_id == "<tenant_id>")

[ ] Verificação
    [ ] Sem JWT → 403
    [ ] JWT de outro tenant → 403
    [ ] Fluxo completo via browser
```
