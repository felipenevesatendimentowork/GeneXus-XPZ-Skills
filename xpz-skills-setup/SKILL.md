---
name: xpz-skills-setup
description: Audita e mantém o registro global das skills XPZ nas ferramentas de agente instaladas na máquina (Codex, Claude Code, OpenCode), com verificação pós-git-pull e oferta de resolução de gaps
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
  estão presentes
- Classificar cada skill por ferramenta: **OK**, **ausente**, **órfã** (registrada
  mas não existe mais no repo) ou **quebrada** (symlink/junction inválido)
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

Os caminhos abaixo são os esperados por ferramenta no Windows. Verificar a existência
de cada caminho antes de usar — não assumir que estão criados:

| Ferramenta | Caminho esperado |
|---|---|
| Codex | `~/.codex/skills/` |
| Claude Code | `~/.claude/skills/` |
| OpenCode | `%APPDATA%/.opencode/skills/` |

## PATH RESOLUTION

- Este `SKILL.md` fica dentro de uma subpasta de skill sob a raiz do repositório.
- A raiz do repositório de skills é a pasta-pai desta skill — é de lá que o
  inventário de skills deve ser feito.
- Toda referência `../arquivo.md` deve ser resolvida a partir da pasta deste
  `SKILL.md`, não do diretório de trabalho corrente.

---

## TRIGGERS

Use esta skill para:
- Verificar se todas as skills XPZ estão registradas globalmente após `git pull`
- Configurar o ambiente de um novo usuário que clonou o repositório de skills XPZ
- Detectar skills ausentes, órfãs ou com vínculo quebrado nas ferramentas instaladas
- Registrar uma nova skill adicionada ao repositório
- Remover o registro de uma skill removida do repositório
- Verificar se o AGENTS.md global do usuário tem as práticas recomendadas para uso das skills XPZ

Do NOT use this skill para:
- Instalar Codex, Claude Code ou OpenCode na máquina
- Registrar skills de outros repositórios (ex: `nexa`, skills GeneXus oficiais)
- Preparar ou auditar a pasta paralela de uma KB GeneXus (use `xpz-kb-parallel-setup`)
- Sincronizar XPZ de uma KB (use `xpz-sync`)

---

## AGENTS.MD RECOMENDADO

As práticas abaixo afetam diretamente o comportamento das skills XPZ em qualquer
ferramenta de agente. Ao configurar um novo ambiente, verificar se o AGENTS.md
global do usuário (ex: `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`) contém ao
menos estas regras:

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
```

---

## WORKFLOW

1. Localizar a raiz do repositório de skills XPZ (pasta-pai deste `SKILL.md`)
2. Inventariar todas as subpastas com `SKILL.md` — esse é o conjunto gerenciável
3. Para cada ferramenta (Codex, Claude Code, OpenCode):
   - Verificar se a ferramenta está instalada na máquina
   - Verificar se o diretório global de skills existe
   - Listar os vínculos presentes no diretório global
   - Classificar cada skill do inventário: **OK**, **ausente**, **órfã** ou **quebrada**
4. Apresentar relatório consolidado por ferramenta
5. Para cada gap identificado, oferecer ação de resolução:
   - **Ausente** → criar symlink (ou junction se symlink falhar por permissão)
   - **Órfã** → remover vínculo do diretório global
   - **Quebrada** → recriar vínculo
6. Aguardar confirmação explícita do usuário
7. Executar as correções aprovadas
8. Confirmar resultado por ferramenta
9. Verificar se o AGENTS.md global do usuário contém as práticas recomendadas
   (seção `## AGENTS.MD RECOMENDADO`); se não contiver, apresentar o bloco
   sugerido e oferecer orientação — nunca editar o AGENTS.md do usuário
   automaticamente
