# Destruir o Lab

## Teardown completo

```bash
./scripts/destroy
```

Remove todos os recursos na ordem inversa dos scripts de provisionamento. O script aguarda a conclusão de cada etapa antes de prosseguir para a próxima.

!!! danger "ACM não é removido automaticamente"
    O certificado ACM não é removido pelo script `destroy`. Remova manualmente:
    ```bash
    aws acm delete-certificate \
      --certificate-arn arn:aws:acm:us-east-1:221047292361:certificate/59ab7614-fa1b-4dba-9f43-7c775cfa5bac \
      --region us-east-1
    ```

## Teardown parcial — apenas autenticação

Para remover somente a stack de autenticação (Cognito, DynamoDB, serviços K8s) sem derrubar o cluster:

```bash
./scripts/destroy-auth
```

Útil quando você quer reprovisionar os scripts 10–17 sem recriar a infraestrutura base (VPC, EKS, ALB, Istio).

## Ordem de remoção (destroy completo)

| Etapa | O que remove |
|---|---|
| 17 → 10 | Namespaces de tenant, Istio auth policies, WAF rate limiting |
| 9 | WAF WebACL (desassocia do ALB antes de deletar) |
| 8 | Namespace `sample` e app httpbin |
| 7b | DNS Azure: CNAME wildcard `*.domain` e A records do apex |
| 7b | Global Accelerator: endpoint group, listener, accelerator |
| 7 | Recurso `Ingress` (ALB é deletado pelo controller) |
| 6 | Certificado ACM **não é removido** — ver aviso acima |
| 5 | Istio (istiod, istio-base, istio-ingressgateway) |
| 4 | ALB Controller e IRSA role |
| 3 | Access entry EKS |
| 2 | Cluster EKS e node group |
| 1 | VPC, subnets, IGW, NAT Gateway, EIP, route tables |

!!! warning "NAT Gateway + EIP"
    O NAT Gateway e o EIP geram custo por hora mesmo quando o cluster não está em uso. Se pausar o lab sem destruir, considere remover apenas esses recursos para reduzir custos.
