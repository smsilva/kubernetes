# Design System — WASP Lab Frontend

Decisões visuais, componentes reutilizáveis e fluxo de validação sem subir o ambiente.

---

## 0. Fontes de verdade

| Camada | Arquivo | Responsabilidade |
|---|---|---|
| **Tokens e componentes** | `design/shared/tokens.css` | CSS custom properties (paleta, dark mode, motion) |
| **Componentes base** | `design/shared/base.css` | Reset, theme-toggle, botões, animações, logo |
| **Documentação narrativa** | `docs/design-system.md` (este arquivo) | Decisões de design, trade-offs, guias de uso |
| **CSS específico** | `services/<svc>/app/static/<svc>.css` | Apenas overrides e componentes exclusivos do serviço |

### Regra

> Toda alteração visual que afeta mais de um serviço deve partir de `design/shared/`. Nunca editar tokens ou componentes compartilhados diretamente nos CSS dos serviços.

### Estrutura de arquivos

```
design/
├── shared/
│   ├── tokens.css    ← edite aqui para mudar cores, dark mode, etc.
│   └── base.css      ← edite aqui para mudar theme-toggle, botões, ripple
└── index.html        ← sandbox de visualização

services/<svc>/app/static/
├── shared -> ../../../../design/shared   (symlink git-tracked, dev local)
└── <svc>.css                             (@import shared + overrides do serviço)
```

### Docker (pre-copy automático)

O Docker BuildKit não segue symlinks fora do build context. O script `scripts/13-deploy-services` resolve isso automaticamente: antes de cada `docker build` dos serviços frontend ele substitui o symlink por uma cópia real de `design/shared/`, e restaura o symlink logo após.

---

## 1. Preferências de design

- Paleta baseada em Google Material You: primária `#1A73E8`, superfícies neutras
- Suporte obrigatório a dark mode via `[data-theme]` + `prefers-color-scheme`
- Todos os tokens centralizados em `:root` dentro de `app.css`
- Tipografia: Roboto para texto, Roboto Mono para código/JSON
- Border-radius grandes (28px) nos cards, menores (8px) em blocos internos
- Transições de tema: `250ms ease` em `background-color` e `color`
- Efeito ripple em botões filled

---

## 2. Validar design sem subir o ambiente

### Sandbox (recomendado)

O arquivo `design/index.html` é um sandbox autocontido com todas as telas (home, test, profile, login), dados mockados e navegação entre views. Os CSS reais dos serviços são carregados via paths absolutos — editar `app.css` ou `login.css` e recarregar o browser já reflete.

**Para mudanças em tokens ou componentes base**, edite `design/shared/tokens.css` ou `design/shared/base.css` diretamente — o efeito é imediato no sandbox sem reiniciar o servidor.

```bash
# Obrigatório: servir a partir de lab/aws/eks/, não de design/
# O Python http.server bloqueia "../" — os paths /services/... só resolvem da raiz
cd lab/aws/eks
python3 -m http.server 8080
```

Acessar: **http://localhost:8080/design/**

> Os `@import` dentro dos CSS dos serviços resolvem via os symlinks `app/static/shared -> ../../../../design/shared`, que o Python http.server segue corretamente.

### O que o sandbox cobre

| Tela | Dados mockados |
|---|---|
| `home` | Avatar, nome, email, tenant badge |
| `test` | 5 test cases com grupos, accordion, run simulado com delay |
| `profile` | Claims primários (sub, email, name) + claims secundários |
| `login` | Floating label, validação de email, estado de erro |

### Checklist visual

- [ ] Light mode
- [ ] Dark mode
- [ ] `prefers-color-scheme: dark` (sem `data-theme`)
- [ ] Tela estreita (< 480px)

---

## 3. Componentes comuns e animações

> **Localização dos componentes compartilhados:** `design/shared/base.css`
> Componentes exclusivos de cada serviço continuam nos respectivos `<svc>.css`.

| Componente | Onde vive |
|---|---|
| Reset `* { box-sizing }` | `base.css` |
| `.theme-toggle` (core) | `base.css` |
| `.btn-filled` | `base.css` |
| `.btn-outlined` | `base.css` |
| `.logo-section`, `.logo-name` | `base.css` |
| `@keyframes ripple`, `card-enter` | `base.css` |
| `.ripple` (element) | CSS do serviço (background varia) |
| `.card` | CSS do serviço (sombras intencionalmente diferentes) |
| `.navbar`, `.accordion`, `.claims-table` | `app.css` (tenant-frontend only) |

### 3.1 Accordion (expand/collapse)

Usado em: `test.html` — lista de casos de teste.

**Comportamento atual:**
- Clique no header abre o body (`display: none → block`)
- Chevron rotaciona 180° (`transition: transform .2s`)
- `aria-expanded` atualizado para acessibilidade

**Animação suave (a implementar):**

```css
.accordion-body {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows 200ms ease;
}
.accordion-body.open {
  grid-template-rows: 1fr;
}
.accordion-body > .accordion-body-inner {
  overflow: hidden;
}
```

Substituir `display: none/block` por toggle da classe `.open`.

### 3.2 Status dot

Indicador de estado de execução de um teste.

| Classe | Cor | Uso |
|---|---|---|
| `.status-idle` | `#dadce0` | Aguardando execução |
| `.status-pass` | `#34a853` | Passou |
| `.status-fail` | `#ea4335` | Falhou |

### 3.3 Badge

```
.badge-ok      /* verde — HTTP 200 */
.badge-deny    /* vermelho — HTTP 403/401 */
.badge-running /* cinza — em execução */
```

### 3.4 Botões

- `.btn-filled`: primário, com ripple e `filter: brightness()`
- `.btn-outlined`: secundário, hover via `background: var(--color-primary-dim)`
- `.btn-sm`: modificador de tamanho (padding e font-size reduzidos)

### 3.5 Copy button

Ícone clipboard → checkmark por 1500ms via troca do atributo `d` do SVG.

### 3.6 Ripple

Elemento `.ripple` injetado via JS no clique, animado com `scale(0→4) + opacity→0`.

---

## 4. Captura de GIFs de documentação

### Ferramentas

```bash
# GUI — selecionar área e gravar
sudo apt install peek

# CLI
sudo apt install byzanz
byzanz-record --duration=4 --x=100 --y=200 --width=600 --height=400 output.gif
```

### Convenção de nomes

```
docs/assets/gifs/<componente>-<comportamento>.gif
```

Exemplos:

```
accordion-expand.gif
accordion-collapse-all.gif
theme-toggle-dark.gif
status-dot-run-all.gif
copy-btn-feedback.gif
```

### GIFs prioritários

- [ ] `accordion-expand.gif` — clique em um item abre com animação
- [ ] `run-all-status.gif` — dots idle → running → pass/fail
- [ ] `theme-toggle.gif` — transição light/dark
- [ ] `copy-btn-feedback.gif` — clipboard → checkmark

---

## 5. Backlog de melhorias

| Item | Descrição | Prioridade |
|---|---|---|
| Animação accordion | Substituir `display:none` por `grid-template-rows` | Alta |
| Skeleton loader | Placeholder animado enquanto testes rodam | Média |
| Toast de notificação | Feedback após "Run all" concluir | Média |
| Responsive navbar | Colapsar links em mobile | Baixa |
