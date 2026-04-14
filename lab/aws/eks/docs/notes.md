# Notas sobre a última execução

## Tempos de execução — 2026-04-13

| Script | Tempo |
|---|---|
| `bootstrap` (pre-check) | ~5s |
| `01-create-vpc` | 2m50s |
| `02-create-cluster` | 14m47s |
| `03-configure-access` | 19s |
| `04-install-alb-controller` | 1m19s |
| `05-install-istio` | 1m15s |
| `06-import-certificate-acm` | 3s |
| `07-configure-alb-ingress` | 25s |
| `07b-configure-global-accelerator` | 1m07s |
| `08-deploy-sample-app` | 24s |
| `09-configure-waf` | 46s |
| `10-create-dynamodb` | 7s |
| `11-create-cognito` | 22s |
| `12-configure-dns-cognito` | 8s |
| `13-deploy-services` | 1m14s |
| `14-configure-istio-auth` | 11s |
| `15-configure-waf-ratelimit` | 7s |
| `16-add-microsoft-idp` | 10s |
| `17-deploy-customer2` | 1m01s |
| **Total** | **~26min** |

Gargalos: `02-create-cluster` (~15min, dominado pelo CloudFormation do eksctl) e `01-create-vpc` (~3min, aguardando NAT Gateway).

---

## Observações operacionais

### Aviso vpc-cni OIDC no `02-create-cluster`

O eksctl emitiu um aviso durante a criação do cluster:

```
[!] recommended policies were found for "vpc-cni" addon, but since OIDC is disabled on the cluster,
eksctl cannot configure the requested permissions; the recommended way to provide IAM permissions
for "vpc-cni" addon is via pod identity associations
```

O script `03-configure-access` cria o OIDC provider logo depois e o eksctl atualiza o addon `vpc-cni` com o CloudFormation stack `eksctl-...-addon-vpc-cni` automaticamente. Na prática não causou problema nesta execução. Monitorar se em versões futuras do eksctl o addon `vpc-cni` precisar de intervenção manual.

### Global Accelerator requer `--region us-west-2`

O serviço AWS Global Accelerator é global e seu endpoint de API é exclusivamente `globalaccelerator.amazonaws.com` — sem sufixo regional. Ao passar `--region us-east-1`, a AWS CLI tenta `globalaccelerator.us-east-1.amazonaws.com`, que não existe, resultando em:

```
aws: [ERROR]: Could not connect to the endpoint URL: "https://globalaccelerator.us-east-1.amazonaws.com/"
```

**Correção:** usar `--region us-west-2` em todos os comandos `aws globalaccelerator` (a AWS CLI roteia para o endpoint global a partir dessa região). O script `07b-configure-global-accelerator` foi corrigido.

### `rollout restart` em mudanças de Secret/ConfigMap sem troca de imagem

Quando apenas o conteúdo de um `Secret` ou `ConfigMap` muda (ex: adicionar `COGNITO_CLIENT_SECRET_CUSTOMER2` ao Secret `callback-handler-secret`), `rollout restart` é necessário para que os pods remontem os volumes/env vars atualizados. Script 17 já faz isso explicitamente após aplicar o Secret.

---

## Decisões de design

### Naming convention para secrets multi-tenant

Adotar `COGNITO_CLIENT_SECRET_<TENANT_ID em maiúsculas>` (ex: `COGNITO_CLIENT_SECRET_CUSTOMER1`, `COGNITO_CLIENT_SECRET_CUSTOMER2`) em vez de um único `COGNITO_CLIENT_SECRET`.

**Motivação:** o `callback-handler` atende múltiplos tenants em um único pod. Ao processar o callback, ele precisa da secret do tenant específico. A convenção permite lookup dinâmico via `os.environ[f"COGNITO_CLIENT_SECRET_{tenant_key}"]` sem hardcode ou listas.

**Impacto:** o K8s Secret `callback-handler-secret` no namespace `auth` deve conter uma chave por tenant. Scripts 13 e 17 constroem esse Secret com todas as chaves antes de reiniciar o deployment.

### Validação de tenant por `custom:tenant_id`, não por domínio de e-mail

A primeira implementação do `callback-handler` derivava o tenant a partir do domínio do e-mail do usuário (ex: `@empresa.com` → `customer1`). Isso quebrou com contas Microsoft pessoais (MSA):

- Usuário `silvio_silva@msn.com` se autentica via Microsoft OIDC
- O claim `email` no token Cognito contém `smsilva@gmail.com` (e-mail principal da conta Microsoft)
- O discovery service retornou `customer1` para `gmail.com`, mas o usuário pertence ao `customer2`

**Correção:** usar o claim `custom:tenant_id` injetado pelo **Pre-Token Generation Lambda** do Cognito. O Lambda recebe o `client_id` do App Client e injeta o tenant correto diretamente no token — independente de qual IdP foi usado ou qual e-mail foi retornado.

```python
def _extract_tenant_id(id_token: str) -> str | None:
    claims = pyjwt.decode(id_token, options={"verify_signature": False}, algorithms=["RS256", "HS256"])
    return claims.get("custom:tenant_id")
```

**Princípio:** identidade de tenant deve vir de uma fonte autoritativa server-side (Lambda/Cognito), não de dados federados do IdP externo que podem variar ou ser manipulados.

### `env.secrets` como fonte única de verdade para credenciais do lab

O arquivo `scripts/env.secrets` concentra todas as credenciais sensíveis. Scripts que geram secrets dinamicamente (ex: `STATE_JWT_SECRET`, `COGNITO_CLIENT_SECRET_*`) devem:

1. Verificar se a variável já está definida antes de gerar
2. Persistir o valor em `env.secrets` com `sed -i` para que sessões futuras não regenerem
3. Carregar `env.secrets` no início (bloco padrão):

```bash
secrets_file="$(dirname "$0")/env.secrets"
if [[ -f "${secrets_file}" ]]; then
  . "${secrets_file}"
fi
```

Isso evita que secrets geradas em uma sessão se percam e causem inconsistência (ex: `STATE_JWT_SECRET` diferente entre `platform-frontend` e `callback-handler` em clusters distintos).

---

## Backlog — por prioridade

### P1 — Quick wins (fácil + alto valor)

- [x] **Completar script destroy**: os recursos abaixo são criados pelos scripts mas não são removidos pelo `destroy`
  - [x] Cognito: custom domain `idp.wasp.silvios.me` (deve ser removido antes do User Pool)
  - [x] Cognito: User Pool `wasp-platform` (inclui IdPs Google/Microsoft e App Clients)
  - [x] Azure DNS: CNAME `idp.wasp.silvios.me` → CloudFront (o destroy remove `*` e `@`, mas não `idp`)
  - [x] Lambda: função `wasp-pre-token-generation`
  - [x] IAM: role `wasp-pre-token-lambda-role` (com inline policy `DynamoDBTenantRegistry`)
  - [x] IAM: role `wasp-discovery-irsa` (com inline policy `DynamoDBTenantRegistryRead`)
  - [x] DynamoDB: tabela `tenant-registry`
- [x] **Verificar propagação DNS pós Global Accelerator**: o script `07b` já mostra os A records
  configurados no Azure DNS, mas não confirma resolução real. Acrescentar ao final:
  `dig +short wasp.silvios.me @8.8.8.8` e comparar com os IPs retornados pelo Global Accelerator.
- [x] **Limpar IDs gerados antes de recriar recursos**: script `scripts/reset-session` criado.
  Zera variáveis dinâmicas de `env.conf` (IDs Cognito, ARN Global Accelerator) e remove linhas
  de `env.secrets` (secrets geradas + JWTs de teste). Suporta `--dry-run` e `--yes`.
  Rodar antes de provisionar do zero; bootstrap após confirma pré-requisitos.
- [x] **Fix redirect "Try Again"**: `error.html:45` tem `href="/"` que aponta para a raiz do
  `callback-handler` (`auth.wasp.silvios.me/`), que retorna `{"detail": "Not Found"}`.
  Fix: passar `login_url` no contexto do `_render_error` e usar `href="{{ login_url }}"` no template.
  O valor deve ser `https://wasp.silvios.me` (lido de env var `PLATFORM_URL` ou equivalente).

### P2 — Melhorias importantes (médio esforço)

- [x] **Build como pré-requisito — discovery**: scripts 13 e 17 já integram build+push+deploy em
  sequência (`set -euo pipefail` garante que falha de build aborta o deploy). Gap específico: script
  17 reconstrói apenas `platform-frontend` e `callback-handler`. Se `discovery` for modificado,
  é necessário re-executar o script 13 — isso não é óbvio. Documentado no CLAUDE.md (Gotchas).
- [ ] **Logging DEBUG**: nenhum dos 3 serviços configura logging explicitamente (usam padrão uvicorn INFO).
  Adicionar `LOG_LEVEL` env var nos ConfigMaps e configurar `logging.basicConfig` em cada `main.py`.
  Caminho de diagnóstico para "Authentication failed: Tenant not configured.":
  1. `kubectl logs -n auth deploy/callback-handler`
  2. CloudWatch Logs: `/aws/lambda/wasp-pre-token-generation`
  3. Cognito User Pool → Logging (requer configuração de log group no CloudWatch)
- [ ] **Erros 500 não tratados**: o `discovery` faz chamadas boto3 ao DynamoDB sem try/except — se a
  IAM policy `DynamoDBTenantRegistryRead` estiver ausente na role `wasp-discovery-irsa`, o serviço
  retorna 500 genérico sem log útil. Envolver chamadas DynamoDB em tratamento de `ClientError`
  e retornar mensagem de erro estruturada.
- [ ] **UI — melhorias de UX**: após login bem-sucedido, o usuário é redirecionado direto para o
  httpbin do tenant (`customer1.wasp.silvios.me`). Não há página de boas-vindas. Melhorias:
  criar landing page por tenant com nome do usuário (claim `name` do JWT no cookie `session`),
  link para `/get` e link de logout. Requer novo template ou serviço por namespace de tenant.
- [ ] **Nomes expressivos para recursos de rede**: script 01 já nomeia todos os recursos com prefixo
  `${cluster_name}` (ex: `wasp-calm-crow-ndx4-vpc`). O problema é o sufixo aleatório gerado pelo
  eksctl, que muda a cada recriação do cluster. Avaliar usar `cluster_name` fixo em `env.conf`
  (ex: `wasp-eks-lab`) para que VPC e subnets tenham nome estável entre sessões.

### P3 — Exploração / futuro (DNS / failover)

- [ ] **Subdomínios com Global Accelerator compartilhado por par de regiões**: decidido que tenants
  sem failover usam CNAME direto para o ALB; tenants premium compartilham um GA por par de regiões
  (ex: `us-east-1 → eu-west-1`). Ver decisão completa em `docs/decisoes-tecnicas.md` (seção
  "DNS por tenant — CNAME vs Global Accelerator"). Implementação no `waspctl` Fase 3.

### P3 — Exploração / futuro

- [ ] **cluster-admin → escopo mínimo (SEC-004)**: script 03 usa `AmazonEKSClusterAdminPolicy` com
  `--access-scope type=cluster`. O EKS Access API suporta `type=namespace` para restringir por
  namespace. Para o lab (deploy em múltiplos namespaces), o caminho prático é criar uma política
  customizada via `aws eks create-access-policy` ou usar RBAC K8s com `ClusterRole` menos permissivo.
- [ ] **DynamoDB multiregion (Global Tables)**: criar a tabela `tenant-registry` em múltiplas regiões
  e habilitar replicação. Cada cluster EKS apontaria para sua região local, com replicação automática
  entre elas. Pré-requisito para o cenário multi-cluster do `waspctl`.
- [ ] **Credenciais externas em SSM Parameter Store**: AWS SSM Parameter Store (SecureString) é
  gratuito para parâmetros standard e já está disponível na conta. Alternativa sem custo ao
  Secrets Manager ($0.40/secret/mês). Azure Key Vault também tem tier gratuito. Avaliar migrar
  `GOOGLE_CLIENT_SECRET`, `AZURE_CLIENT_SECRET` do `env.secrets` para SSM.
- [ ] **`waspctl network proxy`**: explorar comando para provisionar cluster EKS completo e
  integrá-lo ao Global Accelerator. Conceito:
  ```
  waspctl network proxy list          # lista proxies (global, regional)
  waspctl network proxy \
    --name global \
    --add-cluster my-cluster-1        # associa cluster ao proxy global
  ```
- [ ] **Links para scripts no mkdocs**: `operacoes/passo-a-passo.md` é o lugar natural para
  acrescentar links diretos aos scripts em `scripts/`. Atualmente o mkdocs não referencia
  os arquivos de script.

- [ ] **Provisionar EKS com CNI Cillium em ENI (Elastic Network Interface) mode**: Ativado com IPAM (IP Address Management).

- [ ] **Istio com Ambient Mesh**: implementar e verificar possíveis limitações.

- [ ] **Padronizar referencias às variáveis de ambiente**: COGNITO_CLIENT_SECRET e COGNITO_CLIENT_SECRET_CUSTOMER1/2 estão misturados. Padronizar para a convenção `COGNITO_CLIENT_SECRET_<TENANT_ID>` nos documentos e verificar se o código dos serviços está 100% compatível.

- [ ] **Rever informação duplicada entre documentos**: exemplo: `AWS ALB  (subnets públicas, HTTPS terminado via ACM)` aparece tanto em `docs/index.md` (topologia) quanto em `docs/decisoes-tecnicas.md` (ALB). Manter a informação atualizada e consistente entre os documentos é um desafio. Avaliar se vale a pena centralizar detalhes técnicos no `decisoes-tecnicas.md` e deixar o `index.md` mais enxuto, focado na visão geral.
