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
  em Cursor — ver `## ESTRATÉGIA DE REGISTRO`
- Antes de classificar uma skill como **ausente** no Codex, verificar ausência em
  **ambos** os diretórios USER que o Codex indexa (`~/.codex/skills/` e
  `~/.agents/skills/`); presença em qualquer um dos dois conta como disponível
  para o Codex — ver `## CAMINHOS DE SKILLS POR FERRAMENTA`
- Classificar cada skill por ferramenta: **OK**, **coberta por compatibilidade**
  (registrada em diretório que a ferramenta lê por compatibilidade, sem registro
  nativo nela), **ausente**, **órfã** (registrada mas não existe mais no repo) ou
  **quebrada** (symlink/junction inválido)
- Apresentar relatório consolidado por ferramenta antes de qualquer ação
- Oferecer resolver cada gap identificado — nunca agir silenciosamente
- Aguardar confirmação explícita do usuário antes de criar ou remover qualquer vínculo
  de skill **e** antes de gravar ou alterar instrucionais globais (passo 9)
- No Windows, tentar **symlink** como mecanismo preferencial; se falhar por permissão,
  cair automaticamente para **junction** e informar ao usuário o que foi usado e por quê
- Nunca copiar arquivos como alternativa a symlink/junction — cópia gera
  desatualização silenciosa após `git pull`
- Não instalar as ferramentas de agente (Codex, Claude Code, Cursor, OpenCode) —
  apenas gerenciar o registro das skills dentro delas. **Exceção:** o `git` é
  pré-requisito de versionamento (não é ferramenta de agente) e **pode ser
  instalado** por esta skill quando ausente, pois sem ele a pasta baixada como
  ZIP não se liga ao repositório oficial — ver `## BOOTSTRAP DO REPOSITÓRIO`
- Não registrar skills de outros repositórios (ex: `nexa`)
- Não alterar configurações gerais das ferramentas fora do âmbito desta skill;
  **exceção explícita:** instrucionais globais cobertos pelo passo 9 do `WORKFLOW`
  (incluindo instalação do MCP Cursor via
  `scripts/Install-CursorGlobalInstructionsMcp.ps1`), apenas **após confirmação
  explícita** do usuário e **sem edição silenciosa**
- Verificar existência de diretórios com `Test-Path` individual por ferramenta — nunca
  agrupar em hashtable ou bloco de verificação coletiva
- Quando o usuário pedir auditoria ou setup **completo** (ex.: após `git pull`,
  primeiro uso do repo de skills), **executar na mesma sessão** o passo 9 do
  `WORKFLOW` sobre instrucionais globais — primeiro **ler e comparar**, depois
  **ofertar correção assistida** onde houver lacuna (espelha o espírito dos
  passos 6–7: nada gravado sem confirmação explícita) — não substituir esse passo
  por oferta genérica do tipo "na próxima mensagem posso auditar", que confunde
  quem espera um relatório fechado nesta execução

## CAMINHOS DE SKILLS POR FERRAMENTA

Os caminhos abaixo são os esperados no Windows. Verificar a existência de cada
caminho antes de usar — não assumir que estão criados. A coluna "também lê de"
indica caminhos onde a ferramenta detecta skills por compatibilidade cruzada
oficial, mesmo sem registro nativo no caminho dela. Para OpenCode, exigir registro
nativo nesta skill para evitar depender de compatibilidade opcional com Claude Code.

| Ferramenta | Caminho nativo (USER) | Também lê de (compatibilidade) |
|---|---|---|
| Codex | `~/.codex/skills/` (`$CODEX_HOME/skills/` por padrão — destino do `$skill-installer` embutido; inclui `.system/` empacotadas com o produto) | `~/.agents/skills/` — segundo âmbito USER que o Codex também indexa (doc oficial OpenAI); não substitui `.codex/skills/` como “lar” do instalador |
| Claude Code | `~/.claude/skills/` | — |
| Cursor | `~/.cursor/skills/` ou `~/.agents/skills/` | `~/.claude/skills/`, `~/.codex/skills/` |
| OpenCode | `~/.config/opencode/skills/` ou `~/.agents/skills/` | — |

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

Três caminhos cobrem as quatro ferramentas sem usar `~/.agents/skills/` como pilar:

- `~/.claude/skills/` → Claude Code (nativo), Cursor (compat)
- `~/.codex/skills/` → Codex (nativo via `$CODEX_HOME/skills/` / instalador), Cursor (compat)
- `~/.config/opencode/skills/` → OpenCode (nativo)

**Opcional:** `~/.agents/skills/` — alguns setups já mantêm junctions aqui porque
Cursor e OpenCode também tratam esse diretório como USER nativo e porque o Codex
indexa esse segundo âmbito USER; **não entra na compacta recomendada** porque
`.claude` + `.codex` + `.config/opencode` já cobrem as quatro ferramentas sem depender
de compatibilidade opcional do OpenCode com Claude Code.

**Dois junctions para o mesmo alvo:** registrar `nome-da-skill` como junction tanto
em `~/.codex/skills/` quanto em `~/.agents/skills/` apontando para a mesma pasta do
repositório não duplica conteúdo em disco — são dois pontos de entrada redundantes.
Útil apenas quando se quer exposição explícita nos dois âmbitos USER do ecossistema;
caso contrário, um único vínculo por skill na compacta basta.

Vantagem: menos symlinks/junctions para manter, menos pontos de falha após
`git pull`. Desvantagem: desinstalar uma skill de uma única ferramenta sem
afetar as demais exige promover para a estratégia expansiva primeiro.

### Expansiva (opt-in)

Quatro caminhos próprios, um por ferramenta:

- `~/.codex/skills/` (Codex — caminho por padrão do instalador `$skill-installer`,
  `$CODEX_HOME/skills/`; coexistência opcional com `~/.agents/skills/` quando se
  quer dois âmbitos USER indexados pelo Codex)
- `~/.claude/skills/` (Claude Code)
- `~/.cursor/skills/` (Cursor)
- `~/.config/opencode/skills/` (OpenCode)

Vantagem: controle independente por ferramenta. Desvantagem: cada skill aparece
em até quatro vínculos; cada vínculo é um ponto adicional de manutenção.

### Classificação ao auditar

Antes de classificar uma skill como **ausente** em Cursor, verificar se já existe
registro em algum diretório que essa ferramenta lê por compatibilidade (ver
`## CAMINHOS DE SKILLS POR FERRAMENTA`). Se existir,
classificar como **coberta por compatibilidade** em vez de **ausente** — o
relatório informa ao usuário que a skill já é detectável e oferece, sem cobrar,
promoção para registro nativo.

Para **OpenCode**, exigir vínculo em `~/.config/opencode/skills/` ou
`~/.agents/skills/`. Não classificar como **coberta por compatibilidade** apenas
porque existe vínculo em `~/.claude/skills/`, pois a compatibilidade com Claude Code
pode estar desativada por configuração do ambiente.

Para **Codex**, não usar essa etiqueta entre `.codex/skills/` e `.agents/skills/`:
ambos são âmbitos USER que o Codex indexa em paralelo. Se a skill existir em um
deles, declarar **OK** para Codex; só **ausente** quando faltar nos dois (e não
houver outro vínculo válido sob `$CODEX_HOME` alterado via ambiente).

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

O `git` é tratado à parte — é pré-requisito de versionamento, não ferramenta de
agente. Sua presença é verificada (`Get-Command git` ou caminhos padrão de
instalação) e, se ausente, a instalação é oferecida no bootstrap — ver
`## BOOTSTRAP DO REPOSITÓRIO`.

## BOOTSTRAP DO REPOSITÓRIO

O usuário GeneXus tipicamente **baixa o repositório como ZIP** no GitHub,
descompacta no PC e abre uma sessão pedindo o setup. Nesse caso a pasta tem todo
o conteúdo, mas **não é um repositório Git** ligado ao oficial.

**Cenário A — pasta com conteúdo, sem `.git`** (coberto por esta skill): a skill
já existe na pasta, então o setup pode ligá-la ao oficial. O passo 0 do
`## WORKFLOW` executa `scripts/Initialize-XpzSkillsRepoGit.ps1` (`-AsJson` para
agentes), que de forma determinística:

1. Garante o `git`: se ausente, instala via `winget` (`Git.Git`); se o `winget`
   faltar, **bloqueia** orientando download manual (`https://git-scm.com/download/win`);
   se instalar mas o PATH desta sessão não atualizar, devolve
   `GIT_INSTALLED_REOPEN_SHELL` (reabrir a sessão e repetir)
2. `git init` + `remote add origin` (oficial) + `fetch` + `reset --mixed
   origin/main` — liga a história oficial **sem sobrescrever** os arquivos vindos
   do ZIP
3. **Gate anti-destrutivo:** se o working tree divergir do oficial
   (`GIT_LINKED_WITH_DRIFT`), reporta as divergências e **para**; o alinhamento
   destrutivo (`reset --hard`, via `-AlignToOfficial`) só roda após confirmação
   explícita do usuário. ZIP recém-baixado normalmente resulta em
   `GIT_LINKED_CLEAN`

Repositório oficial:
`https://github.com/GxBrasilNOficial/GeneXus-XPZ-Skills.git` (público, para a
comunidade GeneXus). O script aceita `-OfficialRemoteUrl` para outro remoto.

**Cenário B — pasta vazia** (NÃO coberto por esta skill): se a pasta está vazia,
esta skill nem existe nela para ser executada. O `git clone` é **pré-requisito**
— orientar o usuário a clonar antes de pedir o setup:

```
git clone https://github.com/GxBrasilNOficial/GeneXus-XPZ-Skills.git
```

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- A raiz do repositório de skills é a pasta-pai desta skill — é de lá que o
  inventário de skills deve ser feito.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste
  `SKILL.md`, não do diretório de trabalho corrente.

---

## TRIGGERS

Use esta skill para:
- Ligar ao repositório oficial uma pasta recém-baixada como ZIP do GitHub —
  inicializar o Git e, se necessário, instalar o Git (ver
  `## BOOTSTRAP DO REPOSITÓRIO`)
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
| Cursor | MCP global em `~/.cursor/mcp.json` (servidor `xpz-global-instructions`) lendo a **fonte efetiva** de outra ferramenta instalada — ver `## CURSOR — INSTRUCIONAIS GLOBAIS VIA MCP`. Regras em `~/.cursor/rules/` ou `AGENTS.md` no perfil **não** substituem esse mecanismo para instruções globais do Agent |

As ferramentas não precisam duplicar o mesmo texto em cada arquivo global: é válido
**centralizar** as práticas recomendadas em um único arquivo e referenciar esse arquivo
a partir de outro (por exemplo `~/.claude/CLAUDE.md` que remete ou inclui o conteúdo
efetivo de `~/.codex/AGENTS.md`). Ao auditar, verificar **onde o texto efetivo vive**
e se cada ferramenta instalada **carrega** esse caminho na prática — não exigir cópia
literal redundante só porque a tabela acima lista caminhos distintos por produto.
Quando o ambiente já adotar centralização em uma fonte global consolidada, tratar
referência curta para essa fonte como proposta preferencial antes de sugerir duplicação
literal. Neste contexto, "equivalente" significa carregar a mesma fonte efetiva, não
necessariamente repetir o mesmo texto em todos os arquivos.

**Fonte efetiva por ferramenta instalada:** não apontar o Cursor (nem o MCP) para
`~/.codex/AGENTS.md` quando o Codex **não** estiver instalado na máquina; o mesmo
vale para `~/.claude/CLAUDE.md` sem Claude Code e para `~/.config/opencode/AGENTS.md`
sem OpenCode. A resolução segue `## DETECÇÃO DE INSTALAÇÃO` e referências cruzadas
(`@~/.codex/AGENTS.md` em `CLAUDE.md`, `instructions[]` no OpenCode, etc.) antes de
escolher o caminho gravado em `config.json` do MCP.

Em fluxo com agente capaz de editar arquivos, lacunas nestes instrucionais devem
conduzir a **oferta de correção assistida** após confirmação explícita (passo 9 do
`WORKFLOW`). Não tratar copiar-colar manual como **único** caminho salvo quando o
usuário recusar escrita pelo agente ou o ambiente bloquear (ex.: sandbox sem
acesso a `%USERPROFILE%`).

Ao configurar um novo ambiente, verificar se o local global de cada ferramenta
instalada contém ao menos estas regras:

```markdown
## Ferramentas de busca e shell

- Nunca usar `cd "path" && <comando>` — o harness bloqueia esse padrão
  incondicionalmente ("Compound command contains cd with path operation").
  Nenhuma entrada na allowlist contorna esse bloqueio.
- Para listar ou buscar arquivos: usar a capacidade nativa de busca/listagem da
  ferramenta quando disponível; no Claude Code, por exemplo, preferir `Glob` e
  `Grep` com path absoluto. No Codex em Windows, preferir `rg`, `Get-ChildItem`
  e `Select-String` quando for necessário usar shell.
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

## CURSOR — INSTRUCIONAIS GLOBAIS VIA MCP

No Cursor, instruções globais persistentes para o **Agent** não devem depender da UI
de User Rules nem de editar `state.vscdb` / chave legada `aicontext.personalContext`
(mecanismo antigo; não governa o Agent atual de forma confiável).

**Mecanismo recomendado:** servidor MCP stdio `xpz-global-instructions` registrado em
`~/.cursor/mcp.json`, instalado em `~/.cursor/xpz-global-instructions-mcp/` com leitura
dinâmica da fonte efetiva via `config.json` (`agentsPath`). O Cursor expõe o servidor
como `user-xpz-global-instructions` na sessão (pasta `mcps/` do projeto com
`INSTRUCTIONS.md` derivado do campo `instructions` do `initialize`).

**Artefatos canônicos no repositório de skills:**

- `scripts/cursor-global-instructions-mcp/server.py` — servidor MCP
- `scripts/Install-CursorGlobalInstructionsMcp.ps1` — instala/atualiza perfil do usuário,
  faz merge em `mcp.json` preservando outros servidores e grava `agentsPath` resolvido

**Resolução de `agentsPath` (ordem resumida; detalhe no script):**

1. Parâmetro `-AgentsPath` explícito na instalação
2. Referência `@<caminho>.md` em `~/.claude/CLAUDE.md` (quando existir e o arquivo apontado existir)
3. Entradas `instructions[]` em `opencode.json` / `opencode.jsonc` (quando existirem)
4. Se **Codex** instalado → `~/.codex/AGENTS.md` (deve existir; senão bloquear com orientação)
5. Se **Claude Code** instalado → `~/.claude/CLAUDE.md`
6. Se **OpenCode** instalado → `~/.config/opencode/AGENTS.md`
7. Se nenhuma ferramenta com instrucionais globais estiver instalada → não instalar o MCP
   até o usuário criar um arquivo fonte ou passar `-AgentsPath`

**Não fazer:**

- Prometer `~/.cursor/rules/*.mdc` ou `~/.cursor/AGENTS.md` como equivalente global ao
  Codex/Claude/OpenCode para o Agent
- Editar SQLite do Cursor para injetar regras
- Duplicar o corpo inteiro do `AGENTS.md` no repositório de skills — o MCP **lê** a fonte
  já mantida pelo usuário

**Validação pós-instalação (nova sessão do Cursor, após reload/restart):**

- Em `mcps/user-xpz-global-instructions/`, presença de `INSTRUCTIONS.md` coerente com a
  fonte efetiva auditada
- Agente cita o caminho correto da fonte (não um caminho de ferramenta não instalada)
- Comportamento observável de regra presente na fonte (ex.: timestamp no início da resposta,
  se estiver no `AGENTS.md` efetivo)
- Ferramenta `read_global_agents_instructions` e resource do arquivo fonte respondem sem erro

**Atualização:** após `git pull` que altere `server.py`, reexecutar o instalador (ou
copiar o `server.py` canônico) e recarregar MCPs; `config.json` só precisa mudar quando a
fonte efetiva do usuário mudar. O motor de auditoria `scripts/Test-XpzSkillsRegistration.ps1`
detecta o `server.py` defasado comparando o hash instalado com o canônico do repositório
(`cursorMcp.label = MCP_SERVER_STALE`), evitando depender de inspeção manual.

---

## WORKFLOW

0. **Garantir que a raiz é um repositório Git ligado ao `origin` oficial** (ver
   `## BOOTSTRAP DO REPOSITÓRIO`): executar `scripts/Initialize-XpzSkillsRepoGit.ps1`
   (`-AsJson` para agentes) e interpretar o `label`:
   - `GIT_ALREADY_LINKED`, `GIT_LINKED_CLEAN`, `ORIGIN_ADDED` → ligado; seguir
     para o passo 1
   - `GIT_LINKED_WITH_DRIFT` → ligado, mas o conteúdo do ZIP diverge do oficial;
     **relatar as divergências e não sobrescrever** — só alinhar com
     `-AlignToOfficial` após confirmação explícita do usuário
   - `GIT_INSTALLED_REOPEN_SHELL` → Git instalado agora; pedir para reabrir a
     sessão e repetir o passo 0
   - `REMOTE_MISMATCH`, `GIT_MISSING_NO_INSTALLER`, `GIT_INSTALL_FAILED` →
     bloquear e orientar conforme as mensagens do script
   - Quando o usuário pedir explicitamente só o registro de skills, e a raiz já
     for um repositório Git, este passo é um no-op rápido (`GIT_ALREADY_LINKED`)
1. Localizar a raiz do repositório de skills XPZ (pasta-pai deste `SKILL.md`)
2. Executar o **motor de auditoria** `scripts/Test-XpzSkillsRegistration.ps1`
   (`-AsJson` para agentes), que de forma determinística inventaria as subpastas
   com `SKILL.md`, detecta as ferramentas instaladas e classifica cada skill ×
   ferramenta como **OK**, **coberta por compatibilidade**, **ausente**, **órfã**
   ou **quebrada** — aplicando as regras de `## CAMINHOS DE SKILLS POR FERRAMENTA`
   e `### Classificação ao auditar` (Codex indexa `.codex` + `.agents`; OpenCode
   exige nativo; Cursor lê `.claude`/`.codex` por compatibilidade). O motor é
   **somente leitura**: não cria nem remove vínculos. Este `SKILL.md` permanece a
   fonte das regras que o motor implementa.
3. Ler o resultado do motor:
   - `overall` → `REGISTRATION_OK` (registro íntegro) ou `REGISTRATION_GAPS`
     (há ausências, quebradas, órfãs e/ou freshness do MCP do Cursor a tratar)
   - `tools[].skills[]` traz o status por skill; `orphans[]` os vínculos que
     apontam para o repo sem skill correspondente; `cursorMcp.label` o estado do
     MCP global do Cursor (tratado no passo 9)
   - O `summary` (ok / coveredByCompat / missing / broken / orphans / cursorMcp)
     alimenta o relatório
4. Apresentar relatório consolidado por ferramenta, declarando explicitamente
   qual estratégia de registro está em uso (compacta por padrão; expansiva se o
   usuário tiver indicado) — ver `## ESTRATÉGIA DE REGISTRO`
5. Para cada gap identificado, oferecer ação de resolução:
   - **Ausente** → criar symlink (ou junction se symlink falhar por permissão)
     no caminho da estratégia ativa
   - **Coberta por compatibilidade** → apenas informar; oferecer promoção para
     registro nativo se o usuário pedir, sem cobrar (aplica-se a Cursor nesta
     estratégia)
   - **Órfã** → remover vínculo do diretório
   - **Quebrada** → recriar vínculo
6. Aguardar confirmação explícita do usuário
7. Executar as correções aprovadas
8. Confirmar resultado por ferramenta
9. **Auditoria dos instrucionais globais** (obrigatória quando os passos anteriores
   foram executados nesta mesma sessão como auditoria/setup completo — não adiar nem
   delegar a uma "próxima mensagem"):
   - Para cada ferramenta **instalada**, determinar **onde está o texto efetivo**
     (ver tabela em `## AGENTS.MD RECOMENDADO` e o parágrafo sobre centralização);
     ler com a ferramenta de leitura disponível no agente, ou comando seguro
     equivalente; no Codex, por exemplo, usar `Get-Content` ou `rg` com caminho
     explícito. Seguir referências explícitas quando
     o conteúdo estiver centralizado (ex.: `CLAUDE.md` que remete a `AGENTS.md`)
   - Comparar com o bloco recomendado nesta skill (seção `## AGENTS.MD RECOMENDADO`):
     pelo menos os dois tópicos — ferramentas de busca/shell e cherry-pick em
     worktrees — devem estar cobertos **no texto efetivo** ou declarar gap explícito
   - Incluir no relatório uma seção **Instrucionais globais**: por ferramenta,
     caminho auditado, **OK** ou lista do que falta; se o arquivo nominal não
     existir mas houver centralização válida documentada, declarar qual caminho
     foi usado como fonte efetiva
   - Se houver lacunas: apresentar o bloco sugerido desta skill e **ofertar aplicar**
     a correção nos caminhos globais corretos por ferramenta — **sem gravar nada até
     confirmação explícita** do usuário (mesmo espírito dos passos 6–7 para vínculos).
     Priorizar ferramentas onde o usuário tipicamente não tem arquivo próprio
     (**Cursor**, **OpenCode**); tratar **Codex** e **Claude Code** igualmente quando
     o texto efetivo não cumprir os tópicos mínimos.
     Orientação prática por destino:
     - **Cursor:** o motor de auditoria do passo 2 já classifica o estado do MCP em
       `cursorMcp.label`: `MCP_OK`, `MCP_SERVER_STALE` (o `server.py` instalado
       difere do canônico do repo — típico após `git pull`), `MCP_CONFIG_INVALID`
       (sem registro em `mcp.json` ou `agentsPath` inexistente) ou `MCP_NOT_INSTALLED`.
       Verificar também se o `config.json` aponta para a **fonte efetiva** correta
       (respeitando ferramentas instaladas — ver `## CURSOR — INSTRUCIONAIS GLOBAIS
       VIA MCP`) e se o conteúdo dessa fonte cobre os tópicos mínimos. Quando o
       `label` for `MCP_SERVER_STALE`, `MCP_CONFIG_INVALID`, faltar MCP ou a fonte
       estiver errada/ausente: **ofertar** executar
       `scripts/Install-CursorGlobalInstructionsMcp.ps1` do repositório de skills
       (com `-AgentsPath` só quando a resolução automática não for possível), após
       confirmação. Se faltar texto nos tópicos mínimos na fonte efetiva, alinhar o arquivo
       da ferramenta dona (Codex/Claude/OpenCode), não inventar cópia paralela só no Cursor.
       Validar em **nova sessão** após reload do Cursor.
     - **OpenCode:** criar ou atualizar `~/.config/opencode/AGENTS.md`; quando o
       ambiente já centralizar instruções em outro arquivo global (ex.:
       `~/.codex/AGENTS.md`, referenciado por `~/.claude/CLAUDE.md`), oferecer primeiro
       o mesmo padrão de referência curta. Só duplicar o bloco recomendado quando o
       OpenCode não carregar essa referência, quando a validação não for possível e o
       usuário preferir garantia por arquivo autocontido, ou quando o usuário pedir
       explicitamente duplicação literal.
     - **Codex / Claude Code:** alinhar `~/.codex/AGENTS.md` e/ou `~/.claude/CLAUDE.md`
       ao bloco recomendado ou à centralização já descrita nesta skill, sempre com
       confirmação antes de gravar
   - Depois da confirmação: executar só o que foi aprovado, gravar os arquivos
     acordados e **revalidar por nova leitura**; no Codex, por exemplo, reler com
     `Get-Content` ou conferir com `rg`. Se o ambiente bloquear escrita (ex.:
     sandbox), declarar o bloqueio e repetir a oferta quando o usuário reexecutar
     com permissões adequadas — copiar-colar manual permanece **fallback**, não o
     fluxo principal quando o agente pode editar após autorização

Exceção: se o usuário limitar explicitamente o pedido (ex.: "só inventário de
skills, sem AGENTS"), omitir o passo 9 e declarar esse recorte no relatório.
