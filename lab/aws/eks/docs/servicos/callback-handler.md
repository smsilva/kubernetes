# Callback Handler

> Processador de callback OAuth 2.0. Recebe o authorization code do Cognito, valida o state JWT, troca o code por tokens, verifica o isolamento de tenant e emite o cookie de sessão.

## Responsabilidade

É o único serviço que toca tokens de autenticação reais. Etapas em ordem:

1. Decodifica e valida o **state JWT** (proteção CSRF)
2. Lê o `client_secret` do tenant a partir de variável de ambiente
3. Troca o **authorization code** por `id_token`, `access_token` e `refresh_token` via POST no Cognito
4. Extrai o domínio do e-mail do `id_token` (decode sem verificação de assinatura — o JWT vem do Cognito, mas a assinatura é verificada depois pelo Istio)
5. Consulta o **Discovery Service** para obter o `tenant_id` do domínio
6. Compara o `tenant_id` do Discovery com o `tenant_id` do state JWT — se divergirem, retorna 403
7. Emite o **cookie de sessão** `session=<id_token>` com atributos de segurança
8. Redireciona para a `return_url` do state JWT

## API

### `GET /callback`

Recebe o retorno do Cognito após autenticação do usuário.

**Query parameters:**

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `code` | string | sim | Authorization code emitido pelo Cognito |
| `state` | string | sim | State JWT assinado pelo `platform-frontend` |

**Respostas:**

| Condição | Status | Resposta |
|---|---|---|
| State JWT inválido ou expirado | 400 | Renderiza `error.html` |
| Tenant não configurado no serviço | 500 | Renderiza `error.html` |
| Falha na troca de code por token | 400 | Renderiza `error.html` |
| Domínio do e-mail não registrado | 400 | Renderiza `error.html` |
| `tenant_id` do token ≠ `tenant_id` do state | 403 | Renderiza `error.html` |
| Sucesso | 302 | Redirect para `return_url` + `Set-Cookie: session=<id_token>` |

### `GET /health`

```json
{"status": "ok"}
```

## Validação do state JWT

Implementada em `services/callback-handler/app/state.py` (`decode_state_token`):

- Decodifica com `STATE_JWT_SECRET` (HS256)
- Campos esperados: `tenant_id`, `client_id`, `return_url`, `nonce`
- `jwt.ExpiredSignatureError` e `jwt.InvalidTokenError` levantam `InvalidStateError` → HTTP 400

## Troca de código por tokens — CognitoClient

Implementada em `services/callback-handler/app/cognito.py`.

`POST https://<COGNITO_DOMAIN>/oauth2/token` com:

```
grant_type=authorization_code
code=<code recebido do Cognito>
client_id=<client_id do state JWT>
redirect_uri=<CALLBACK_URL>
Authorization: Basic <base64(client_id:client_secret)>
```

Retorna `CognitoTokens(id_token, access_token, refresh_token)`. Falha HTTP ≠ 200 levanta `CognitoTokenExchangeError` → HTTP 400.

## Validação cruzada de domínio — DomainValidator

Implementada em `services/callback-handler/app/domain_validator.py`.

Chama `GET <DISCOVERY_URL>/tenant?domain=<domínio>` e retorna o `tenant_id` do Discovery.

**Por que isso importa:** impede que um JWT válido de `customer1` seja usado para acessar `customer2`. O e-mail extraído do token pertence a um domínio, e o domínio está registrado em exatamente um tenant. Se o `tenant_id` retornado pelo Discovery diferir do `tenant_id` presente no state JWT, o callback retorna 403.

## Secrets por tenant

Cada tenant tem seu próprio `client_secret` armazenado como variável de ambiente seguindo a convenção:

```
COGNITO_CLIENT_SECRET_<TENANT_ID_UPPERCASE>
```

Exemplo:

```python
tenant_key = login_state.tenant_id.upper()  # "customer1" → "CUSTOMER1"
client_secret = os.environ[f"COGNITO_CLIENT_SECRET_{tenant_key}"]
```

Injetadas via Kubernetes Secret `callback-handler-secret` no namespace `auth`.

!!! warning "Adicionar tenant = rollout manual"
    Adicionar um novo tenant exige editar o Secret `callback-handler-secret` e fazer rollout do deployment. A solução para produção (AWS Secrets Manager ou Parameter Store por tenant) está documentada em [decisoes-tecnicas.md](../decisoes-tecnicas.md).

## Cookie de sessão

```
Set-Cookie: session=<id_token>
  HttpOnly   — inacessível a JavaScript
  Secure     — apenas HTTPS
  SameSite=Lax — proteção CSRF básica
  Domain=.wasp.silvios.me — válido para todos os subdomínios da plataforma
```

O valor do cookie é o `id_token` JWT do Cognito. O Istio `RequestAuthentication` no namespace do tenant valida esse JWT via JWKS URI do Cognito (verificação de assinatura RS256).

## Variáveis de ambiente

| Variável | Descrição |
|---|---|
| `COGNITO_DOMAIN` | Hostname do Cognito — **sem `https://`** (ex: `idp.wasp.silvios.me`) |
| `CALLBACK_URL` | URL registrada como `redirect_uri` no App Client |
| `DISCOVERY_URL` | URL base do Discovery Service |
| `STATE_JWT_SECRET` | Segredo compartilhado com `platform-frontend` |
| `COGNITO_CLIENT_SECRET_CUSTOMER1` | Client secret do App Client do customer1 |
| `COGNITO_CLIENT_SECRET_CUSTOMER2` | Client secret do App Client do customer2 |
| `COGNITO_CLIENT_SECRET_<TENANT>` | Um por tenant — convenção `TENANT_ID_UPPERCASE` |

## Gotcha — pipe + heredoc conflita com stdin

!!! warning "stdin"
    Pipe (`|`) e heredoc (`<<EOF`) disputam o stdin. O heredoc vence. Se um script precisar gravar uma variável via heredoc **e** o código Python ler stdin, gravar o conteúdo em arquivo temporário e ler via `open()`.

## Namespace e deploy K8s

- **Namespace:** `auth`
- **Imagem:** `silviosilva/wasp-callback-handler:<sha>`
- **Secret:** `callback-handler-secret` (client secrets dos tenants + STATE_JWT_SECRET)
- **ConfigMap:** COGNITO_DOMAIN, CALLBACK_URL, DISCOVERY_URL

## Testes

```bash
cd lab/aws/eks/services/callback-handler
.venv/bin/pytest tests/ -v
```

- `test_callback.py` — testa `GET /callback` com overrides de `CognitoClient` e `DomainValidator`
- `test_state.py` — testa `decode_state_token` (token válido, expirado, inválido)
