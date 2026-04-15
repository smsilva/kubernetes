# Lessons Learned — Lab Local (k3d + Keycloak + Istio)

Problemas encontrados e soluções aplicadas durante o desenvolvimento e execução do lab local.
Documento de referência para reproduzir o ambiente ou diagnosticar falhas em novas execuções.

---

## Keycloak 26

### Bitnami removeu imagens do Docker Hub

A imagem `bitnami/keycloak` foi removida do Docker Hub. Qualquer referência a ela resulta em
`pull access denied`.

**Solução:** usar a imagem oficial `quay.io/keycloak/keycloak:26.1` com `start-dev` e importar
via `k3d image import` antes do deploy. Setar `imagePullPolicy: Never`.

---

### `frontendUrl` no body de criação do realm causa erro 400

Passar `frontendUrl` como campo de topo no JSON de criação (`POST /admin/realms`) retorna
`"unable to read contents from stream"` no KC 26.

**Solução:** criar o realm sem `frontendUrl`, depois configurar via:

```bash
curl --request PUT "${kc_url}/admin/realms/${realm}" \
  --header "Content-Type: application/json" \
  --data '{"attributes":{"frontendUrl":"http://idp.wasp.local:32080"}}'
```

---

### JSON multiline em `--data` causa erro 400 com Istio

Quando o pod tem sidecar Istio, requisições `curl` com JSON formatado em múltiplas linhas via
`--data` causam erros de parse no Keycloak. O Istio modifica o encoding do body.

**Solução:** sempre usar JSON em uma única linha nos `--data` dos scripts bash.

---

### User Profile do KC 26 descarta atributos não declarados

No KC 26 o sistema de User Profile só persiste atributos que foram previamente declarados no
schema do realm. Se `tenant_id` não estiver declarado, ele é ignorado silenciosamente ao criar
usuários — o curl retorna 201 mas o atributo nunca é gravado.

**Solução:** antes de criar usuários, declarar o atributo via `GET /users/profile` → adicionar
`tenant_id` → `PUT /users/profile`:

```bash
profile=$(curl --silent "${kc_url}/admin/realms/${realm}/users/profile" --header "${auth_header}")
python3 << PYEOF
import json
profile = json.loads('${profile}')
if not any(a['name'] == 'tenant_id' for a in profile.get('attributes', [])):
    profile['attributes'].append({
        "name": "tenant_id",
        "displayName": "Tenant ID",
        "permissions": {"view": ["admin"], "edit": ["admin"]},
        "validations": {}, "annotations": {},
        "required": {"roles": []}, "multivalued": False
    })
with open('/tmp/wasp_user_profile.json', 'w') as f:
    json.dump(profile, f)
PYEOF
curl --request PUT "${kc_url}/admin/realms/${realm}/users/profile" \
  --header "${auth_header}" --header "Content-Type: application/json" \
  --data @/tmp/wasp_user_profile.json
```

---

### VERIFY_PROFILE bloqueia login mesmo com `defaultAction: false`

O KC 26 avalia `VERIFY_PROFILE` dinamicamente. Desabilitar apenas como `defaultAction: false`
não é suficiente — o action ainda intercepta o login se detectar campos ausentes.

**Solução:** desabilitar completamente com `enabled: false`:

```bash
curl --request PUT \
  "${kc_url}/admin/realms/${realm}/authentication/required-actions/VERIFY_PROFILE" \
  --header "${auth_header}" --header "Content-Type: application/json" \
  --data '{"alias":"VERIFY_PROFILE","name":"Verify Profile","providerId":"VERIFY_PROFILE","enabled":false,"defaultAction":false,"priority":90,"config":{}}'
```

---

### `grant_type=password` não retorna `id_token` sem `scope=openid`

Para testar tokens diretamente via curl, o `password` grant só inclui `id_token` quando
`scope=openid` está presente:

```bash
curl ... --data "grant_type=password" --data "scope=openid"
```

---

## HAProxy Ingress

### Parâmetro Helm para NodePort fixo

O parâmetro `controller.service.nodePorts.http` não tem efeito. O parâmetro correto é:

```bash
--set "controller.service.httpPorts[0].nodePort=32080"
```

Se o HAProxy for instalado com a porta errada, corrigir via patch sem reinstalar:

```bash
kubectl patch svc haproxy-ingress -n ingress-controller \
  --type='json' \
  --patch='[{"op":"replace","path":"/spec/ports/0/nodePort","value":32080}]'
```

---

### HAProxy precisa de um `Ingress` resource para rotear para o Istio

O HAProxy Ingress Controller não sabe encaminhar para o Istio IngressGateway sem um recurso
`Ingress` que aponte para ele. Sem isso, o HAProxy retorna 503 para qualquer requisição.

**Solução:** criar um `Ingress` catch-all no namespace `istio-ingress` com `defaultBackend`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: istio-passthrough
  namespace: istio-ingress
  annotations:
    kubernetes.io/ingress.class: haproxy
spec:
  defaultBackend:
    service:
      name: istio-ingressgateway
      port:
        number: 80
```

Este recurso foi adicionado ao final do script `04-install-istio`.

---

## Discovery service

### SQLite falha sem volume montado em `/data`

O service `discovery` tenta criar o arquivo `.db` em `/data/tenants.db`. Sem um volume
montado nesse path, o pod inicia mas falha com `unable to open database file`.

**Solução:** adicionar `emptyDir: {}` na spec do deployment:

```yaml
volumeMounts:
  - name: data
    mountPath: /data
volumes:
  - name: data
    emptyDir: {}
```

---

### `DISCOVERY_URL` deve ser in-cluster, não o host externo

Dentro dos pods, `http://discovery.wasp.local:32080` não resolve — o DNS do `/etc/hosts` do
host não é propagado para os containers.

**Solução:** usar o nome de serviço Kubernetes diretamente:

```
DISCOVERY_URL=http://discovery.discovery.svc.cluster.local:8000
```

---

### Domínio no seed deve ser o domínio do e-mail, não o subdomínio da aplicação

A plataforma faz lookup do tenant pelo domínio do e-mail do usuário (`customer1.com`). O seed
deve conter o domínio do e-mail, não o subdomínio da aplicação (`customer1.wasp.local`).

**Errado:**
```json
{ "domain": "customer1.wasp.local", ... }
```

**Correto:**
```json
{ "domain": "customer1.com", ... }
```

---

## callback-handler — cookie de sessão

### `secure=True` impede envio do cookie em HTTP

O valor original `secure=True` hardcoded faz com que o browser (e o curl) nunca envie o
cookie em conexões HTTP. No lab local não há TLS no path externo.

### `domain=".wasp.silvios.me"` não cobre `.wasp.local`

O domínio hardcoded do lab AWS não corresponde ao domínio local.

**Solução (TDD):** adicionar variáveis de ambiente `COOKIE_SECURE` e `COOKIE_DOMAIN`:

```python
cookie_secure = os.getenv("COOKIE_SECURE", "true").lower() != "false"
cookie_domain = os.getenv("COOKIE_DOMAIN", ".wasp.silvios.me")
```

No ConfigMap do lab local:

```yaml
COOKIE_SECURE: "false"
COOKIE_DOMAIN: ".wasp.local"
```

---

## Ordem de diagnóstico recomendada

Ao reprovisionar o lab do zero, verificar nesta ordem se algo falhar:

1. **Health checks** — todos os serviços retornam 200 em `/health`
2. **Token direto** — `grant_type=password&scope=openid` retorna `id_token` com `custom:tenant_id`
3. **Login flow** — `POST /login` → redirect para KC com `state` válido
4. **Callback** — `GET /callback?code=...&state=...` retorna 302 com `set-cookie: session=...`
5. **Cookie** — verificar `Domain=.wasp.local` e ausência de `Secure` no header `set-cookie`
6. **Acesso tenant** — `curl --cookie "session=<jwt>" http://customer1.wasp.local:32080/` retorna 200
7. **Isolamento** — JWT do customer1 rejeitado em customer2 com 403
