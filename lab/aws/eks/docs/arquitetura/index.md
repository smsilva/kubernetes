# Arquitetura

O lab provisiona uma plataforma SaaS multi-tenant sobre EKS. A camada de infraestrutura cobre VPC, ALB, WAF e Istio. A camada de autenticação adiciona Cognito como hub de federação de identidade, DynamoDB para o registro de tenants, e três microserviços que orquestram o fluxo de login.

## Diagrama de topologia

```
       sara@customer1.com                        motoko@customer2.com
                │                                          │
                └─────────────────────┬────────────────────┘
                                      ▼
                               wasp.silvios.me
                                      │
                            Global Accelerator
                                      │
                ┌─────────────────────┴────────────────────┐
                ▼                                          ▼
     platform-us-east-1-wasp                  platform-eu-central-1-wasp
          (us-east-1)                              (eu-central-1)
                │                                          │
                ▼                                          ▼
        discovery-service                          discovery-service
                │                                          │
                ▼                                          ▼
   customer1.wasp.silvios.me                 customer2.wasp.silvios.me
                │                                          │
     ┌──────────┴─────────┐                                │
     ▼                    ▼                                ▼
customer1-us-east-1  customer1-us-west-1         customer2-ap-east-1
```

## Subdomínios e roteamento

| Subdomínio | Destino | Namespace K8s | Via |
|---|---|---|---|
| `wasp.silvios.me` | platform-frontend | `platform` | ALB → Istio |
| `idp.wasp.silvios.me` | Cognito Hosted UI | — | CloudFront (Azure DNS CNAME) |
| `auth.wasp.silvios.me` | callback-handler | `auth` | ALB → Istio |
| `discovery.wasp.silvios.me` | discovery service | `discovery` | ALB → Istio |
| `customer1.wasp.silvios.me` | app do tenant | `customer1` | ALB → Istio |

!!! note "DNS"
    O domínio `wasp.silvios.me` é gerenciado em **Azure DNS** (subscription `wasp-sandbox`, resource group `wasp-foundation`), não no Route 53. Os scripts usam `az network dns record-set` em vez de `aws route53`.

## Recursos principais

| Recurso | Identificador |
|---|---|
| Cluster EKS | `wasp-calm-crow-ndx4` |
| Região | `us-east-1` |
| VPC | `vpc-03cb9d83815b52ee1` |
| Certificado ACM | `arn:aws:acm:us-east-1:221047292361:certificate/59ab7614-fa1b-4dba-9f43-7c775cfa5bac` |

## Páginas desta seção

- [Fluxo de Tráfego](fluxo-trafego.md) — detalhes da stack ALB → WAF → Istio → App
- [Autenticação Multi-tenant](../fluxo-autenticacao-multitenant.md) — fluxo de login, Cognito, DynamoDB e isolamento JWT
- [Decisões Técnicas](../decisoes-tecnicas.md) — trade-offs e backlog de decisões abertas
