Analise e sincronize os três documentos do lab EKS:

1. Leia `lab/aws/eks/CLAUDE.md`, `lab/aws/eks/HANDOFF.md` e `lab/aws/eks/local/docs/lessons-learned.md`

2. Aplique estas regras:

**CLAUDE.md:**
- Adicionar seção "Lab local (k3d)" se não existir, com: diretório `local/`, domínio `wasp.local`, porta `32080`, referência ao `/etc/hosts`
- Mover conteúdo de sincronização Design→Frontend do HANDOFF para cá como regra permanente (se não estiver já)
- Garantir que as credenciais do lab local (`KEYCLOAK_CLIENT_SECRET`, `COOKIE_SECURE`, `COOKIE_DOMAIN`) estejam documentadas

**HANDOFF.md:**
- Remover seção `## Commits` (histórico está no git)
- Remover itens marcados ✅ ou ~~tachados~~ do `Next Steps`
- Remover gotchas que já estão documentados em `local/docs/lessons-learned.md` — verificar duplicação antes de remover
- Manter: Backlog (P1/P2/P3), runs de execução, Key Files, Context

**Não duplicar** nada que já esteja em `lessons-learned.md`.

Ao final, liste o que foi alterado em cada arquivo.
