# Diferenças entre o lab local e o lab AWS EKS

O lab local (`local/`) replica o comportamento do lab AWS (`scripts/`) sem dependências de nuvem.
O objetivo é testar interface e comportamento dos serviços sem incorrer em custos de provisionamento.

## Mapa de substituições

| Componente AWS | Equivalente local | Observação |
|---|---|---|
| EKS | k3d (3 servers) | Traefik desabilitado |
| ALB | HAProxy Ingress (NodePort 32080) | Sem TLS termination no ingress |
| ACM + TLS | cert-manager (CA self-signed) | Certificados gerados localmente para `*.wasp.local` |
| Route 53 / Azure DNS | `/etc/hosts` | Entradas manuais apontando para `127.0.0.1` |
| Cognito User Pool | Keycloak (bitnami/keycloak) | Realm `wasp`, client `wasp-platform` |
| Cognito Lambda Pre-Token Generation | Keycloak Protocol Mapper | `oidc-usermodel-attribute-mapper` → claim `custom:tenant_id` |
| Cognito App Client por tenant | Client único `wasp-platform` | Isolamento via `custom:tenant_id`, não via client ID |
| DynamoDB `tenant-registry` | SQLite (stdlib, in-process) | `BACKEND=sqlite`, seed via ConfigMap |
| IRSA (IAM Roles for Service Accounts) | Variáveis de ambiente diretas | Sem AWS — `KEYCLOAK_CLIENT_SECRET` em env.secrets |
| Google IdP / Microsoft IdP | Sem IdP externo | `idp_name=""` no seed; `identity_provider` omitido na URL de autorização |
| Docker Hub push | `k3d image import` | `imagePullPolicy: Never` em todos os pods |
| WAF, Global Accelerator | Não implementados | Fora do escopo do lab local |

## Variáveis de ambiente adicionadas aos serviços

Essas variáveis não existem no lab AWS (onde os valores são construídos com URLs fixas do Cognito).
Quando não definidas, os serviços mantêm o comportamento original para compatibilidade com o AWS lab.

| Serviço | Variável | Valor local |
|---|---|---|
| `platform-frontend` | `IDP_AUTHORIZE_URL` | `http://idp.wasp.local:32080/realms/wasp/protocol/openid-connect/auth` |
| `callback-handler` | `IDP_TOKEN_URL` | `http://keycloak.keycloak.svc.cluster.local:8080/realms/wasp/protocol/openid-connect/token` |
| `discovery` | `BACKEND` | `sqlite` |
| `discovery` | `SQLITE_SEED_FILE` | `/seed/tenants.json` (montado do ConfigMap `discovery-seed`) |

## Fluxo de tráfego

```
Browser (localhost)
  → HAProxy NodePort :32080
  → k3d loadbalancer :32080
  → HAProxy pod
  → Istio IngressGateway (ClusterIP)
  → VirtualService
  → Aplicação (namespace com sidecar injection)
```

No AWS o ALB faz TLS termination e encaminha HTTP para o Istio IngressGateway. Localmente o HAProxy recebe HTTP diretamente e encaminha para o Istio — sem TLS no path externo.

## Issuer do JWT

O Keycloak determina o campo `iss` do JWT com base no `frontendUrl` do realm. O script `05-deploy-keycloak` configura:

```
frontendUrl = http://idp.wasp.local:32080
```

Por isso o issuer nos tokens é:

```
http://idp.wasp.local:32080/realms/wasp
```

O `RequestAuthentication` do Istio usa este valor exato. O `jwksUri` aponta para o service interno do cluster para evitar round-trip pelo HAProxy:

```
http://keycloak.keycloak.svc.cluster.local:8080/realms/wasp/protocol/openid-connect/certs
```

## Multi-tenancy local vs AWS

No AWS cada tenant tem um App Client Cognito separado com seu próprio `client_secret`. Localmente todos os tenants usam o mesmo client Keycloak (`wasp-platform`) e portanto o mesmo `client_secret`. O isolamento continua sendo garantido pelo claim `custom:tenant_id` no JWT e pelas `AuthorizationPolicy` do Istio — que é o mecanismo de segurança relevante.

## Sequência de scripts

```
bootstrap              # valida dependências e /etc/hosts
01-create-cluster      # k3d com 3 servers
02-install-haproxy-ingress
03-install-cert-manager
04-install-istio
05-deploy-keycloak     # realm wasp + users de teste + salva KEYCLOAK_CLIENT_SECRET
06-deploy-services     # discovery, platform-frontend, callback-handler, customer1
07-configure-istio-auth
08-deploy-customer2
destroy                # k3d cluster delete (remove tudo)
```

## Requisitos no /etc/hosts

```
127.0.0.1  wasp.local
127.0.0.1  auth.wasp.local
127.0.0.1  discovery.wasp.local
127.0.0.1  idp.wasp.local
127.0.0.1  customer1.wasp.local
127.0.0.1  customer2.wasp.local
```
