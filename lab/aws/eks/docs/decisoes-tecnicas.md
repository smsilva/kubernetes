# Decisões técnicas — backlog e trade-offs

Registro de decisões de design tomadas durante o desenvolvimento do lab, com o raciocínio por trás de cada escolha e o que foi adiado conscientemente.

---

## Referências externas

Artigos que serviram de base para a arquitetura deste lab:

- [Building a Multi-Tenant SaaS Solution Using Amazon EKS](https://aws.amazon.com/pt/blogs/apn/building-a-multi-tenant-saas-solution-using-amazon-eks/) — Toby Buckley e Ranjith Raman (AWS APN Blog)
- [Operating a multi-regional stateless application using Amazon EKS](https://aws.amazon.com/pt/blogs/containers/operating-a-multi-regional-stateless-application-using-amazon-eks/) — Re Alvarez-Parmar (AWS Containers Blog)
- [Amazon EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/) — módulos Terraform de referência para EKS

---

## Roadmap de fases e waspctl

**Status:** Fase 1 em execução; Fases 2 e 3 planejadas

Este lab implementa manualmente a infraestrutura da Fase 1. Em paralelo, o projeto [`waspctl`](https://github.com/silviosilva/waspctl) está sendo desenvolvido como CLI para automatizar o provisionamento dessa mesma topologia.

| Fase | Descrição | Estado |
|---|---|---|
| 1 | Cluster único + Auth Service simples (este lab) | em execução |
| 2 | Platform-cluster separado dos customer-clusters | planejado |
| 3 | Platform-clusters regionais + Global Accelerator + DynamoDB Global Table | planejado |

O `waspctl` seguirá a mesma progressão de fases, abstraindo os scripts manuais em comandos declarativos:

```bash
waspctl sso login

waspctl instance list

NAME     DOMAIN            REGIONS               OWNER

waspctl instance create \
  --name wasp-x3b5 \
  --region us-east-1 \
  --region eu-north-1 \
  --domain wasp.silvios.me

waspctl instance list

NAME      DOMAIN            REGIONS               OWNER
wasp-x3b5  wasp.silvios.me  us-east-1,eu-north-1  administrators

waspctl instance create \
  --name wasp-i4dy \
  --region us-east-1 \
  --domain dev.wasp.silvios.me

waspctl instance list

NAME       DOMAIN               REGIONS               OWNER
wasp-x3b5  wasp.silvios.me      us-east-1,eu-north-1  administrators
wasp-i4dy  dev.wasp.silvios.me  us-east-1             administrators

waspctl customer create \
  --name customer1-us-east-1 \
  --instance wasp-x3b5 \
  --region us-east-1

waspctl tenant create \
  --name customer1 \
  --domain customer1.com \
  --gateway customer1-us-east-1-xt56.wasp.silvios.me

waspctl tenant endpoint add \
  --tenant customer1.com \
  --endpoint customer1-eu-north-1-yh98.wasp.silvios.me
```

---

## ALB Cognito native integration vs Auth Service customizado

**Status:** decisão tomada; Auth Service customizado mantido por flexibilidade

### Contexto

O ALB tem integração nativa com Amazon Cognito: o próprio ALB executa o fluxo OIDC/OAuth e injeta os claims do JWT em headers HTTP antes de encaminhar a requisição ao backend. Isso eliminaria a necessidade do `platform-frontend` e do `callback-handler` como serviços separados.

### Opções avaliadas

**A — ALB Cognito native (OIDC authenticate action)**
O ALB faz o redirect para o Cognito Hosted UI, troca o authorization code por token e injeta `X-Amzn-Oidc-Identity`, `X-Amzn-Oidc-Access-Token` e `X-Amzn-Oidc-Data` (JWT com claims) nos headers. Zero código de autenticação no backend.

**B — Auth Service customizado (solução atual)**
`platform-frontend` recebe o e-mail, resolve o tenant via discovery, constrói a URL de autorização para o Cognito IdP correto e redireciona. `callback-handler` recebe o código, troca por token, valida o tenant e seta o cookie de sessão.

### Decisão: Auth Service customizado (Opção B)

A integração nativa do ALB não oferece controle sobre a seleção dinâmica de IdP por tenant — o ALB autentica contra um único Cognito App Client fixo na listener rule. O Auth Service customizado permite:

- Resolver o tenant pelo domínio do e-mail **antes** de iniciar o fluxo OAuth
- Construir a URL de autorização com o `identity_provider` correto para o tenant
- Validar que o domínio autenticado pertence ao tenant esperado (proteção anti-hijacking)
- Injetar informações de tenant no state JWT para correlação no callback

A integração nativa do ALB é adequada para casos onde todos os usuários autenticam pelo mesmo IdP. Para multi-tenant com IdPs distintos por tenant, o Auth Service customizado é necessário.

---

## API auth options for external clients

**Status:** pendente de decisão

Como autenticar chamadas de `curl`/scripts à API sem passar pelo browser SSO flow.

### Opções avaliadas

**A — Service account token (Kubernetes Secret)**
Criar um `ServiceAccount` dedicado com permissões limitadas e usar o token gerado automaticamente. Simples, sem dependência de AWS, mas token de longa duração (sem expiração por padrão antes do Kubernetes 1.24).

**B — AWS SigV4 (IAM)**
Assinar as requisições com credenciais IAM via `aws-sigv4`. Requer que o API Gateway ou o proxy valide a assinatura. Integra bem com IRSA para workloads no cluster, mas adiciona complexidade no cliente.

**C — Cognito client credentials flow (OAuth 2.0 machine-to-machine)**
Criar um App Client Cognito sem usuário, usar `grant_type=client_credentials` para obter um access token. Token de curta duração, auditável, sem browser. É o padrão para M2M em OAuth 2.0.

**Decisão:** Opção C avaliada como mais alinhada ao padrão OAuth 2.0 para M2M. Implementação adiada — nenhuma opção escolhida ainda.

---

## Secrets por tenant no callback-handler

**Status:** solução temporária em produção no lab; solução ótima documentada e adiada

### Problema

O `callback-handler` precisa do `client_secret` de cada App Client Cognito para trocar o authorization code por token. Com múltiplos tenants, cada um tem seu próprio App Client com secret diferente.

### Solução atual (lab)

Env vars nomeadas por convenção: `COGNITO_CLIENT_SECRET_<TENANT_ID_UPPERCASE>`.
Injetadas via Kubernetes Secret criado/atualizado pelo script de deploy.

```python
tenant_key = login_state.tenant_id.upper()   # "customer1" → "CUSTOMER1"
client_secret = os.environ[f"COGNITO_CLIENT_SECRET_{tenant_key}"]
```

Secret Kubernetes com uma chave por tenant:

```yaml
stringData:
  COGNITO_CLIENT_SECRET_CUSTOMER1: "<secret1>"
  COGNITO_CLIENT_SECRET_CUSTOMER2: "<secret2>"
  STATE_JWT_SECRET: "<jwt-secret>"
```

**Limitação:** adicionar tenant = editar o Secret + rollout do callback-handler. Secrets em base64 no etcd sem encryption at rest por padrão.

### Solução ótima para produção (adiada)

**External Secrets Operator + AWS Secrets Manager**

- ESO sincroniza automaticamente Secrets Manager → K8s Secret
- Rotation gerenciada pela AWS
- Adicionar tenant = criar secret no Secrets Manager, sem tocar no deployment
- Padrão de facto para EKS em produção nessa stack (ESO + ArgoCD)

**Alternativa — SDK call em runtime:**
O callback-handler chama Secrets Manager diretamente usando `tenant_id` como chave. Zero redeployment ao adicionar tenant. Desvantagem: latência extra no caminho crítico do login.

**Quando revisar:** ao escalar além de ~5 tenants ou ao colocar em produção.

---

## Cache no discovery service

**Status:** adiado; sem cache hoje

### Contexto

O discovery service é chamado **duas vezes por login**: uma pelo `platform-frontend` (ao submeter o e-mail) e outra pelo `callback-handler` (para validar que o domínio do e-mail autenticado pertence ao tenant esperado). Cada chamada consulta o DynamoDB. Fora do fluxo de login, o Istio valida o JWT diretamente via JWKS — o discovery não é envolvido.

Para o volume típico de um sistema de login, a latência do DynamoDB é aceitável. O risco real é de **disponibilidade**: se o DynamoDB ou o discovery service ficar indisponível, o login falha.

### Opções avaliadas

**A — Cache em memória com TTL no processo (recomendada)**
Dict com timestamp por domínio. Domínio não encontrado ou expirado vai ao DynamoDB. TTL de 5 minutos elimina a quase totalidade das chamadas (domínios mudam raramente). Zero infra adicional.

**B — ElastiCache (Redis/Memcached)**
Cache compartilhado entre pods e regiões. Útil se o número de pods do discovery crescer muito. Adiciona infra, custo e complexidade operacional — não justifica no estágio atual.

**C — DynamoDB DAX**
Cache gerenciado na frente do DynamoDB, latência de microssegundos. Custo elevado para o padrão de acesso (logins, não queries contínuas). Não justifica.

### Decisão

Opção A avaliada como suficiente para o volume esperado. Implementação adiada até que a latência do DynamoDB se prove um problema real em produção.

### Quando revisar

Ao observar p99 de latência no login acima de 500 ms, ou ao escalar o número de pods do discovery (onde o cache em memória por pod se torna ineficiente).

---

## User Pool único compartilhado vs um por tier/região

**Status:** pendente de decisão

### Contexto

O Cognito User Pool é uma instância global única no lab atual (`us-east-1`). Em uma topologia multi-região com Global Accelerator, o callback pode retornar para qualquer cluster regional — todos precisam validar o JWT emitido pelo mesmo pool.

### Opções

**A — User Pool único global**
Simples, todos os clusters validam o mesmo JWKS. Latência de validação depende do JWKS endpoint do Cognito (geralmente baixa, com cache). Limite de 300 IdPs externos por pool.

**B — Um User Pool por região (alinhado ao Global Accelerator)**
Cada região tem seu pool; o frontend usa o pool da região mais próxima. Elimina dependência cross-region no caminho de autenticação. Adiciona complexidade: o `client_id` por tenant precisa ser replicado por região, e o callback precisa saber para qual pool redirecionar.

### Quando decidir

Ao planejar a expansão multi-região. Para o lab de cluster único, User Pool único é suficiente.

---

## Keycloak self-hosted — risco de SLA acoplado ao customer

**Status:** risco documentado; decisão de aceitar ou mitigar pendente de caso real

### Contexto

Quando um tenant usa Keycloak self-hosted, o Cognito precisa de conectividade de rede para o servidor Keycloak do customer durante o login. Se o Keycloak do customer ficar indisponível, o login do tenant inteiro quebra.

### Opções de mitigação

| Opção | Trade-off |
|---|---|
| Customer expõe Keycloak publicamente com TLS | Mais simples; expõe infra do customer |
| AWS PrivateLink + VPN site-to-site | Mais seguro; complexidade operacional alta |
| Customer migra para Keycloak Cloud (managed) | Elimina o problema; depende de decisão do customer |
| Documentar como risco contratual explícito | Zero custo técnico; SLA da plataforma fica degradado para esse tenant |

### Decisão recomendada

Documentar como risco contratual explícito para qualquer tenant com Keycloak self-hosted. Exigir SLA de disponibilidade do Keycloak como pré-requisito para onboarding ou oferecer tier diferenciado.

---

## Sessão cross-region — tokens JWT stateless

**Status:** decisão tomada para o caso de tokens de acesso; refresh tokens requerem atenção

### Contexto

No Global Accelerator com múltiplos clusters regionais, um usuário pode começar o login em `us-east-1` e ter o callback processado em `eu-central-1`. O JWT emitido pelo Cognito é stateless — qualquer cluster com acesso ao JWKS do Cognito consegue validar.

### Decisão

Tokens JWT de acesso funcionam sem estado compartilhado entre regiões. Cada cluster valida o JWT localmente contra o JWKS do Cognito (com cache local).

Refresh tokens emitidos pelo Cognito são opacos e precisam ser trocados no mesmo User Pool que os emitiu — o Cognito lida com isso globalmente. Se a plataforma armazenar refresh tokens em DynamoDB para renovação transparente, a tabela deve ser uma **DynamoDB Global Table** para acesso local em qualquer região.

---

## Microsoft MSA vs Azure AD corporativo no Cognito

**Status:** decisão tomada

### Contexto

O Cognito suporta dois tipos de issuer para contas Microsoft, e a distinção é necessária antes de criar o IdP:

| Tipo de conta | `oidc_issuer` | Quando usar |
|---|---|---|
| Contas pessoais Microsoft (MSA, Hotmail, Outlook.com) | `https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0` | GUID fixo para MSA — não é um tenant ID real |
| Azure AD corporativo / Google Workspace federado via Azure AD | `https://login.microsoftonline.com/<azure-tenant-id>/v2.0` | Usar o tenant ID real da organização no Azure |

### Decisão

Registrar o IdP no Cognito com o `oidc_issuer` correspondente ao tipo de conta. A confusão mais comum é usar o GUID de MSA para contas corporativas (ou vice-versa), resultando em falha silenciosa na autenticação.

Para tenants SaaS corporativos, o caso esperado é **Azure AD com tenant ID real**. MSA é relevante apenas se a plataforma aceitar contas pessoais Microsoft.

---

## Gateway API vs Ingress clássico no ALB Controller

**Status:** decisão tomada; revisitar quando a série v3.x do ALB Controller estabilizar

### Contexto

O AWS Load Balancer Controller v3.x adicionou suporte à Kubernetes Gateway API (`GatewayClass`, `Gateway`, `HTTPRoute`) a partir da v3.0. Este lab utiliza intencionalmente os recursos clássicos `Ingress` e `IngressClass`.

### Decisão: manter Ingress/IngressClass

A issue [kubernetes-sigs/aws-load-balancer-controller#4674](https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/4674) (aberta em abril de 2026) reporta que o upgrade de `v3.1.0` para `v3.2.1` quebra instalações onde a Gateway API **não está habilitada**, pois os CRDs de `ListenerSet` ficam ausentes. Enquanto esse tipo de problema de compatibilidade não estiver estabilizado, manter `Ingress`/`IngressClass` é a escolha conservadora.

O Istio `Gateway` + `VirtualService` (passo 08) é um recurso do próprio Istio e **não** é afetado por essa limitação do ALB Controller.

### Quando revisitar

- Resolução da issue #4674 e de outros bugs de compatibilidade na série v3.x
- Avaliar `HTTPRoute` → ALB para substituir o `Ingress` atual (`07-configure-alb-ingress`)

---

## STATE_JWT_SECRET em deployments multi-região

**Status:** decisão tomada; implementação da rotação adiada

### Contexto

O `STATE_JWT_SECRET` é o segredo compartilhado entre `platform-frontend` e `callback-handler` para assinar e verificar o state JWT do OAuth flow (proteção CSRF). O Cognito é uma instância global única — o callback retorna para `auth.wasp.silvios.me`, que o Global Accelerator pode rotear para **qualquer** cluster regional.

### Decisão: segredo idêntico em todos os clusters

Se o state JWT foi assinado em `us-east-1` mas o callback cai em `eu-central-1`, o `callback-handler` nessa região precisa verificar a assinatura. Portanto o `STATE_JWT_SECRET` deve ser o mesmo em todos os clusters regionais.

### Implicações

- **Provisionamento:** o segredo deve ser replicado para todas as regiões. Com ESO + Secrets Manager com replicação cross-region, isso é automático.
- **Rotação:** precisa ser coordenada — todos os clusters devem receber o novo segredo simultaneamente, ou aceitar dois segredos durante uma janela de transição (exigiria suporte a múltiplos segredos no `decode_state_token`).
- **Comprometimento:** se o segredo vazar, um atacante pode forjar state JWTs válidos. A expiração curta (10 minutos) limita a janela de exploração — rotation imediata invalida todos os states em voo (usuários precisam reiniciar o login).

### Solução ótima para rotação (adiada)

Suporte a dois segredos simultâneos no `decode_state_token` (tenta verificar com o novo; se falhar, tenta com o anterior). Permite rotação sem downgrade de UX. Implementar junto com a migração para ESO + Secrets Manager.
