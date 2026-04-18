# Migração para `aws-saas-platform`

Este documento descreve os passos para extrair o lab `lab/aws/eks` do repositório
`smsilva/kubernetes` para um novo repositório independente chamado `aws-saas-platform`.

---

## 1. Criar o novo repositório no GitHub

No GitHub, crie o repositório `aws-saas-platform` com:

- **Description:** EKS lab provisioning a complete multi-tenant SaaS platform: ALB + Istio + Federated Auth with Amazon Cognito, WAF, and DynamoDB tenant registry.
- **Visibility:** Public (ou Private, conforme preferência)
- **Topics:** `aws` `eks` `kubernetes` `istio` `saas` `multi-tenant` `cognito` `terraform` `platform-engineering`
- **NÃO** inicialize com README, .gitignore ou licença

---

## 2. Clonar o repositório original e extrair o subtree

```bash
# Clone o repositório original (se ainda não tiver local)
git clone https://github.com/smsilva/kubernetes.git
cd kubernetes

# Extraia o histórico do subdiretório como branch isolada
git subtree split --prefix=lab/aws/eks --branch eks-lab-split
```

---

## 3. Criar o novo repositório local e importar o histórico

```bash
# Saia do repo original e crie o novo
cd ..
mkdir aws-saas-platform
cd aws-saas-platform
git init

# Importe a branch extraída
git pull ../kubernetes eks-lab-split

# Adicione o remote do novo repositório
git remote add origin https://github.com/smsilva/aws-saas-platform.git

# Envie para o GitHub
git push -u origin main
```

---

## 4. Atualizar referências internas

### `mkdocs.yml`

```yaml
# Antes
site_url: https://smsilva.github.io/kubernetes/
repo_url: https://github.com/smsilva/kubernetes
repo_name: smsilva/kubernetes

# Depois
site_url: https://smsilva.github.io/aws-saas-platform/
repo_url: https://github.com/smsilva/aws-saas-platform
repo_name: smsilva/aws-saas-platform
```

### Links hardcoded na documentação

Busque e substitua ocorrências de paths antigos:

```bash
# Verificar ocorrências
grep -r "smsilva/kubernetes" docs/
grep -r "lab/aws/eks" docs/

# Substituir (ajuste conforme necessário)
find docs/ -name "*.md" -exec sed -i \
  's|github.com/smsilva/kubernetes/tree/main/lab/aws/eks|github.com/smsilva/aws-saas-platform|g' {} +
```

---

## 5. Configurar GitHub Pages no novo repositório

1. Acesse **Settings → Pages** no repositório `aws-saas-platform`
2. Em **Source**, selecione `GitHub Actions` (se usar workflow MkDocs) ou a branch `gh-pages`
3. Verifique se o workflow `.github/workflows/` está presente e apontando para o novo repo
4. Após o primeiro deploy, o site estará em: `https://smsilva.github.io/aws-saas-platform/`

---

## 6. Atualizar o repositório original

No repositório `smsilva/kubernetes`, adicione um aviso no `lab/aws/eks/README.md`:

```markdown
> ⚠️ **Este lab foi movido.**
> O conteúdo deste diretório foi migrado para o repositório independente
> [aws-saas-platform](https://github.com/smsilva/aws-saas-platform).
```

---

## Checklist final

- [ ] Novo repositório criado no GitHub com description e topics
- [ ] Histórico Git preservado via `git subtree split`
- [ ] `mkdocs.yml` atualizado com novo `site_url` e `repo_url`
- [ ] Links hardcoded corrigidos na documentação
- [ ] GitHub Pages configurado e funcionando
- [ ] README do repo original atualizado com link de redirecionamento
- [ ] Workflows de CI/CD (se houver) revisados no novo repo
