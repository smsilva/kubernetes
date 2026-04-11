# Revisão de Segurança

Análise dos scripts do lab com foco em riscos reais para uso em produção ou como base para outros ambientes.

## Issues identificadas

| ID | Severidade | Script | Problema | Status |
|---|---|---|---|---|
| [SEC-002](../security-issues/sec-002.md) | Médio | `04-install-alb-controller` | IAM policy baixada do GitHub sem verificação de hash SHA256 | Aberto |
| [SEC-003](../security-issues/sec-003.md) | Baixo | `08-deploy-sample-app` | Imagem `kennethreitz/httpbin` sem tag ou digest fixo | Aberto |
| [SEC-004](../security-issues/sec-004.md) | Médio | `03-configure-access` | `AmazonEKSClusterAdminPolicy` com escopo de cluster inteiro | Aberto |
| [SEC-005](../security-issues/sec-005.md) | Baixo | `07-configure-alb-ingress` | Security Groups do ALB criados automaticamente, sem restrição de IP de origem | Aberto |
| [SEC-006](../security-issues/sec-006.md) | Médio | `02-create-cluster` | IMDSv1 habilitado por padrão nos nodes — credenciais acessíveis via SSRF | Aberto |
| [SEC-007](../security-issues/sec-007.md) | Baixo | `09-configure-waf` | WAF sem rate limiting — sem proteção contra força bruta ou flood | Resolvido pelo script 15 |

## Critérios de severidade

| Severidade | Critério |
|---|---|
| **Alto** | Risco de comprometimento direto de credenciais de produção ou exfiltração de dados sem condições adicionais |
| **Médio** | Vetor de ataque viável com impacto significativo, mas requer condições adicionais (SSRF, IAM role comprometida, etc.) |
| **Baixo** | Aumento de superfície de ataque mitigado por outras camadas; não explorado diretamente |

## Resumo por camada

| Camada | Issues | Observação |
|---|---|---|
| IAM | SEC-002, SEC-004 | Permissões excessivas e ausência de verificação de integridade no provisionamento |
| Container | SEC-003 | Imagem mutável — `latest` implícito pode mudar entre execuções do lab |
| Kubernetes RBAC | SEC-004 | `cluster-admin` sem escopo de namespace aumenta o raio de blast de um comprometimento |
| Rede | SEC-005 | Security Groups permissivos no ALB — sem allowlist de IPs de origem |
| Node | SEC-006 | IMDSv1 permite que qualquer pod com SSRF acesse credenciais do node |
| WAF | SEC-007 | Ausência de rate limiting em endpoints de autenticação permite força bruta e flood |
