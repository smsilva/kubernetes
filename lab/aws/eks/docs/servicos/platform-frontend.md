# Platform Frontend

> Frontend de login da plataforma. Recebe o e-mail do usuário, consulta o Discovery Service e redireciona para o Cognito Hosted UI do tenant correspondente.

## Responsabilidade

Ponto de entrada do usuário. Funciona como "IdP router": não autentica o usuário diretamente — apenas descobre qual IdP usar e inicia o OAuth 2.0 Authorization Code Flow redirecionando para o Cognito correto.

## Fluxo de login

1. Usuário acessa `https://wasp.silvios.me` → `GET /` renderiza `login.html`
2. Usuário digita o e-mail e submete o formulário → `POST /login`
3. O serviço valida o formato do e-mail e extrai o domínio
4. Chama `GET /tenant?domain=<domínio>` no Discovery Service
5. Monta o state JWT com `tenant_id`, `client_id`, `return_url` e `nonce` (expira em 10 min, HS256)
6. Monta a URL de autorização do Cognito com `identity_provider`, `scope`, `state`, `redirect_uri`
7. Retorna `HTTP 302` → Cognito Hosted UI

## API

### `GET /`

Renderiza `login.html`. Não requer autenticação.

### `POST /login`

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `email` | string (form) | sim | E-mail do usuário |

**Comportamento:**

| Condição | Resposta |
|---|---|
| E-mail sem `@` ou sem `.` no domínio | Re-renderiza login com mensagem de erro |
| Domínio não encontrado no Discovery | Re-renderiza login com mensagem de erro |
| Domínio encontrado | `HTTP 302` → Cognito Hosted UI |

### `GET /health`

```json
{"status": "ok"}
```

## State JWT

O state JWT é a proteção CSRF do OAuth flow. Definido em `services/platform-frontend/app/auth.py`:

| Campo | Tipo | Descrição |
|---|---|---|
| `tenant_id` | string | ID do tenant (ex: `customer1`) |
| `client_id` | string | Cognito App Client ID do tenant |
| `return_url` | string | URL de destino pós-login (`https://<tenant_url>`) |
| `nonce` | string | 16 bytes urlsafe aleatórios — unicidade por request |
| `exp` | timestamp | Expira em 10 minutos |

- **Algoritmo:** HS256
- **Segredo:** `STATE_JWT_SECRET` — compartilhado com `callback-handler`

## URL de autorização do Cognito

Parâmetros montados por `build_cognito_authorize_url()` em `auth.py`:

| Parâmetro | Valor |
|---|---|
| `client_id` | Cognito App Client ID do tenant |
| `identity_provider` | Nome do IdP no Cognito (ex: `Google`, `MicrosoftAD-Customer2`) |
| `redirect_uri` | `https://auth.wasp.silvios.me/callback` |
| `response_type` | `code` |
| `scope` | `openid email profile` |
| `state` | State JWT assinado |

URL montada: `https://<COGNITO_DOMAIN>/oauth2/authorize?<params>`

## Variáveis de ambiente

| Variável | Descrição |
|---|---|
| `DISCOVERY_URL` | URL base do Discovery Service (ex: `https://discovery.wasp.silvios.me`) |
| `COGNITO_DOMAIN` | Hostname do Cognito — **sem `https://`** (ex: `idp.wasp.silvios.me`) |
| `CALLBACK_URL` | URL de callback OAuth (ex: `https://auth.wasp.silvios.me/callback`) |
| `STATE_JWT_SECRET` | Segredo compartilhado com `callback-handler` |

!!! warning "`COGNITO_DOMAIN` sem `https://`"
    O código em `auth.py` adiciona o scheme `https://` ao montar a URL. Se `COGNITO_DOMAIN` for `https://idp.wasp.silvios.me`, o redirect gerado será `https://https://idp...` e o login quebrará.

## Namespace e deploy K8s

- **Namespace:** `platform`
- **Imagem:** `silviosilva/wasp-platform-frontend:<sha>`
- **ConfigMap:** `platform-frontend-config` (DISCOVERY_URL, COGNITO_DOMAIN, CALLBACK_URL)
- **Secret:** `platform-frontend-secret` (STATE_JWT_SECRET)

## Testes

```bash
cd lab/aws/eks/services/platform-frontend
.venv/bin/pytest tests/ -v
```

- `test_login_page.py` — testa `GET /`, `POST /login` (e-mail inválido, domínio não encontrado, domínio encontrado com redirect correto)
