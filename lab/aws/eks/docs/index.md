# EKS Lab — ALB + Istio + Autenticação Multi-tenant

Laboratório de EKS que provisiona uma plataforma SaaS multi-tenant completa: VPC com subnets públicas e privadas, ALB com TLS, Istio IngressGateway, WAF, e uma stack de autenticação federada com Amazon Cognito e DynamoDB. Suporta múltiplos Identity Providers (Google, Microsoft, Okta, Auth0, Keycloak) por tenant.

## Componentes provisionados

| Componente | Tipo | Descrição |
|---|---|---|
| VPC `10.0.0.0/16` | AWS | Rede isolada com 2 subnets públicas e 2 privadas em AZs distintas |
| Internet Gateway | AWS | Tráfego de entrada e saída nas subnets públicas |
| NAT Gateway + EIP | AWS | Tráfego de saída das subnets privadas com IP público fixo |
| Route Tables | AWS | Roteamento público (via IGW) e privado (via NAT GW) |
| EKS Cluster | AWS | Control plane gerenciado, versão `1.34`, OIDC provider habilitado para IRSA |
| Managed Node Group | AWS | 2–5 nós `t3.medium` nas subnets privadas, IMDSv2 obrigatório |
| IAM Access Entry | AWS | Permissão `cluster-admin` para o caller IAM via EKS Access API |
| AWS Load Balancer Controller `v3.2.1` | Kubernetes | Operador que gerencia o ALB a partir de recursos `Ingress` |
| IAM Role (IRSA) | AWS | Role vinculada ao service account do ALB Controller via OIDC |
| ALB | AWS | Load balancer internet-facing, TLS terminado via ACM, redireciona HTTP→HTTPS |
| ACM Certificate | AWS | Certificado Let's Encrypt importado para `*.wasp.silvios.me` |
| Istio | Kubernetes | `istio-base` (CRDs), `istiod` (control plane), `istio-ingressgateway` (ClusterIP) |
| WAF WebACL | AWS | Regras gerenciadas AWS (CRS, KnownBadInputs, IP Reputation) + rate limiting |
| DynamoDB | AWS | Tabela `tenant-registry` com configuração de tenants e IdPs |
| Amazon Cognito | AWS | User Pool como hub de federação, custom domain no ACM |

## Fluxo de tráfego

```
Internet
   │
   ▼
AWS ALB  (subnets públicas, HTTPS terminado via ACM)
   │       WAF WebACL: CRS + KnownBadInputs + IP Reputation + rate limiting
   │       Shield Standard: ativo por padrão
   ▼
Istio IngressGateway  (namespace: istio-ingress, ClusterIP)
   │       pods nas subnets privadas, tráfego via target-type ip
   ▼
Aplicações  (namespaces com sidecar injection habilitado)
```

## Topologia multi-região

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
```

## Navegação

<div class="grid cards" markdown>

-   **Arquitetura**

    ---

    Topologia, fluxo de tráfego detalhado, autenticação multi-tenant e decisões técnicas.

    [:octicons-arrow-right-24: Ver Arquitetura](arquitetura/index.md)

-   **Operações**

    ---

    Passo a passo de provisionamento (scripts 01–17), onboarding de novos tenants e teardown.

    [:octicons-arrow-right-24: Ver Operações](operacoes/index.md)

-   **Serviços**

    ---

    Os três microserviços Python/FastAPI: Discovery, Platform Frontend e Callback Handler.

    [:octicons-arrow-right-24: Ver Serviços](servicos/index.md)

-   **Segurança**

    ---

    Revisão de segurança dos scripts com severidade, vetor de ataque e status de mitigação.

    [:octicons-arrow-right-24: Ver Segurança](seguranca/index.md)

</div>
