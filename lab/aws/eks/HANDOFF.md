# HANDOFF — Ambiente Local com k3d

## Goal

`lab/aws/eks/local/` — versão offline do lab AWS EKS usando k3d, sem dependências de cloud.
Permite desenvolver e testar os serviços Python localmente sem AWS.

## Current Progress

**Lab local: completo.**

| Script | Status |
|---|---|
| `env.conf` | ✅ |
| `bootstrap` | ✅ |
| `01-create-cluster` | ✅ |
| `02-install-haproxy-ingress` | ✅ |
| `03-install-cert-manager` | ✅ |
| `04-install-istio` | ✅ |
| `05-deploy-keycloak` | ✅ |
| `06-deploy-services` | ✅ |
| `07-configure-istio-auth` | ✅ |
| `08-deploy-customer2` | ✅ |
| `destroy` | ✅ |
| `docs/diferencas-aws.md` | ✅ |

**Serviços modificados (TDD, AWS intacto):**

| Serviço | Mudança |
|---|---|
| `discovery` | `SQLiteTenantRepository` + `BACKEND=sqlite\|dynamodb` (default `dynamodb`) + `SQLITE_SEED_FILE` |
| `platform-frontend` | `IDP_AUTHORIZE_URL` opcional; `identity_provider` omitido quando `idp_name=""`; `tenant_url` usado as-is quando já tem scheme |
| `callback-handler` | `IDP_TOKEN_URL` opcional para substituir URL do Cognito |

**Testes:** 16 (platform-frontend) + 34 (discovery) + 24 (callback-handler) = 74 passando.

**Commits:**
- `d6afefd` — `feat(eks/local): add local k3d lab and extend services for offline operation`
- `62e60a5` — `docs(eks): add notes on local lab plan and HANDOFF`

Branch: `dev`. Push pendente (não fazer push sem instrução explícita do usuário).

## What Worked

- HAProxy Ingress em vez de Nginx (deprecated) — `NodePort 32080`
- Keycloak com `frontendUrl` explícito no realm → `iss` determinístico no JWT
- `k3d image import` + `imagePullPolicy: Never` (sem Docker Hub)
- `IDP_TOKEN_URL` aponta para service interno do cluster (`keycloak.keycloak.svc.cluster.local:8080`) para o callback-handler — evita round-trip pelo HAProxy
- `tenant_url` no seed com URL completa (`http://customer1.wasp.local:32080`) — resolve o bug de `https://` hardcoded no `platform-frontend`

## What Didn't Work / Gotchas

- **Porto `32080:80@loadbalancer` conflitava** com `9080:80@loadbalancer` — corrigido para `32080:32080@loadbalancer` (HAProxy NodePort)
- **`frontendUrl` ausente no realm Keycloak** → `iss` no JWT calculado a partir do Host header, não determinístico. Fixado em `05-deploy-keycloak`.
- **`KEYCLOAK_CLIENT_SECRET` vs `keycloak_client_secret`** — convenção de nome inconsistente; `05` agora salva automaticamente em `env.secrets` como `KEYCLOAK_CLIENT_SECRET` (uppercase).
- **SQLite carrega seed só na inicialização** — `08-deploy-customer2` faz `rollout restart` após atualizar o ConfigMap `discovery-seed`.
- **`test_post_login_omits_identity_provider`**: override de dependency dentro do body do teste era não-confiável — movido para fixture `yield` no `conftest.py`.

## Next Steps

O lab está completo para execução. Os possíveis próximos passos são:

1. **Executar o lab e validar o fluxo end-to-end** — rodar os scripts na ordem e fazer login com `user1@customer1.com` / `user2@customer2.com`
2. **Adicionar Ingress HAProxy para Keycloak** em `05-deploy-keycloak` — atualmente só via port-forward; em produção o Keycloak precisa de Ingress para ser acessível via `idp.wasp.local:32080`
3. **Push do branch `dev`** quando pronto

## Key Files

| Arquivo | Relevância |
|---|---|
| `local/scripts/env.conf` | Config global do lab local (domínio, portas, credenciais Keycloak) |
| `local/scripts/env.secrets` | Gerado em runtime — `KEYCLOAK_CLIENT_SECRET`, `STATE_JWT_SECRET` |
| `local/docs/diferencas-aws.md` | Mapa completo de substituições e gotchas locais |
| `scripts/13-deploy-services` | Referência original para o `06-deploy-services` local |
| `scripts/14-configure-istio-auth` | Referência original para o `07-configure-istio-auth` local |
| `CLAUDE.md` | Contexto do lab AWS (domínios, credenciais, regras de TDD) |

## Context

- Diretório local: `lab/aws/eks/local/` (junto aos serviços, coexiste com `lab/aws/eks/scripts/`)
- Domínio local: `wasp.local` (porta `32080` para acesso externo)
- `/etc/hosts`: `127.0.0.1` para `wasp.local`, `auth.wasp.local`, `discovery.wasp.local`, `idp.wasp.local`, `customer1.wasp.local`, `customer2.wasp.local`
- customer1 e customer2 usam o mesmo client Keycloak (`wasp-platform`) — isolamento via `custom:tenant_id`
- Regra do projeto: TDD — testes antes de qualquer alteração nos serviços
- Nunca fazer push sem instrução explícita
