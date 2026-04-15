# HANDOFF — Ambiente Local com k3d

## Goal

Criar `lab/local/` — versão offline do lab AWS EKS usando k3d, sem dependências de cloud. O objetivo é ter um ambiente iterativo para desenvolver e testar os serviços Python sem precisar da AWS.

## Current Progress

- [x] Plano completo definido e documentado em `docs/notes.md` (último item do backlog P3)
- [ ] Nenhuma linha de código ou script escrita ainda — esta sessão foi só planejamento

## What Worked

- Análise completa da stack AWS existente identificou quais componentes são portáteis (Istio, namespaces, AuthorizationPolicy, serviços Python) e quais precisam de substituto local
- Mapeamento de substituições validado:

  | Componente AWS | Substituto local |
  |---|---|
  | EKS | k3d (single-node) |
  | ALB | Nginx Ingress Controller |
  | ACM / TLS | cert-manager + CA auto-assinada |
  | Cognito | Keycloak (Helm `bitnami/keycloak`) |
  | Lambda Pre-Token | Keycloak Protocol Mapper (injeta `tenant_id`) |
  | DynamoDB | SQLite via `aiosqlite` no discovery service |
  | IRSA | Env vars diretas no pod |
  | Route53/Azure DNS | `/etc/hosts` com `*.wasp.local → 127.0.0.1` |
  | Global Accelerator / WAF | Removidos |

## What Didn't Work

Nada tentado ainda — sessão foi de planejamento.

## Next Steps

Seguir as 13 etapas na ordem definida em `docs/notes.md`. Resumo:

1. **Criar `lab/local/`** com estrutura: `scripts/`, `manifests/`, `docs/`
2. **`scripts/bootstrap`** — validar pré-requisitos locais (`k3d`, `kubectl`, `helm`, `docker`; sem `aws`/`az`)
3. **`scripts/01-create-cluster`** — k3d com portas 80/443 no host, Traefik desabilitado
4. **`scripts/02-install-nginx-ingress`** — Helm, verificar pod Ready
5. **`scripts/03-install-cert-manager`** — Helm + `ClusterIssuer` CA auto-assinada para `*.wasp.local`
6. **`scripts/04-install-istio`** — reuso dos charts do lab AWS; `ingressgateway` em ClusterIP
7. **`scripts/05-deploy-keycloak`** — realm `wasp`, dois users de teste (`user1@customer1.com`, `user2@customer2.com`), Protocol Mapper que injeta `tenant_id` via email domain
8. **Adaptar `discovery` service** — backend SQLite configurável via `BACKEND=sqlite|dynamodb`; TDD primeiro
9. **`scripts/06-deploy-services`** — build local (sem Docker Hub push), ConfigMaps com endpoints locais
10. **`scripts/07-configure-istio-auth`** — reusar manifests; ajustar `jwksUri` para JWKS do Keycloak
11. **`scripts/08-deploy-customer2`** — namespace `customer2` local
12. **`scripts/destroy`** — deletar cluster k3d + containers Keycloak
13. **`lab/local/docs/diferencas-aws.md`** — documentar o que não funciona localmente (WAF, GA, IRSA, multi-região)

## Key Files

| Arquivo | Relevância |
|---|---|
| `docs/notes.md` | Plano completo com tabela de substituições e 13 etapas (último item backlog P3) |
| `scripts/env.conf` | Config global do lab AWS — base para o `env.conf` local |
| `scripts/05-install-istio` | Referência para reusar os charts Helm do Istio |
| `scripts/13-deploy-services` | Referência para adaptar o deploy local |
| `services/discovery/` | Serviço que precisa de backend SQLite como alternativa ao DynamoDB |
| `CLAUDE.md` | Contexto do lab (domínios, credenciais, gotchas operacionais) |

## Context

- Domínio local: `wasp.local` (em vez de `wasp.silvios.me`)
- Subdomínios no `/etc/hosts`: `wasp.local`, `auth.wasp.local`, `discovery.wasp.local`, `idp.wasp.local`, `customer1.wasp.local`, `customer2.wasp.local`
- Todo o lab AWS fica intacto — `lab/local/` é um diretório paralelo independente
- Regra do projeto: TDD — testes antes do código para qualquer alteração nos serviços
