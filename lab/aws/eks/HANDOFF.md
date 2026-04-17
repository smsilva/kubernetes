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

Os gotchas detalhados com soluções estão em `local/docs/lessons-learned.md`. Resumo dos não óbvios:

- **`rollout restart` necessário quando Secret/ConfigMap muda** — sem troca de imagem, pods não remontam env vars automaticamente. `kubectl rollout restart deployment/<name>`.
- **Subagente sem permissão bash** — subagentes via Agent tool não herdam permissões da sessão principal. Reiniciar o Claude Code ou rodar scripts manualmente.
- **`--skip-schema-validation` inválido em Helm v3.12** — causa `Error: unknown flag`; removida do `04-install-istio`.
- **CORS regex `\.` em YAML dentro de `<<EOF` bash** — `\\.` vira `\.`, escape inválido em YAML. Usar `[.]` no lugar de `\.` nos scripts.
- **Endpoint do discovery é `/tenant?domain=<email_domain>`** — não `/tenants` (404).

## Backlog

### P1 — Quick wins

- [x] **Renomear variáveis `COGNITO_*` → `IDP_*` no lab local**: concluído em `e32187a`. `COGNITO_DOMAIN` → `IDP_DOMAIN`, `COGNITO_CLIENT_SECRET_CUSTOMER1/2` → `IDP_CLIENT_SECRET_CUSTOMER1/2` nos scripts e serviços (TDD: 28 + 16 testes passando).
- [ ] **Unificar scripts de IDP** (AWS): script 11 (Google) e 16 (Microsoft) → script único `configure-idps`.
- [ ] **Decode JWT na página de teste**: `test.html` exibir claims decodificados do JWT (header + payload) ao lado do token bruto.
- [ ] **Syntax highlight nos resultados de teste**: respostas JSON e saída shell com highlight de sintaxe na página de teste do tenant-frontend.
- [ ] **Screenshots para documentação**: tirar prints das telas principais (login, redirecionamento, página do tenant, isolamento 403) para enriquecer `docs/`.

### P2 — Melhorias importantes

- [ ] **Nomes estáveis para recursos de rede**: avaliar usar `cluster_name` fixo em `env.conf` (ex: `wasp-eks-lab`) para VPC/subnets com nome estável entre sessões.
- [ ] **Health check dedicado `/healthz`**: separar tráfego de health check (ALB) do tráfego real; avaliar se expõe risco de segurança.
- [ ] **Redirect ao expirar token**: Istio retorna 403 puro quando JWT expira. O `tenant-frontend` deve detectar expiração (claim `exp`) e redirecionar para `/login`. Alternativa: configurar Istio para redirecionar em vez de 403.
- [ ] **Network policy isolando namespaces**: complementar o isolamento do Istio com `NetworkPolicy` K8s bloqueando tráfego direto entre namespaces de tenants.
- [ ] **Diagrama do Lab EKS**: atualizar `docs/` com diagrama de arquitetura (fluxo de tráfego, componentes, namespaces).
- [ ] **Métricas com OpenTelemetry**: instrumentar os serviços Python para emitir métricas via OTEL (latência, erros, requisições por tenant).
- [ ] **Fitness function / Business metrics**: endpoint de saúde semântica do cluster (ex: `/healthz/business`) com métricas de tenants ativos, autenticações bem-sucedidas, disponível localmente com indicador visual.
- [ ] **Métricas do cluster**: Prometheus + Grafana ou similar para observabilidade de infra (CPU, memória, pods por namespace).
- [ ] **Teste de interface local (e2e)**: testes automatizados de browser para o fluxo de login completo (Playwright ou similar), rodando contra k3d.

### P3 — Exploração / futuro

- [ ] **CDN para assets frontend**: CSS, logo, JS duplicados entre serviços. Avaliar S3+CloudFront ou nginx estático compartilhado.
- [ ] **Cilium CNI em ENI mode**: provisionar EKS com Cilium em vez de AWS VPC CNI.
- [ ] **Istio Ambient Mesh**: implementar e verificar limitações.
- [ ] **Remover `COGNITO_CLIENT_ID` órfão dos ConfigMaps** (AWS): serviços não usam essa variável (vem do discovery via state JWT).
- [ ] **SSM Parameter Store**: migrar secrets de `env.secrets` para SSM (alternativa gratuita ao Secrets Manager).
- [ ] **waspctl network proxy**: comando para provisionar cluster e integrar ao Global Accelerator.
- [ ] **Resource quotas por namespace**: limitar CPU/memória por tenant para evitar noisy neighbor.
- [ ] **Proteger repositório GitHub**: branch protection rules, required reviews, signed commits.
- [ ] **Penetration test**: avaliar OWASP ZAP ou similar contra o lab local (k3d) antes de rodar contra AWS.
- [ ] **CSPM** (Cloud Security Posture Management): avaliar ferramenta para detectar misconfigurações na conta AWS (ex: Prowler, AWS Security Hub).
- [ ] **CIEM** (Cloud Infrastructure Entitlement Management): auditar permissões IAM excessivas; avaliar ferramentas dedicadas.
- [ ] **CNAPP** (Cloud Native Application Protection Platform): avaliar solução unificada que cubra CSPM + CIEM + runtime security (ex: Wiz, Lacework).
- [ ] **Simulação waspctl com IA**: interação conversacional simulando comandos `waspctl` com respostas simuladas, para exercitar conceitos e documentar o fluxo esperado da CLI.

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

## Next Steps

- Ver Backlog abaixo.

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

## Referências externas

- [smsilva.github.io/kubernetes](https://smsilva.github.io/kubernetes) — documentação publicada do projeto
- [Building a Multi-Tenant SaaS Solution Using Amazon EKS](https://aws.amazon.com/pt/blogs/apn/building-a-multi-tenant-saas-solution-using-amazon-eks) — referência de arquitetura multi-tenant
- [Operating a multi-regional stateless application using Amazon EKS](https://aws.amazon.com/pt/blogs/containers/operating-a-multi-regional-stateless-application-using-amazon-eks) — referência para expansão multi-região
