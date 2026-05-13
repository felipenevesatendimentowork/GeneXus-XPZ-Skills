---
name: xpz-skills-setup
description: Audita e mantém o registro global das skills XPZ nas ferramentas de agente instaladas na máquina (Codex, Claude Code, Cursor, OpenCode), com verificação pós-git-pull e oferta de resolução de gaps
---

# xpz-skills-setup

Audita e mantém o registro global das skills XPZ nas ferramentas de agente instaladas
na máquina. Detecta quais skills existem no repositório, compara com o que está
registrado em cada ferramenta e apresenta um relatório com oferta de resolução antes
de qualquer ação.

Esta skill opera sobre o repositório de skills XPZ, não sobre uma KB GeneXus. Deve
ser executada após `git pull` no repositório e na primeira configuração do ambiente
de um novo usuário.

---

## GUIDELINE

- Inventariar todas as subpastas com `SKILL.md` na raiz do repositório — essas são
  as skills gerenciáveis por esta skill
- Para cada ferramenta, verificar se o diretório global de skills existe antes de
  tentar registrar qualquer coisa
- Detectar quais ferramentas estão instaladas na máquina — não assumir que todas
  estão presentes (ver `## DETECÇÃO DE INSTALAÇÃO`)
- Considerar a compatibilidade cruzada antes de classificar uma skill como ausente
  em Cursor ou OpenCode — ver `## ESTRATÉGIA DE REGISTRO`
- Classificar cada skill por ferramenta: **OK**, **coberta por compatibilidade**
  (registrada em diretório que a ferramenta lê por compatibilidade, sem registro
  nativo nela), **ausente**, **órfã** (registrada mas não existe mais no repo) ou
  **quebrada** (symlink/junction inválido)
- Apresentar relatório consolidado por ferramenta antes de qualquer ação
- Oferecer resolver cada gap identificado — nunca agir silenciosamente
- Aguardar confirmação explícita do usuário antes de criar ou remover qualquer vínculo
- No Windows, tentar **symlink** como mecanismo preferencial; se falhar por permissão,
  cair automaticamente para **junction** e informar ao usuário o que foi usado e por quê
- Nunca copiar arquivos como alternativa a symlink/junction — cópia gera
  desatualização silenciosa após `git pull`
- Não instalar as ferramentas — apenas gerenciar o registro das skills dentro delas
- Não registrar skills de outros repositórios (ex: `nexa`)
- Não tocar em configurações das ferramentas além do diretório de skills
- Verificar existência de diretórios com `Test-Path` individual por ferramenta — nunca
  agrupar em hashtable ou bloco de verificação coletiva

## CAMINHOS DE SKILLS POR FERRAMENTA

Os caminhos abaixo são os esperados no Windows. Verificar a existência de cada
caminho antes de usar — não assumir que estão criados. A coluna "também lê de"
indica caminhos onde a ferramenta detecta skills por compatibilidade cruzada
oficial, mesmo sem registro nativo no caminho dela.

| Ferramenta | Caminho nativo (USER) | Também lê de (compatibilidade) |
|---|---|---|
| Codex | `~/.agents/skills/` | `~/.codex/skills/` aparece como localização de skills empacotadas com o produto (`.system/`) e como caminho histórico de instalações antigas; manter monitorado |
| Claude Code | `~/.claude/skills/` | — |
| Cursor | `~/.cursor/skills/` ou `~/.agents/skills/` | `~/.claude/skills/`, `~/.codex/skills/` |
| OpenCode | `~/.config/opencode/skills/` ou `~/.agents/skills/` | `~/.claude/skills/` |

`~` no Windows resolve para `%USERPROFILE%`. Não confundir `~/.config/opencode/`
(caminho oficial de configuração do OpenCode, inclusive no Windows) com
`%APPDATA%/opencode/` (cache do Edge WebView do desktop app, não é diretório de
skills). Não confundir `~/.cursor/skills/` (diretório de skills personalizadas do
usuário) com `~/.cursor/skills-cursor/` (diretório interno do produto Cursor
para skills nativas distribuídas pelo time da Cursor).

## ESTRATÉGIA DE REGISTRO

A skill apresenta duas estratégias e adota a **compacta** como padrão. Aceita a
**expansiva** quando o usuário pedir, sem ruído nem aviso de "fora do padrão".

### Compacta (padrão)

Dois caminhos cobrem as quatro ferramentas:

- `~/.claude/skills/` → Claude Code (nativo), Cursor (compat), OpenCode (compat)
- `~/.agents/skills/` → Codex (nativo USER), Cursor (nativo), OpenCode (compat)

Vantagem: menos symlinks/junctions para manter, menos pontos de falha após
`git pull`. Desvantagem: desinstalar uma skill de uma única ferramenta sem
afetar as demais exige promover para a estratégia expansiva primeiro.

### Expansiva (opt-in)

Quatro caminhos próprios, um por ferramenta:

- `~/.codex/skills/` (Codex — caminho histórico, ainda lido pelas instalações
  atuais; o caminho USER oficial mais recente do Codex é `~/.agents/skills/`,
  então em ambiente novo prefira a compacta)
- `~/.claude/skills/` (Claude Code)
- `~/.cursor/skills/` (Cursor)
- `~/.config/opencode/skills/` (OpenCode)

Vantagem: controle independente por ferramenta. Desvantagem: cada skill aparece
em até quatro vínculos; cada vínculo é um ponto adicional de manutenção.

### Classificação ao auditar

Antes de classificar uma skill como **ausente** em Cursor ou OpenCode, verificar
se já existe registro em algum diretório que aquela ferramenta lê por
compatibilidade (ver `## CAMINHOS DE SKILLS POR FERRAMENTA`). Se existir,
classificar como **coberta por compatibilidade** em vez de **ausente** — o
relatório informa ao usuário que a skill já é detectável e oferece, sem cobrar,
promoção para registro nativo.

## DETECÇÃO DE INSTALAÇÃO

Considerar uma ferramenta instalada quando ao menos uma destas evidências for
verdadeira:

- O executável de CLI está disponível no PATH (`Get-Command codex`, `claude`,
  `cursor`, `opencode` retorna algo), **ou**
- O arquivo principal de configuração existe:
  - Codex: `~/.codex/config.toml`
  - Claude Code: `~/.claude/settings.json` ou `~/.claude/CLAUDE.md`
  - Cursor: `~/.cursor/` com qualquer config interna (ex.: `mcp.json`,
    `skills-cursor/`, `rules/`)
  - OpenCode: `~/.config/opencode/opencode.json` ou
    `~/.config/opencode/opencode.jsonc`

Presença isolada de subdiretório de cache não conta como instalação. Em
particular, `%APPDATA%/opencode/EBWebView/` é apenas cache do Edge WebView do
desktop app — não é evidência de OpenCode CLI configurado.

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- A raiz do repositório de skills é a pasta-pai desta skill — é de lá que o
  inventário de skills deve ser feito.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste
  `SKILL.md`, não do diretório de trabalho corrente.

---

## TRIGGERS

Use esta skill para:
- Verificar se todas as skills XPZ estão registradas globalmente após `git pull`,
  em qualquer ferramenta instalada (Codex, Claude Code, Cursor, OpenCode)
- Configurar o ambiente de um novo usuário que clonou o repositório de skills XPZ
- Detectar skills ausentes, órfãs, com vínculo quebrado ou cobertas apenas por
  compatibilidade cruzada nas ferramentas instaladas
- Registrar uma nova skill adicionada ao repositório
- Remover o registro de uma skill removida do repositório
- Verificar se as instruções globais do usuário (AGENTS.md, CLAUDE.md ou
  equivalente por ferramenta) contêm as práticas recomendadas para uso das
  skills XPZ

Do NOT use this skill para:
- Instalar Codex, Claude Code, Cursor ou OpenCode na máquina
- Registrar skills de outros repositórios (ex: `nexa`, skills GeneXus oficiais)
- Preparar ou auditar a pasta paralela de uma KB GeneXus (use `xpz-kb-parallel-setup`)
- Sincronizar XPZ de uma KB (use `xpz-sync`)

---

## AGENTS.MD RECOMENDADO

As práticas abaixo afetam diretamente o comportamento das skills XPZ em qualquer
ferramenta de agente. Cada ferramenta tem um local global próprio para
instruções persistentes do usuário:

| Ferramenta | Local global de instruções |
|---|---|
| Codex | `~/.codex/AGENTS.md` |
| Claude Code | `~/.claude/CLAUDE.md` |
| OpenCode | `~/.config/opencode/AGENTS.md` (aceita também `~/.claude/CLAUDE.md` como fallback) |
| Cursor | `~/.cursor/rules/<arquivo>.mdc` (pasta de regras globais; o formato `.mdc` exige front-matter `description`/`globs`/`alwaysApply`). `~/.cursor/AGENTS.md` pode ser aceito como alternativa simples em versões recentes; preferir a pasta `rules/` para ambientes com versão estável documentada |

Ao configurar um novo ambiente, verificar se o local global de cada ferramenta
instalada contém ao menos estas regras:

```markdown
## Ferramentas de busca e shell

- Nunca usar `cd "path" && <comando>` — o harness bloqueia esse padrão
  incondicionalmente ("Compound command contains cd with path operation").
  Nenhuma entrada na allowlist contorna esse bloqueio.
- Para listar ou buscar arquivos: usar as ferramentas nativas `Glob` e `Grep`
  com path absoluto.
- Quando inevitável usar o shell, passar o path direto ao comando:
  - `Get-ChildItem -Path "C:\..."` em vez de `cd "C:\..." && Get-ChildItem`
  - `git -C "C:\..." <cmd>` em vez de `cd "C:\..." && git <cmd>`

## Cherry-pick em worktrees

- Ao fazer cherry-pick com `git -C <path>`, sempre passar o hash do commit
  literal — nunca `HEAD@{0}`, `HEAD~1` ou outras refs relativas. Refs em
  `git -C` se resolvem no contexto do path target (main), não da sessão
  de origem; `HEAD@{0}` aponta para o último commit do destino, não do
  worktree onde o commit acabou de ser feito. Capturar o hash do
  `git commit` que acabou de rodar, ou via `git -C <worktree> rev-parse HEAD`.
```

---

## WORKFLOW

1. Localizar a raiz do repositório de skills XPZ (pasta-pai deste `SKILL.md`)
2. Inventariar todas as subpastas com `SKILL.md` — esse é o conjunto gerenciável
3. Para cada ferramenta (Codex, Claude Code, Cursor, OpenCode):
   - Verificar se a ferramenta está instalada na máquina (ver
     `## DETECÇÃO DE INSTALAÇÃO`); se não estiver, pular para a próxima
   - Verificar se o diretório nativo de skills existe (ver
     `## CAMINHOS DE SKILLS POR FERRAMENTA`)
   - Listar os vínculos presentes no diretório nativo e também nos diretórios
     que aquela ferramenta lê por compatibilidade
   - Classificar cada skill do inventário: **OK**, **coberta por
     compatibilidade**, **ausente**, **órfã** ou **quebrada**
4. Apresentar relatório consolidado por ferramenta, declarando explicitamente
   qual estratégia de registro está em uso (compacta por padrão; expansiva se o
   usuário tiver indicado) — ver `## ESTRATÉGIA DE REGISTRO`
5. Para cada gap identificado, oferecer ação de resolução:
   - **Ausente** → criar symlink (ou junction se symlink falhar por permissão)
     no caminho da estratégia ativa
   - **Coberta por compatibilidade** → apenas informar; oferecer promoção para
     registro nativo se o usuário pedir, sem cobrar
   - **Órfã** → remover vínculo do diretório
   - **Quebrada** → recriar vínculo
6. Aguardar confirmação explícita do usuário
7. Executar as correções aprovadas
8. Confirmar resultado por ferramenta
9. Verificar se o local global de instruções de cada ferramenta instalada
   contém as práticas recomendadas (seção `## AGENTS.MD RECOMENDADO`); se não
   contiver, apresentar o bloco sugerido e oferecer orientação — nunca editar
   AGENTS.md, CLAUDE.md, regras `.mdc` ou equivalentes do usuário
   automaticamente
