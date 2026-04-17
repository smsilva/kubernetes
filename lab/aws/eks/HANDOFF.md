# HANDOFF — Ambiente Local com k3d

## Goal

`lab/aws/eks/local/` — versão offline do lab AWS EKS usando k3d, sem dependências de cloud.
Permite desenvolver e testar os serviços Python localmente sem AWS.

## Current Progress

**Lab local: completo e validado end-to-end.**

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
| `docs/lessons-learned.md` | ✅ |

**Serviços modificados (TDD, AWS intacto):**

| Serviço | Mudança |
|---|---|
| `discovery` | `SQLiteTenantRepository` + `BACKEND=sqlite\|dynamodb` (default `dynamodb`) + `SQLITE_SEED_FILE` |
| `platform-frontend` | `IDP_AUTHORIZE_URL` opcional; `identity_provider` omitido quando `idp_name=""`; `tenant_url` usado as-is quando já tem scheme |
| `callback-handler` | `IDP_TOKEN_URL` opcional; `COOKIE_SECURE` e `COOKIE_DOMAIN` configuráveis por env var |

**Testes:** 16 (platform-frontend) + 34 (discovery) + 26 (callback-handler) = 76 passando.

**Fluxo end-to-end validado:**

```
POST /login (user1@customer1.com)
  → 302 → Keycloak login page
  → POST credentials
  → 302 → /callback?code=...&state=...
  → 302 → customer1.wasp.local:32080 + set-cookie: session=<JWT>
  → 200 customer1 com JWT              ← custom:tenant_id=customer1 ✅
  → 403 customer2 com JWT customer1    ← isolamento Istio ✅
  → 403 customer2 sem JWT              ← Istio AuthorizationPolicy ✅
```

**Commits neste branch:**
- `d6afefd` — `feat(eks/local): add local k3d lab and extend services for offline operation`
- `62e60a5` — `docs(eks): add notes on local lab plan and HANDOFF`
- `218c4ef` — `docs(eks): update HANDOFF with completed local lab status`
- `5da5ecb` — `fix(eks/local): make local k3d lab work end-to-end with Keycloak 26`
- `e32187a` — `refactor(eks/local): rename COGNITO_* env vars to IDP_* for provider-agnostic naming`

## What Worked

- HAProxy Ingress em vez de Nginx (deprecated) — `NodePort 32080`
- Keycloak oficial `quay.io/keycloak/keycloak:26.1` com `start-dev` + `k3d image import`
- `frontendUrl` configurado via `PUT /admin/realms/{realm}` com `{"attributes":{"frontendUrl":"..."}}` (não no body de criação)
- User Profile KC 26: declarar `tenant_id` antes de criar usuários, via `GET/PUT /users/profile`
- `VERIFY_PROFILE` desabilitado com `enabled:false` (não apenas `defaultAction:false`)
- `IDP_TOKEN_URL` apontando para service interno do cluster (`keycloak.keycloak.svc.cluster.local:8080`) — evita round-trip pelo HAProxy
- Ingress catch-all em `istio-ingress` com `defaultBackend → istio-ingressgateway:80` — conecta HAProxy ao Istio
- `emptyDir` em `/data` no discovery para o SQLite criar o arquivo `.db`
- `DISCOVERY_URL` in-cluster (`discovery.discovery.svc.cluster.local:8000`) — DNS do `/etc/hosts` não propaga para pods
- `COOKIE_SECURE=false` + `COOKIE_DOMAIN=.wasp.local` — cookie enviado em HTTP com domínio correto

### Design Decisions (arquitetura)

| Decisão | Implementação |
|---------|---------------|
| **Tenant por `custom:tenant_id`** | Protocol Mapper no Keycloak injeta claim `custom:tenant_id` no token. Isolamento via Istio `AuthorizationPolicy` que valida `request.auth.claims[custom:tenant_id] == tenant_id`. |
| **Naming de secrets multi-tenant** | `COGNITO_CLIENT_SECRET_<TENANT_ID>` (ex: `COGNITO_CLIENT_SECRET_CUSTOMER1`). Permite lookup dinâmico no `callback-handler` sem hardcode. |
| **Backend discovery switchável** | `BACKEND=sqlite\|dynamodb` — SQLite para local, DynamoDB para AWS. Default `dynamodb` para compatibilidade. |
| **Claims via User Profile** | `tenant_id` declarado no KC 26 User Profile antes de criar usuários. KC descarta atributos não declarados silenciosamente. |
| **`env.secrets` como fonte única** | Secrets geradas em runtime (`KEYCLOAK_CLIENT_SECRET`, `STATE_JWT_SECRET`) persistidas em `env.secrets` para sessões futuras não regenerarem valores inconsistentes. |

## What Didn't Work / Gotchas

- **Bitnami removeu imagens do Docker Hub** — `bitnami/keycloak` retorna `pull access denied`. Usar `quay.io/keycloak/keycloak:26.1`.
- **`frontendUrl` no body de criação do realm** → `"unable to read contents from stream"` no KC 26. Separar criação da configuração do `frontendUrl`.
- **JSON multiline em `--data` com Istio sidecar** → KC 26 rejeita com erro de parse. Todo JSON nos `--data` dos scripts deve ser em linha única.
- **KC 26 User Profile descarta atributos não declarados** — `tenant_id` silenciosamente ignorado ao criar usuários se não estiver no schema.
- **`VERIFY_PROFILE` intercepta login mesmo com `defaultAction:false`** — precisa de `enabled:false`.
- **Parâmetro Helm `controller.service.nodePorts.http`** não tem efeito. Correto: `controller.service.httpPorts[0].nodePort`.
- **HAProxy sem `Ingress` resource** → 503 em tudo. O HAProxy não encaminha para o Istio sem um `Ingress` com `defaultBackend`.
- **Discovery falha sem volume em `/data`** — `unable to open database file` se não houver `emptyDir`.
- **Domínio do seed deve ser o do e-mail** (`customer1.com`), não o subdomínio da app (`customer1.wasp.local`).
- **`secure=True` hardcoded** no callback-handler → cookie não enviado em HTTP. Substituído por `COOKIE_SECURE` env var.
- **`domain=".wasp.silvios.me"` hardcoded** → cookie não aceito em `.wasp.local`. Substituído por `COOKIE_DOMAIN` env var.
- **`grant_type=password` sem `scope=openid`** → não retorna `id_token` (só `access_token`). Adicionar `--data "scope=openid"` ao testar diretamente.
- **`rollout restart` necessário quando Secret/ConfigMap muda** — quando apenas o conteúdo de um Secret ou ConfigMap muda (sem troca de imagem), o pod não remonta volumes/env vars automaticamente. É necessário `kubectl rollout restart deployment/<name>` para aplicar as mudanças.
- **Subagente sem permissão bash** — ao delegar execução de scripts para subagente via Agent tool, ele não herda as permissões da sessão principal mesmo com `Bash(*)` em `~/.claude/settings.json`. A permissão é carregada na inicialização da sessão — reiniciar o Claude Code resolve. Alternativamente, rodar os scripts manualmente.
- **`--skip-schema-validation` inválido em Helm v3.12** — flag não existe nesta versão do Helm, causa `Error: unknown flag`. Removida do `04-install-istio`. O istio-ingressgateway não era instalado silenciosamente porque o script usava `set -euo pipefail` mas o erro ocorria dentro de uma subshell de pipeline. Corrigido: removida a flag.
- **CORS regex `\.` em YAML double-quoted string é inválido** — dentro de `<<EOF` bash, `\\.` vira `\.` que é sequência de escape inválida em YAML (YAML só aceita `\\`, `\"`, `\n`, etc.). O `kubectl apply` falha com `found unknown escape character`. Solução: usar `[.]` no lugar de `\.` nos padrões de regex nos scripts `06-deploy-services` e `08-deploy-customer2`.
- **Endpoint do discovery é `/tenant?domain=<email_domain>`** — não `/tenants`. A verificação final no HANDOFF.md e no prompt de tarefa usava `/tenants` (404). O endpoint correto é `/tenant?domain=customer1.com`.

## Backlog

### P1 — Quick wins

- [x] **Renomear variáveis `COGNITO_*` → `IDP_*` no lab local**: concluído em `e32187a`. `COGNITO_DOMAIN` → `IDP_DOMAIN`, `COGNITO_CLIENT_SECRET_CUSTOMER1/2` → `IDP_CLIENT_SECRET_CUSTOMER1/2` nos scripts e serviços (TDD: 28 + 16 testes passando).
- [ ] **Unificar scripts de IDP** (AWS): script 11 (Google) e 16 (Microsoft) → script único `configure-idps`.

### P2 — Melhorias importantes

- [ ] **Nomes estáveis para recursos de rede**: avaliar usar `cluster_name` fixo em `env.conf` (ex: `wasp-eks-lab`) para VPC/subnets com nome estável entre sessões.
- [ ] **Health check dedicado `/healthz`**: separar tráfego de health check (ALB) do tráfego real; avaliar se expõe risco de segurança.
- [ ] **Redirect ao expirar token**: Istio retorna 403 puro quando JWT expira. O `tenant-frontend` deve detectar expiração (claim `exp`) e redirecionar para `/login`. Alternativa: configurar Istio para redirecionar em vez de 403.

### P3 — Exploração / futuro

- [ ] **CDN para assets frontend**: CSS, logo, JS duplicados entre serviços. Avaliar S3+CloudFront ou nginx estático compartilhado.
- [ ] **Cilium CNI em ENI mode**: provisionar EKS com Cilium em vez de AWS VPC CNI.
- [ ] **Istio Ambient Mesh**: implementar e verificar limitações.
- [ ] **Remover `COGNITO_CLIENT_ID` órfão dos ConfigMaps** (AWS): serviços não usam essa variável (vem do discovery via state JWT).
- [ ] **SSM Parameter Store**: migrar secrets de `env.secrets` para SSM (alternativa gratuita ao Secrets Manager).
- [ ] **waspctl network proxy**: comando para provisionar cluster e integrar ao Global Accelerator.

## Lab Local — Run 2026-04-16

Commit: `016d9d4` — Branch: `dev`

### Resultados por script

| Script | Status | Duração (s) | Notas |
|---|---|---|---|
| `bootstrap` | ✅ | 1 | Todos os pré-requisitos presentes; k3d 5.8.3, kubectl 1.31, helm 3.12.2, docker 29.4.0, istioctl 1.29.1; entradas `/etc/hosts` já existiam |
| `01-create-cluster` | ✅ | 52 | Cluster k3d `wasp` criado com 3 server nodes (v1.31.5+k3s1); traefik desabilitado; portas 9080, 9443, 32080 mapeadas |
| `02-install-haproxy-ingress` | ✅ | 3 | HAProxy Ingress instalado via Helm; NodePort 32080 funcional |
| `03-install-cert-manager` | ✅ | 28 | cert-manager v1.20.2; ClusterIssuer `wasp-local-ca` pronto |
| `04-install-istio` | ✅ | 35 | Istio 1.24.3; istio-base, istiod, istio-ingressgateway (ClusterIP); Ingress catch-all HAProxy→Istio criado |
| `05-deploy-keycloak` | ✅ | 79 | Keycloak 26.1 deployado; realm `wasp` configurado; client `wasp-platform`; Protocol Mapper `custom:tenant_id`; `VERIFY_PROFILE` desabilitado; client secret salvo em `env.secrets` |
| `06-deploy-services` | ✅ | 77 | Build local das 4 imagens (git tag `016d9d4`); import k3d; deploy discovery (SQLite), platform-frontend, callback-handler, customer1 (httpbin + tenant-frontend) |
| `07-configure-istio-auth` | ✅ | 1 | `RequestAuthentication` + `AuthorizationPolicy` em `customer1`; JWT issuer `http://idp.wasp.local:32080/realms/wasp` |
| `08-deploy-customer2` | ✅ | 31 | ConfigMap discovery-seed atualizado; callback-handler secret atualizado; namespace `customer2` com Istio auth; rollouts concluídos |

**Tempo total: ~307 s (~5 min 7 s)**

### Smoke tests (todos passaram)

| Endpoint | HTTP | Esperado |
|---|---|---|
| `http://wasp.local:32080/health` | 200 | ✅ |
| `http://discovery.wasp.local:32080/health` | 200 | ✅ |
| `http://auth.wasp.local:32080/health` | 200 | ✅ |
| `http://customer1.wasp.local:32080/` (sem JWT) | 403 | ✅ |
| `http://customer2.wasp.local:32080/` (sem JWT) | 403 | ✅ |
| `GET /tenant?domain=customer1.com` | tenant_id=customer1 | ✅ |
| `GET /tenant?domain=customer2.com` | tenant_id=customer2 | ✅ |

### Problemas encontrados

Nenhum — todos os 8 scripts passaram sem falha na primeira execução. Ambiente estava em estado limpo (cluster k3d não existia).

---

## Design → Frontend: sincronização de UI

### Contexto

O arquivo `design/index.html` é o **single source of truth visual**. Ele carrega o CSS real dos serviços via `<link rel="stylesheet" href="/services/tenant-frontend/app/static/app.css">`, então qualquer mudança em `app.css` é imediatamente refletida no sandbox ao rodar `make serve`.

### O que foi feito

- **Passo 1 (concluído):** Todo CSS de componentes que estava inline no `<style>` do `design/index.html` foi movido para `app.css`. O `<style>` agora contém apenas o chrome do sandbox (`#sandbox-bar`, `body { padding-bottom }`) e um override pontual (`.result-drawer-overlay { bottom: 40px }` para não cobrir a barra do sandbox).

  **Fluxo atual:** editar CSS → editar `app.css` → design sandbox e serviço ficam sincronizados automaticamente.

- **Passo 2 (concluído):** Script `06-deploy-services` (local) alinhado com `13-deploy-services` (AWS): o symlink `app/static/shared → ../../../../design/shared` é substituído por cópia real antes do `docker build` e restaurado após, garantindo que `shared/tokens.css` e `shared/base.css` entrem na imagem.

- **Passo 3 (concluído):** JS de UI extraído para `services/tenant-frontend/app/static/test-ui.js`.

  **Interface de inicialização:**
  ```js
  window.initTestPage({ testCases, jwtToken });
  ```
  - `design/index.html`: carrega via `<script src="/services/tenant-frontend/app/static/test-ui.js">`, chama `initTestPage({ testCases: TEST_CASES, jwtToken: MOCK_JWT })` após `buildAccordion()`.
  - `test.html`: `<script src="{{ url_for('static', path='test-ui.js') }}">` + `initTestPage({ testCases: ..., jwtToken: ... })` com dados Jinja2.
  - `test-ui.js` expõe `window._testUi` e registra funções globais (`toggleAccordion`, `runSingle`, `openDrawer`, etc.) no `initTestPage()` para compatibilidade com atributos `onclick=` inline.

  **Fluxo atual:** editar JS de UI → editar `test-ui.js` → sandbox e serviço ficam sincronizados automaticamente.

### Observações

- Script `05-deploy-keycloak` regenerou `KEYCLOAK_CLIENT_SECRET` em `env.secrets` (valor anterior era da sessão anterior).
- `env.secrets` existia com `STATE_JWT_SECRET` reaproveitado — `06-deploy-services` detectou e usou sem regenerar.
- Cluster usa 3 server nodes (HA etcd); build das imagens usa cache Docker — builds quasi-instantâneos.

### Issues abertas

Nenhuma nova. Backlog inalterado.

---

## Next Steps

1. **Reprovisionar do zero** — ✅ Validado em 2026-04-16. Scripts 01-08 funcionam após correções documentadas nos Gotchas. `./destroy && ./run` funciona a partir de estado limpo.
2. **`cognito_pool_id` → `idp_pool_id`** (data model) — rename do campo no discovery service, fora do escopo anterior (requer DB migration + TDD)

## Key Files

| Arquivo | Relevância |
|---|---|
| `local/scripts/env.conf` | Config global do lab local (domínio, portas, credenciais Keycloak) |
| `local/scripts/env.secrets` | Gerado em runtime — `KEYCLOAK_CLIENT_SECRET`, `STATE_JWT_SECRET` |
| `local/docs/diferencas-aws.md` | Mapa completo de substituições locais |
| `local/docs/lessons-learned.md` | Todos os problemas encontrados e soluções durante execução |
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
