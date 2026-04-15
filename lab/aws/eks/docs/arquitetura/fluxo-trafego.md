# Fluxo de Tráfego

## Stack de entrada

```
Internet
   │
   ▼
wasp.silvios.me  (DNS APEX → Global Accelerator Anycast IPs estáticos)
   │
   ▼
AWS ALB  (subnets públicas, HTTPS terminado via ACM)
   │       WAF WebACL: CRS + KnownBadInputs + IP Reputation + rate limiting
   │       Shield Standard: ativo por padrão
   ▼
Istio IngressGateway  (namespace: istio-ingress, ClusterIP)
   │       pods nas subnets privadas, tráfego via target-type ip
   ▼
Istio Gateway + VirtualService  (roteamento por Host header)
   ▼
Aplicação  (namespace com sidecar injection)
   │
   Istio RequestAuthentication + AuthorizationPolicy
   (validação JWT Cognito + isolamento por tenant)
```

## Camadas detalhadas

### ALB

- **Subnets:** públicas (`10.0.1.0/24`, `10.0.2.0/24`) em `us-east-1a` e `us-east-1b`
- **TLS termination:** certificado wildcard `*.wasp.silvios.me` via ACM
- **HTTP→HTTPS redirect:** configurado via annotation no Ingress
- **Target:** Istio IngressGateway como `ClusterIP`, usando `target-type: ip` (os pods são o target, não um NodePort)
- **Provisionado por:** AWS Load Balancer Controller `v3.2.1` a partir do recurso `Ingress` + `IngressClass`

### WAF

A WebACL associada ao ALB aplica as seguintes regras na ordem:

| Regra | Proteção |
|---|---|
| `AWSManagedRulesCommonRuleSet` | XSS, SQLi e outros vetores de aplicação comuns |
| `AWSManagedRulesKnownBadInputsRuleSet` | Inputs maliciosos conhecidos (Log4Shell, etc.) |
| `AWSManagedRulesAmazonIpReputationList` | IPs de botnets e infraestrutura de ataque conhecida |
| Rate limit `/login` | 100 req/5min por IP — proteção contra força bruta em credenciais |
| Rate limit `/callback` | 100 req/5min por IP — proteção contra replay de authorization codes |

!!! info "Shield Standard"
    O AWS Shield Standard está ativo por padrão em todos os recursos AWS (ALB, CloudFront) sem custo adicional. Fornece proteção contra ataques DDoS de camadas 3 e 4.

### Istio IngressGateway

- **Namespace:** `istio-ingress`
- **Tipo de serviço:** `ClusterIP` — sem NLB próprio, recebe tráfego diretamente do ALB via IP dos pods
- **Instalado via:** Helm (`istio/gateway`)
- **Responsabilidade:** receber todo o tráfego externo e encaminhá-lo com base nos recursos `Gateway` e `VirtualService`

### Istio Gateway + VirtualService

Cada subdomínio tem um `VirtualService` que roteia o tráfego para o serviço correto com base no `Host` header:

```
wasp.silvios.me           → platform-frontend.platform.svc.cluster.local
auth.wasp.silvios.me      → callback-handler.auth.svc.cluster.local
discovery.wasp.silvios.me → discovery.discovery.svc.cluster.local
customer1.wasp.silvios.me → <app>.customer1.svc.cluster.local
```

### Istio RequestAuthentication + AuthorizationPolicy

Nos namespaces de tenant (ex: `customer1`), o Istio valida o JWT presente no cookie `session`:

- **`RequestAuthentication`:** configura o JWKS URI do Cognito para validação da assinatura do token
- **`AuthorizationPolicy`:** rejeita requests sem JWT válido (`notRequestPrincipals: ["*"]`) e, opcionalmente, restringe por claim (`azp`, `cognito:groups`)

Isso garante que um token emitido para `customer1` não seja aceito no namespace `customer2`.

## Security Groups

Os Security Groups do cluster, dos nodes e do ALB são criados **automaticamente** pelo `eksctl` e pelo ALB Controller — nenhum SG é definido explicitamente nos scripts.

!!! warning "SEC-005"
    Security Groups auto-gerenciados permitem entrada `0.0.0.0/0` no ALB por padrão. Para produção, é recomendado definir SGs dedicados com restrição de IP de origem. Ver [SEC-005](../security-issues/sec-005.md).
