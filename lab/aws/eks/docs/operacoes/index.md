# Operações

Esta seção cobre o ciclo de vida completo do lab: provisionamento inicial (scripts 01–17), adição de novos tenants e teardown do ambiente.

## Scripts disponíveis

Todos os scripts ficam em `scripts/`. A configuração global está em `scripts/env.conf`.

| Script | O que faz |
|---|---|
| `01-create-vpc` | VPC, subnets públicas/privadas, IGW, NAT Gateway, route tables |
| `02-create-cluster` | Cluster EKS + node group via eksctl |
| `03-configure-access` | EKS Access API + `AmazonEKSClusterAdminPolicy` para o caller IAM |
| `04-install-alb-controller` | Helm + IRSA para o AWS Load Balancer Controller |
| `05-install-istio` | Helm: `istio/base` + `istiod` + `istio/gateway` |
| `06-import-certificate-acm` | Importa o certificado Let's Encrypt wildcard no ACM |
| `07-configure-alb-ingress` | Recurso `Ingress` + `IngressClass` → provisiona o ALB |
| `08-deploy-sample-app` | `httpbin` no namespace `sample` para validação do fluxo |
| `09-configure-waf` | WAF WebACL com regras gerenciadas + associação ao ALB |
| `10-create-dynamodb` | Tabela DynamoDB `tenant-registry` + item de exemplo (customer1) |
| `11-create-cognito` | User Pool, Google IdP, App Client, Lambda Pre-Token Generation |
| `12-configure-dns-cognito` | Custom domain do Cognito (`idp.wasp.silvios.me`) + CNAME no Azure DNS |
| `13-deploy-services` | Build/push Docker Hub, IRSA do discovery, deploy dos 4 namespaces K8s |
| `14-configure-istio-auth` | `RequestAuthentication` + `AuthorizationPolicy` no namespace `customer1` |
| `15-configure-waf-ratelimit` | Rate limiting WAF para `/login` e `/callback` |
| `configure-idps` | Registra IdP (Google ou Microsoft) + App Client + DynamoDB para um tenant |
| `17-deploy-customer2` | Deploy do namespace `customer2` com autenticação Microsoft |
| `destroy` | Remove todos os recursos na ordem inversa |
| `destroy-auth` | Remove apenas a stack de autenticação (Cognito, DynamoDB, serviços) |

!!! warning "Script pendente"
    `07b-configure-global-accelerator` — deve ser executado entre os scripts 07 e 08. Provisiona dois IPs anycast estáticos (Global Accelerator → ALB) para o apex `wasp.silvios.me`, cujos IPs do ALB são rotativos e não suportam A records estáticos.

## Gotchas operacionais

!!! warning "`tenants.json` deve ter valores reais do Cognito"
    `services/discovery/app/data/tenants.json` é fonte de dados estática. Ao reprovisionar o Cognito, atualizar `client_id` e `idp_pool_id` antes do build, fazer commit e rebuild com nova tag SHA.

!!! warning "`COGNITO_DOMAIN` sem `https://`"
    No ConfigMap `platform-frontend-config`, o campo `COGNITO_DOMAIN` deve ser só o hostname (`idp.wasp.silvios.me`). O código em `auth.py` já adiciona o scheme — colocar a URL completa gera `https://https://idp...`.

!!! warning "DynamoDB — palavras reservadas em `--update-expression`"
    Atributos com nomes reservados (ex: `auth`, `name`, `status`) causam `ValidationException`. Usar `--expression-attribute-names` com alias `#`:
    ```bash
    --update-expression 'SET #auth.field = :val' \
    --expression-attribute-names '{"#auth": "auth"}'
    ```

!!! warning "WAFv2 — `--id` exige UUID, não name"
    ```bash
    # CORRETO — $NF extrai o UUID (último segmento do ARN)
    web_acl_id="$(echo "${web_acl_arn}" | awk -F'/' '{print $NF}')"
    ```

## Páginas desta seção

- [Passo a Passo](passo-a-passo.md) — execução detalhada dos scripts 01–17
- [Onboarding de Customer](../onboarding-novo-customer.md) — como adicionar um novo tenant
- [Destruir o Lab](destruir-lab.md) — teardown completo e parcial
