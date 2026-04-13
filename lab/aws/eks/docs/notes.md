# Notas sobre a última execução

## Global Accelerator requer `--region us-west-2`

O serviço AWS Global Accelerator é global e seu endpoint de API é exclusivamente `globalaccelerator.amazonaws.com` — sem sufixo regional. Ao passar `--region us-east-1`, a AWS CLI tenta `globalaccelerator.us-east-1.amazonaws.com`, que não existe, resultando em:

```
aws: [ERROR]: Could not connect to the endpoint URL: "https://globalaccelerator.us-east-1.amazonaws.com/"
```

**Correção:** usar `--region us-west-2` em todos os comandos `aws globalaccelerator` (a AWS CLI roteia para o endpoint global a partir dessa região). O script `07b-configure-global-accelerator` foi corrigido.

---

- Lembrar de tentar gerar vpcs, subnets, nat gateways, e internet gateways com nomes mais expressivos, para facilitar a identificação depois.

- Explorar a ideia do waspctl provisionar uma instancia de cluster eks com tudo que ele precisa para receber tráfego e obter informacoes dele para configurar posteriormente com o global accelerator. Talvez possa ser algo como:

```bash
waspctl network proxy list

NAME      TYPE
global    global
regional  regional

waspctl network proxy \
  --name global \
  --add--cluster my-cluster-1
```

- Atualmente concedendo cluster-admin para o usuário atual. Investigar a melhor forma de criar uma Policy e associar ao usuário para limitar os privilégios.

- Testar DynamoDB multiregion (Global). Uma região para cada cluster EKS.

- Obter informações do domínio wasp.silvios.me após configurar o Global Accelerator, para verificar se o CNAME aponta para o endpoint do Global Accelerator. Acrescentar esse passo no final do script `07b-configure-global-accelerator`.
  - usar dig e nslookup para verificar o CNAME e o endpoint do Global Accelerator.

- Senhas externas: já deixar em um AWS Secret Manager? (Talvez um Azure Key Vault não gera custos para o Lab).

- Aumentar o nível de logging dos serviços para DEBUG, para facilitar a identificação de problemas.

- Quando ocorre erro de logon "Authentication failed: Tenant not configured.", ao clicar em "Try Again" no wasp.silvios.me, deve redirecionar para a página d login novamente. Atualmente redireciona para auth.wasp.silvios.me e mostra:

```json
{
"detail": "Not Found"
}
```

- Melhorar a interface mostrando que o usuário logou e colocando links para chamar /get que cai no httpbin

- Criar link para logoff

- Criar página de Profile

- Sempre que atualizar build das imagens, não usar a mesma tag. Atualizar CLAUDE.md do lab para recomendar usar o hash do commit como tag, para garantir que o rollout do Kubernetes detecte a mudança de imagem e reinicie os pods. Exemplo:

```bash
image_tag="$(git -C "${services_dir}" rev-parse --short HEAD)"
```

  **Causa técnica:** com `imagePullPolicy: IfNotPresent` (padrão para tags que não são `:latest`), o Kubernetes não re-faz o pull se a tag já está em cache no node — mesmo após `rollout restart`. Trocar a tag é a única forma de garantir que o novo código seja carregado sem alterar a política de pull.

- Como melhorar o DEBUG em casos de erro? 
  - Como saber o motivo do erro "Authentication failed: Tenant not configured."? Verificar logs do Lambda de Pre-Token Generation, do Cognito, e do serviço de autenticação no EKS?
