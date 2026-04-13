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

## Observação — aviso vpc-cni OIDC no `02-create-cluster`

O eksctl emitiu um aviso durante a criação do cluster:

```
[!] recommended policies were found for "vpc-cni" addon, but since OIDC is disabled on the cluster,
eksctl cannot configure the requested permissions; the recommended way to provide IAM permissions
for "vpc-cni" addon is via pod identity associations
```

O script `03-configure-access` cria o OIDC provider logo depois e o eksctl atualiza o addon `vpc-cni` com o CloudFormation stack `eksctl-...-addon-vpc-cni` automaticamente. Na prática não causou problema nesta execução. Monitorar se em versões futuras do eksctl o addon `vpc-cni` precisar de intervenção manual.

---

## Global Accelerator requer `--region us-west-2`

O serviço AWS Global Accelerator é global e seu endpoint de API é exclusivamente `globalaccelerator.amazonaws.com` — sem sufixo regional. Ao passar `--region us-east-1`, a AWS CLI tenta `globalaccelerator.us-east-1.amazonaws.com`, que não existe, resultando em:

```
aws: [ERROR]: Could not connect to the endpoint URL: "https://globalaccelerator.us-east-1.amazonaws.com/"
```

**Correção:** usar `--region us-west-2` em todos os comandos `aws globalaccelerator` (a AWS CLI roteia para o endpoint global a partir dessa região). O script `07b-configure-global-accelerator` foi corrigido.

---

- Lembrar de tentar gerar vpcs, subnets, nat gateways, e internet gateways com nomes mais expressivos, para facilitar a identificação depois.

- Explorar a ideia do waspctl provisionar uma instancia de cluster eks com tudo que ele precisa para receber tráfego e obter informacoes dele para configurar posteriormente com o global accelerator. Talvez possa ser algo como:

```bash
waspctl network proxy list

NAME      TYPE
global    global
regional  regional

waspctl network proxy \
  --name global \
  --add--cluster my-cluster-1
```

- Atualmente concedendo cluster-admin para o usuário atual. Investigar a melhor forma de criar uma Policy e associar ao usuário para limitar os privilégios.

- Testar DynamoDB multiregion (Global). Uma região para cada cluster EKS.

- Obter informações do domínio wasp.silvios.me após configurar o Global Accelerator, para verificar se o CNAME aponta para o endpoint do Global Accelerator. Acrescentar esse passo no final do script `07b-configure-global-accelerator`.
  - usar dig e nslookup para verificar o CNAME e o endpoint do Global Accelerator.

- Senhas externas: já deixar em um AWS Secret Manager? (Talvez um Azure Key Vault não gera custos para o Lab).

- Aumentar o nível de logging dos serviços para DEBUG, para facilitar a identificação de problemas.

- Quando ocorre erro de logon "Authentication failed: Tenant not configured.", ao clicar em "Try Again" no wasp.silvios.me, deve redirecionar para a página d login novamente. Atualmente redireciona para auth.wasp.silvios.me e mostra:

```json
{
"detail": "Not Found"
}
```

- Melhorar a interface mostrando que o usuário logou e colocando links para chamar /get que cai no httpbin

- Criar link para logoff

- Criar página de Profile

---

## Naming convention para secrets multi-tenant

Adotar `COGNITO_CLIENT_SECRET_<TENANT_ID em maiúsculas>` (ex: `COGNITO_CLIENT_SECRET_CUSTOMER1`, `COGNITO_CLIENT_SECRET_CUSTOMER2`) em vez de um único `COGNITO_CLIENT_SECRET`.

**Motivação:** o `callback-handler` atende múltiplos tenants em um único pod. Ao processar o callback, ele precisa da secret do tenant específico. A convenção permite lookup dinâmico via `os.environ[f"COGNITO_CLIENT_SECRET_{tenant_key}"]` sem hardcode ou listas.

**Impacto:** o K8s Secret `callback-handler-secret` no namespace `auth` deve conter uma chave por tenant. Scripts 13 e 17 constroem esse Secret com todas as chaves antes de reiniciar o deployment.

---

## Validação de tenant por `custom:tenant_id`, não por domínio de e-mail

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

---

## env.secrets como fonte única de verdade para credenciais do lab

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

- Sempre que atualizar build das imagens, não usar a mesma tag. Atualizar CLAUDE.md do lab para recomendar usar o hash do commit como tag, para garantir que o rollout do Kubernetes detecte a mudança de imagem e reinicie os pods. Exemplo:

```bash
image_tag="$(git -C "${services_dir}" rev-parse --short HEAD)"
```

  **Causa técnica:** com `imagePullPolicy: IfNotPresent` (padrão para tags que não são `:latest`), o Kubernetes não re-faz o pull se a tag já está em cache no node — mesmo após `rollout restart`. Trocar a tag é a única forma de garantir que o novo código seja carregado sem alterar a política de pull.

  **Atenção:** `rollout restart` *é* necessário quando apenas o conteúdo de um `Secret` ou `ConfigMap` muda sem troca de imagem (ex: adicionar `COGNITO_CLIENT_SECRET_CUSTOMER2` ao Secret `callback-handler-secret`). Nesse caso o restart força os pods a remontarem os volumes/env vars atualizados. Script 17 já faz isso explicitamente após aplicar o Secret.

- Como melhorar o DEBUG em casos de erro? 
  - Como saber o motivo do erro "Authentication failed: Tenant not configured."? Verificar logs do Lambda de Pre-Token Generation, do Cognito, e do serviço de autenticação no EKS?

- Acrescentar links para os scripts no mkdocs.

- Verificar se o Cognito user pool está sendo destruído no script destroy.

- Verificar se as tabelas DynamoDB estão sendo destruídas no script destroy.

- Fazer build das imagens como pré-requisitos para os scripts de configuração, para evitar erros de imagem não encontrada.

- Limpar valores das secrets geradas no env.secrets antes de recriar os recursos.

- Verificar nos Services possíveis erros 500 não tratados como no caso da falta de Policy IAM para acessar o DynamoDB.
