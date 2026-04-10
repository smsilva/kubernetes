# Decisões técnicas — backlog e trade-offs

Registro de decisões de design tomadas durante o desenvolvimento do lab, com o raciocínio por trás de cada escolha e o que foi adiado conscientemente.

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
