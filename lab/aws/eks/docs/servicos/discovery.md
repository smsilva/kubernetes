# Discovery Service

> Dado um domínio de e-mail, retorna a configuração do tenant correspondente consultando a tabela DynamoDB `tenant-registry`.

## Responsabilidade

Única responsabilidade: mapear `domínio de e-mail → TenantConfig`. É chamado por:

- `platform-frontend` — ao submeter o formulário de login, para descobrir qual IdP usar
- `callback-handler` — para validar que o domínio do token pertence ao tenant esperado

## API

### `GET /tenant`

Retorna a configuração do tenant para o domínio informado.

**Parâmetros:**

| Parâmetro | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `domain` | string (query) | sim | Domínio do e-mail (ex: `customer1.com`) |

**Respostas:**

=== "200 OK"

    ```json
    {
      "tenant_id": "customer1",
      "tenant_url": "customer1.wasp.silvios.me",
      "client_id": "<cognito-app-client-id>",
      "idp_name": "Google",
      "idp_pool_id": "<pool-id>"
    }
    ```

=== "404 Not Found"

    ```json
    {
      "detail": "Tenant not found for domain: customer1.com"
    }
    ```

### `GET /health`

```json
{"status": "ok"}
```

## Modelo TenantConfig

Definido em `services/discovery/app/models.py`:

| Campo | Tipo | Descrição |
|---|---|---|
| `tenant_id` | `str` | Identificador único do tenant (ex: `customer1`) |
| `tenant_url` | `str` | Hostname do tenant sem scheme (ex: `customer1.wasp.silvios.me`) |
| `client_id` | `str` | Cognito App Client ID do tenant |
| `idp_name` | `str` | Nome do IdP configurado no Cognito (ex: `Google`, `MicrosoftAD-Customer2`) |
| `idp_pool_id` | `str` | ID do User Pool / Pool do IdP |

## Repositório DynamoDB

Implementado em `services/discovery/app/repository.py` (`DynamoDBTenantRepository`).

**Chave primária:** `pk = "domain#<domínio>"` (lowercase)

Mapeamento dos atributos DynamoDB → `TenantConfig`:

| Atributo DynamoDB | Campo no modelo | Observação |
|---|---|---|
| `pk` | — | Chave de lookup: `domain#customer1.com` |
| `tenant_id` | `tenant_id` | |
| `url` | `tenant_url` | |
| `cognito_app_client_id` | `client_id` | |
| `auth.M.cognito_idp_name` | `idp_name` | Atributo aninhado no mapa `auth` |
| `auth.M.cognito_user_pool_id` | `idp_pool_id` | Atributo aninhado no mapa `auth` |

!!! warning "DynamoDB — palavras reservadas"
    `auth` é uma palavra reservada no DynamoDB. Em `--update-expression`, use alias `#auth` com `--expression-attribute-names '{"#auth": "auth"}'`. Ver [gotchas operacionais](../operacoes/index.md#gotchas-operacionais).

## IRSA

O serviço usa IRSA para acessar o DynamoDB sem credenciais hardcoded no container.

Permissão necessária: `dynamodb:GetItem` na tabela `tenant-registry`.

O service account e a IAM role são provisionados pelo script `13-deploy-services`.

## Variáveis de ambiente

| Variável | Descrição |
|---|---|
| `AWS_REGION` | Região AWS onde a tabela DynamoDB está |
| `DYNAMODB_TABLE` | Nome da tabela (padrão: `tenant-registry`) |

## Namespace e deploy K8s

- **Namespace:** `discovery`
- **Imagem:** `silviosilva/wasp-discovery:<sha>`
- **Service account:** vinculado à IAM role via IRSA

## Cache

O repositório usa `@lru_cache` no nível de fábrica do cliente boto3, mas **não faz cache** dos resultados de cada consulta. Cada chamada `GET /tenant` resulta em um `GetItem` no DynamoDB.

A decisão de adicionar cache em memória (TTL, invalidação) está em aberto. Ver [decisoes-tecnicas.md](../decisoes-tecnicas.md).

## Testes

```bash
cd lab/aws/eks/services/discovery
.venv/bin/pytest tests/ -v
```

- `test_tenant_api.py` — testa os endpoints HTTP com `TestClient` do FastAPI
- `test_tenant_repository.py` — testa `InMemoryTenantRepository` e `DynamoDBTenantRepository` (com mock do cliente boto3)
