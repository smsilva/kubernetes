# CLAUDE.md — EKS Lab Context

> Guia de contexto para Claude Code em sessões futuras neste diretório.

---

## Identificadores principais

| Recurso | Valor |
|---|---|
| **Cluster EKS** | `wasp-calm-crow-ndx4` |
| **Região** | `us-east-1` |
| **Domínio** | `wasp.silvios.me` (wildcard `*.wasp.silvios.me`) |
| **ACM Certificate ARN** | `arn:aws:acm:us-east-1:221047292361:certificate/59ab7614-fa1b-4dba-9f43-7c775cfa5bac` |
| **VPC ID** | `vpc-03cb9d83815b52ee1` |
| **AWS Account ID** | `221047292361` |

---

## Projeto relacionado: waspctl

O projeto `waspctl` em `~/git/waspctl` é a CLI que vai automatizar o provisionamento desta mesma infraestrutura. Este lab documenta a **Fase 1** (cluster único + Auth Service manual). O waspctl cobre as fases 1-3, incluindo expansão multi-região com Global Accelerator. Consultar `~/git/waspctl/README.md` para referências externas (artigos AWS) e especificação completa da CLI.

---

## Fluxo de tráfego

```
Internet → ALB (TLS termination, ACM cert)
         → WAF (managed rules + rate limiting)
         → Istio IngressGateway (ClusterIP, private subnet)
         → Istio Gateway + VirtualService
         → Aplicação (namespace com sidecar injection)
```

---

## Regra: sempre adicionar entrada de destroy ao criar recurso novo

Toda vez que um script de provisionamento criar um recurso AWS ou Azure, **a entrada correspondente de deleção deve ser adicionada ao `scripts/destroy` na mesma sessão**, na posição correta da ordem inversa. A ordem deve respeitar dependências (ex: Cognito custom domain antes do User Pool) — se houver conflito com ordem de custo, a ordem de dependência prevalece.

Checklist ao adicionar um recurso:
1. Identificar o comando de deleção (`aws <serviço> delete-*` ou `az ... delete`)
2. Determinar a posição correta no `destroy` (ordem inversa da criação, respeitando dependências)
3. Usar `|| true` ou verificação de existência para tornar idempotente
4. Atualizar o comentário de ordem no cabeçalho do `destroy`
5. Marcar o item como `[x]` no backlog de `docs/notes.md` se havia pendência registrada

---

## Antes de criar ou destruir recursos

Sempre execute o `bootstrap` primeiro para validar pré-requisitos:

```bash
# antes de criar
./scripts/bootstrap --create

# antes de destruir
./scripts/bootstrap --destroy
```

O script verifica: CLIs instaladas (`aws`, `eksctl`, `kubectl`, `helm`, `istioctl`, `docker`, `az`), credenciais AWS ativas na conta correta (`221047292361`), Azure CLI autenticada na subscription `wasp-sandbox`, Docker daemon rodando e secrets obrigatórias definidas (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `STATE_JWT_SECRET`).

---

## Estrutura dos scripts

Scripts em `scripts/`, documentos em `docs/`. Configurações globais em `scripts/env.conf`.

| Script | O que faz | Tempo |
|---|---|---|
| `scripts/bootstrap` | Valida pré-requisitos antes de criar ou destruir recursos | ~5s |
| `scripts/reset-session` | Zera variáveis dinâmicas (IDs Cognito, ARN GA, secrets geradas, JWTs) antes de reprovisionar do zero | ~1s |
| `scripts/01-create-vpc` | VPC, subnets, IGW, NAT Gateway, route tables | ~3min |
| `scripts/02-create-cluster` | Cluster EKS + node group via eksctl | ~15min |
| `scripts/03-configure-access` | EKS Access API + AmazonEKSClusterAdminPolicy | ~20s |
| `scripts/04-install-alb-controller` | Helm + IRSA para ALB Controller | ~1min20s |
| `scripts/05-install-istio` | Helm: istio/base + istiod + gateway | ~1min15s |
| `scripts/06-import-certificate-acm` | Importa cert Let's Encrypt no ACM | ~5s |
| `scripts/07-configure-alb-ingress` | Ingress resource + IngressClass | ~25s |
| `scripts/07b-configure-global-accelerator` | Global Accelerator → ALB, IPs estáticos, A records no Azure DNS | ~1min |
| `scripts/08-deploy-sample-app` | httpbin no namespace `sample` | ~25s |
| `scripts/09-configure-waf` | WAF WebACL + regras gerenciadas + associação ao ALB | ~45s |
| `scripts/10-create-dynamodb` | Tabela DynamoDB `tenant-registry` + item customer1 | ~10s |
| `scripts/11-create-cognito` | User Pool, Google IdP, App Client, Lambda Pre-Token Generation | ~25s |
| `scripts/12-configure-dns-cognito` | Custom domain Cognito (`idp.wasp.silvios.me`) + CNAME no Azure DNS | ~10s |
| `scripts/13-deploy-services` | Build/push Docker Hub, IRSA discovery, deploy K8s dos 4 namespaces | ~1min15s |
| `scripts/14-configure-istio-auth` | Istio `RequestAuthentication` + `AuthorizationPolicy` no namespace `customer1` | ~10s |
| `scripts/15-configure-waf-ratelimit` | Rate limiting WAF para `/login` e `/callback` | ~10s |
| `scripts/16-add-microsoft-idp` | IdP Microsoft OIDC + App Client customer2 + DynamoDB | ~10s |
| `scripts/17-deploy-customer2` | Build/push + deploy namespace customer2 + rollout callback-handler | ~1min |
| `scripts/destroy` | Destrói tudo na ordem inversa (ACM deve ser removido manualmente) | ~20-30min |

**Tempo total de criação: ~26min** (dominado pelo `02-create-cluster` ~15min via CloudFormation).

---

## Documentação de referência

| Documento | Conteúdo |
|---|---|
| `docs/fluxo-autenticacao-multitenant.md` | Arquitetura do fluxo de autenticação multi-tenant |
| `docs/decisoes-tecnicas.md` | Decisões de design, trade-offs e itens adiados conscientemente |
| `docs/onboarding-novo-customer.md` | Passos para cadastrar novo tenant: IdP, DynamoDB, K8s, domínios compartilhados |

---

## DNS

O domínio `wasp.silvios.me` é gerenciado em **Azure DNS** (subscription `wasp-sandbox`, resource group `wasp-foundation`), não no Route 53. Scripts usam `az network dns record-set` em vez de `aws route53`.

---

## Subdomínios e roteamento

| Subdomínio | Destino | Via |
|---|---|---|
| `wasp.silvios.me` | platform-frontend (ns: `platform`) | ALB → Istio |
| `idp.wasp.silvios.me` | Cognito Hosted UI | CloudFront (Azure DNS CNAME) |
| `auth.wasp.silvios.me` | callback-handler (ns: `auth`) | ALB → Istio |
| `discovery.wasp.silvios.me` | discovery service (ns: `discovery`) | ALB → Istio |
| `customer1.wasp.silvios.me` | httpbin / app tenant (ns: `customer1`) | ALB → Istio |

---

## Credenciais — variáveis de ambiente obrigatórias

Scripts 11 e 13 requerem env vars (não entram no `env.conf`):

| Variável | Usado em | Como obter |
|---|---|---|
| `GOOGLE_CLIENT_ID` | `11-create-cognito` | Google Cloud Console → OAuth 2.0 credentials |
| `GOOGLE_CLIENT_SECRET` | `11-create-cognito` | Google Cloud Console → OAuth 2.0 credentials |
| `COGNITO_CLIENT_SECRET` | `13-deploy-services` | `aws cognito-idp describe-user-pool-client --query UserPoolClient.ClientSecret` |
| `STATE_JWT_SECRET` | `13-deploy-services` | `openssl rand -hex 32` |

Google redirect URI obrigatório: `https://idp.wasp.silvios.me/oauth2/idpresponse` em **Authorized redirect URIs** (não em JavaScript origins — nosso flow é server-side redirect).

---

## Serviços Python (`services/`)

Stack: Python 3.12 + FastAPI + Jinja2 + PyJWT + httpx. Cada serviço tem `.venv` próprio.

```bash
cd lab/aws/eks/services/<serviço>
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest tests/ -v
```

### Variáveis de ambiente por serviço

| Serviço | Variável | Valor |
|---|---|---|
| `callback-handler` | `COGNITO_DOMAIN` | `idp.wasp.silvios.me` (só hostname, sem `https://`) |
| `callback-handler` | `COGNITO_CLIENT_ID` | App Client ID do tenant (ConfigMap) |
| `callback-handler` | `COGNITO_CLIENT_SECRET` | Via Secret `callback-handler-secret` |
| `callback-handler` | `STATE_JWT_SECRET` | Chave compartilhada com `platform-frontend` |
| `platform-frontend` | `COGNITO_DOMAIN` | `idp.wasp.silvios.me` (só hostname, sem `https://`) |
| `platform-frontend` | `DISCOVERY_URL` | `https://discovery.wasp.silvios.me` |
| `platform-frontend` | `CALLBACK_URL` | `https://auth.wasp.silvios.me/callback` |
| `platform-frontend` | `STATE_JWT_SECRET` | Chave compartilhada com `callback-handler` |

Imagens Docker Hub (build com `--platform linux/amd64`; tag = git short SHA, nunca `:latest`):

| Serviço | Repositório |
|---|---|
| `discovery` | `silviosilva/wasp-discovery` |
| `platform-frontend` | `silviosilva/wasp-platform-frontend` |
| `callback-handler` | `silviosilva/wasp-callback-handler` |

---

## Issues de segurança documentadas (SEC-*)

| ID | Severidade | Problema |
|---|---|---|
| [SEC-002](docs/security-issues/sec-002.md) | Médio | IAM policy baixada sem verificação de hash |
| [SEC-003](docs/security-issues/sec-003.md) | Baixo | Imagem do container sem digest fixo |
| [SEC-004](docs/security-issues/sec-004.md) | Médio | Permissão cluster-admin sem escopo de namespace |
| [SEC-005](docs/security-issues/sec-005.md) | Baixo | Sem Security Groups dedicados para o ALB |
| [SEC-006](docs/security-issues/sec-006.md) | Médio | IMDSv1 habilitado nos nodes |

---

## Gotchas operacionais

### `tenants.json` deve ter valores reais do Cognito

`services/discovery/app/data/tenants.json` é fonte de dados estática. Ao reprovisionar o Cognito, atualizar `client_id` e `cognito_pool_id` antes do build, fazer commit e rebuild com nova tag SHA.

### `COGNITO_DOMAIN` sem `https://`

No ConfigMap `platform-frontend-config`, o campo `COGNITO_DOMAIN` deve ser só o hostname (`idp.wasp.silvios.me`). O código em `auth.py` já adiciona o scheme — colocar a URL completa gera `https://https://idp...`.

### DynamoDB — palavras reservadas em `--update-expression`

Atributos com nomes reservados (ex: `auth`, `name`, `status`) causam `ValidationException`. Usar `--expression-attribute-names` com alias `#`:

```bash
--update-expression 'SET #auth.field = :val' \
--expression-attribute-names '{"#auth": "auth"}'
```

### WAFv2 — `--id` exige UUID, não name

```bash
# CORRETO — $NF extrai o UUID (último segmento do ARN)
web_acl_id="$(echo "${web_acl_arn}" | awk -F'/' '{print $NF}')"
```

### Pipe + heredoc Python — conflito de stdin

Pipe (`|`) e heredoc (`<<EOF`) disputam o stdin. O heredoc vence. Gravar a variável em arquivo temporário e ler via `open()`.


# Notas

Durante a execução dos scripts do lab, faça anotações no arquivo lab/aws/eks/docs/notes.md para registrar aprendizados, decisões, problemas encontrados e soluções aplicadas. Essas notas serão valiosas para futuras sessões de desenvolvimento, troubleshooting e para enriquecer a documentação do projeto.

Anote também sempre que precisar tirar uma dúvida durante a execução dos scripts, para que possamos discutir e esclarecer esses pontos em sessões futuras.

Qualquer alteração no código ou nas configurações usadas pelos serviços, deve ser primeiramente coberta com testes automatizados.

Alterações sempre com TDD.
