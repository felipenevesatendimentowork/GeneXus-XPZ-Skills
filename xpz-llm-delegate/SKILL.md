---
name: xpz-llm-delegate
description: Permite ao agente principal delegar tarefas menores ou pedir segunda opinião a um LLM secundário via opencode, Codex (GPT-5.5) ou Claude Code (Opus 4.8), com classificação local/externo determinística e gate de confidencialidade por KB; acionamento sempre humano (a pedido do usuário ou com sua concordância explícita)
---

# xpz-llm-delegate

Permite ao agente principal (forte) **delegar tarefas menores** ou **pedir segunda
opinião** a um LLM secundário, sem ceder a ele o juízo das decisões complexas. A
delegação é uma **ferramenta dirigida pelo humano**: nunca é acionada automaticamente
pelo agente — só a pedido do usuário ou com a concordância explícita dele a uma
sugestão.

Há três motores de delegação (backends): o **opencode** (backend #1, agêntico), o
**Codex** (backend #2, `codex exec` com GPT-5.5 por padrão) e o **Claude Code**
(backend #3, `claude -p` com Opus 4.8 por padrão). A skill é **backend-agnóstica**:
o núcleo (classificação de localidade, política de confidencialidade por KB, validação de
saída) é o mesmo para os três; cada backend só contribui seu **adapter de invocação** e seu
**resolvedor de localidade**. O backend é distinguido pelo script que se chama
(`Invoke-Codex`, `Invoke-OpenCode` ou `Invoke-ClaudeCode`) e pelo parâmetro `-Backend`
do gate — **nunca** pela chave de modelo na política (ver `## ANATOMIA`).

Esta skill é transversal — opera tanto na **raiz de desenvolvimento das skills XPZ**
quanto, com regras mais estreitas, em sessão dentro de uma **pasta paralela de KB**.
Ela não manipula XPZ/XML; o prefixo `xpz-` é marcador de família, como em
`xpz-skills-setup`.

Um caso de uso documentado deste mecanismo é o **painel multi-modelo de revisão
pré-push reforçada** — ver [`14-revisao-pre-push-reforcada.md`](../14-revisao-pre-push-reforcada.md)
na raiz do repositório, que guarda a política (régua de convergência); esta skill
guarda o mecanismo de delegação.

---

## GUIDELINE

- **Acionamento só humano.** Nunca invocar um subagente por conta própria. O agente
  pode **sugerir** delegar; só executa após pedido ou concordância explícita do usuário.
- **O agente forte mantém o juízo.** Nunca delegar decisão estrutural GeneXus
  (classificação de risco de objeto, segurança de import, juízo de família/tipo,
  veredito de gate). Isso fica sempre com o agente principal — ver `## O QUE NÃO DELEGAR`.
- **Validar a saída do subagente.** Toda saída de tarefa delegada é insumo, não verdade.
  O agente forte revisa antes de usar. Modelos fracos não são confiáveis para conteúdo
  GeneXus (ver `README.md`, regra de modelos de linguagem).
- **Confidencialidade por gate determinístico.** Antes de enviar qualquer payload a um
  modelo, classificar o payload (`kb-sensitive` ou `public`) e passar por
  `Resolve-LlmDelegateAuthorization.ps1`. Conteúdo de KB só vai a modelo externo com
  autorização; conteúdo público é livre — ver `## CONFIDENCIALIDADE`.
- **Anunciar o destino.** Mesmo com autorização durável, declarar ao usuário para qual
  modelo (e se local ou externo) o conteúdo está indo a cada uso.
- **Recusa não é o padrão; autorização é.** Para payload sensível a modelo externo sem
  política durável, o gate devolve `ask` — o agente pede autorização explícita e oferece
  **persistir** a escolha no arquivo de política da KB (liberação durável).
- **Não confiar no relógio nem em fatos reportados pelo subagente.** Timestamps,
  contagens e afirmações vindas do modelo secundário podem ser alucinados; validar.

## CONTEXTOS DE USO (uma coisa não atrapalha a outra)

| Contexto | Classe de dado típica | Regra |
|---|---|---|
| Raiz de desenvolvimento das skills XPZ | público (diff do repo, molde sanitizado, README) | externo liberado; é o caso nobre da **diversidade de modelo** (segunda opinião na revisão pré-push) — externo é até desejável, pois diversidade quer um modelo diferente do principal |
| Sessão dentro de pasta paralela de KB | sensível (conteúdo real de KB, `ObjetosDaKbEmXml`, XML) | externo exige autorização (gate); preferir modelo local; o subagente agêntico **não** tem proteção nativa de leitura na pasta paralela — ver `## CONFIDENCIALIDADE` |

A revisão pré-push (`13-revisao-pre-push.md`) **não** se aplica a pastas paralelas. O caso
de diversidade de modelo vive na raiz de desenvolvimento, não na pasta paralela.

## ANATOMIA (cada parte faz o quê, e qual eixo governa)

A skill separa **três eixos independentes**. Confundi-los gera erro (ex.: namespear a
política pelo backend abre brecha de confidencialidade). Os eixos:

| Eixo | Pergunta | Onde mora |
|---|---|---|
| **Tarefa** | é delegável (mecânica/2ª opinião) ou é juízo GeneXus? | `## O QUE NÃO DELEGAR` |
| **Adapter** (como o dado é enviado) | qual motor leva o prompt? | o **script** que se chama (`Invoke-Codex`, `Invoke-OpenCode`, `Invoke-ClaudeCode`) |
| **Destino** (para onde o dado vai) | o tráfego sai da máquina? para qual provider? | resolvedor de localidade + política |

**Invariante de destino (a regra que evita o erro):** a chave de modelo no gate e na
política é o **`provider/modelo` de DESTINO** — para onde o tráfego vai. Adapters diferentes
que enviam para o **mesmo** provider normalizam para a **mesma** chave; o backend/adapter
**nunca** entra na chave. Por isso o Codex com GPT-5.5 (que vai para a OpenAI) casa a chave
`openai/gpt-5.5` e é governado pelas **mesmas** regras `openai/*` que o opencode — não por uma
chave `codex/*`. Namespear por adapter faria uma regra `openai/*: deny-external` deixar o
Codex passar: brecha silenciosa no eixo que o gate existe para proteger. Pelo mesmo motivo,
Claude Code com Opus 4.8 casa `anthropic/claude-opus-4-8`, nunca `claude-code/*`.

Mapa de responsabilidade por componente (em `scripts/`, na raiz):

| Componente | Governa | Não faz |
|---|---|---|
| `Invoke-*` / `Start-*Job` (adapter) | **como** o prompt é enviado (mecânica do motor) | não decide destino nem confidencialidade |
| `Resolve-OpenCodeModelLocality` / `Resolve-CodexModelLocality` / `Resolve-ClaudeCodeModelLocality` | traduz a invocação → **`provider/modelo` de destino** (`canonicalModel`) + local/external | não lê o payload |
| `Resolve-LlmDelegateAuthorization` (gate) | veredito allow/ask/deny por destino + sensibilidade + política | não envia nada; seleciona o resolvedor por `-Backend` |
| `opencode-delegation-policy.json` (política por-KB) | autorização durável por **chave de destino** | não conhece o adapter |

## CONFIDENCIALIDADE

A classificação **local vs externo é determinística**, lida da config do backend pelo
`baseURL`/`base_url` do provider de destino (loopback ⇒ local; caso contrário ⇒ externo).
No opencode vem da config JSON; no Codex, da `config.toml` (`model_providers`/`profiles`) ou
das flags `--oss`/`--local-provider` — GPT-5.5 sem `--oss` ⇒ provider `openai` ⇒ externo.
No Claude Code, modelos Claude explícitos são tratados como destino Anthropic externo;
`opus` é normalizado conservadoramente para `anthropic/claude-opus-4-8`, e aliases não
mapeados ficam `unknown`.
Já a pergunta *"este payload é sensível?"* **não** é determinística — ancora no
**contexto/origem**, não em varrer o texto. Não há selo técnico: o que segura é gatilho
humano + gate + contrato.

Dois eixos independentes:

1. **Tipo de tarefa** (governa confiabilidade): mecânica/segunda-opinião pode ir a modelo
   secundário; juízo GeneXus, não.
2. **Sensibilidade do payload** (governa confidencialidade): conteúdo de KB → só modelo
   local, salvo autorização; texto público → externo livre.

Scripts do gate (em `scripts/`, na raiz do repositório):

- `Resolve-OpenCodeModelLocality.ps1 -Model <provider/modelo>` → JSON `{ locality: local|external|unknown, baseUrl, reason }`. Backend opencode.
- `Resolve-CodexModelLocality.ps1 -Model <m> [-Oss] [-LocalProvider <ollama|lmstudio>] [-Profile <id>]` → JSON `{ locality, baseUrl, canonicalModel, reason }`. Backend codex; `canonicalModel` é a chave de destino (ex.: `openai/gpt-5.5`).
- `Resolve-ClaudeCodeModelLocality.ps1 -Model <m>` → JSON `{ locality, canonicalModel, reason }`. Backend Claude Code; `opus` e `claude-opus-4-8` casam `anthropic/claude-opus-4-8`.
- `Resolve-LlmDelegateAuthorization.ps1 -Model <m> -PayloadSensitivity <kb-sensitive|public> [-Backend <opencode|codex|claude-code>] [-Oss] [-LocalProvider <p>] [-Profile <id>] [-PolicyPath <json>]` → JSON `{ verdict: allow|ask|deny, targetModelKey, ... }`. Núcleo backend-agnóstico; seleciona o resolvedor por `-Backend` e casa a política pela chave de destino.

Lógica do gate:

```
payload = public                  -> allow  (qualquer modelo)
payload = kb-sensitive:
    localidade local              -> allow  (dado não sai da máquina)
    localidade external/unknown   -> política por-KB:
        allow-external            -> allow  (anunciar destino)
        deny-external             -> deny
        ask / não definido        -> ask    (autorização explícita do usuário)
```

## ARQUIVO DE POLÍTICA POR KB

Caminho: `opencode-delegation-policy.json` na raiz da pasta paralela da KB (criado/ofertado
pelo `xpz-kb-parallel-setup`, ou ao persistir uma autorização). Granularidade fina por
`provider/modelo`, com curinga de provider e default. Ausente ⇒ comportamento `ask`.

```json
{
  "schemaVersion": 1,
  "defaultExternal": "ask",
  "models": {
    "openai/gpt-5.4": "allow-external",
    "ollama-cloud/*": "deny-external"
  }
}
```

Resolução do modelo na política: chave exata → curinga `provider/*` → curinga `*` →
`defaultExternal` → `ask` (quando não há arquivo). Valores válidos por entrada:
`allow-external`, `deny-external`, `ask`.

A chave é sempre o **provider de destino** (ver `## ANATOMIA`), não o backend. O Codex com
GPT-5.5 casa `openai/gpt-5.5` / `openai/*` — as **mesmas** entradas que governam o opencode
quando manda para a OpenAI. Não existe (nem deve existir) prefixo `codex/` na política.
O Claude Code com Opus 4.8 casa `anthropic/claude-opus-4-8` / `anthropic/*`; não existe
prefixo `claude-code/` na política.

## O QUE NÃO DELEGAR

Fica sempre com o agente forte (nunca no subagente):

- Classificação de risco/família/tipo de objeto GeneXus
- Decisão de segurança de import/build e veredito de qualquer gate
- Interpretação de Source/Rules/Events para decisão de empacotamento
- Qualquer decisão que vire ação de escrita na KB ou no repositório

## TAREFAS DELEGÁVEIS (sugestões iniciais, não exaustivas)

- Resumir um log longo / saída verbosa
- Reformatar ou normalizar texto
- Rascunhar mensagem de commit a partir de um diff
- Tradução das seções `Español`/`English` do `README.md` (trabalho recorrente)
- **Segunda opinião de modelo distinto** na revisão semântica pré-push (diversidade de
  modelo do `13`) — payload público (diff/`.md` do repo)
- Transformações mecânicas de texto que o agente forte valida depois

---

## TRIGGERS

Use esta skill para:
- Delegar uma tarefa menor a um LLM secundário, a pedido do usuário ou com a concordância
  dele a uma sugestão
- Pedir segunda opinião de um modelo distinto (ex.: diversidade de modelo na revisão pré-push)
- Disparar uma tarefa longa sem bloquear (job assíncrono com janela de acompanhamento)
- Delegar a um sub-agente Codex (`codex exec`, GPT-5.5) — síncrono ou assíncrono
- Delegar a um sub-agente Claude Code (`claude -p`, Opus 4.8) — síncrono ou assíncrono
- Classificar se um modelo do opencode, Codex ou Claude Code é local ou externo
- Decidir, via gate, se um payload pode ser enviado a um modelo (allow/ask/deny), em qualquer backend

Do NOT use esta skill para:
- Delegar juízo estrutural GeneXus (ver `## O QUE NÃO DELEGAR`)
- Enviar conteúdo de pasta paralela de KB a modelo externo sem passar pelo gate
- Acionar um subagente automaticamente sem pedido/concordância do usuário
- Registrar a própria skill nas ferramentas (use `xpz-skills-setup`)
- Preparar a pasta paralela de uma KB (use `xpz-kb-parallel-setup`)

---

## SCRIPTS (em `scripts/`, na raiz do repositório)

Backend opencode:
- `Invoke-OpenCode.ps1 <prompt> [-Model <p/m>] [-Agent <n>] [-Raw] [-AllText] [-TimeoutSec <s>]` — síncrono (prompt → texto). Bloqueia até a resposta. `-AllText` devolve toda a narração (preâmbulos + resposta) em vez de só a resposta final. Usa o `opencode.exe` real e runner temporário para preservar prompt multilinha como argumento único.
- `Start-OpenCodeJob.ps1 <prompt> [-Model <p/m>] [-Agent <n>] [-NoWatcher] [-TempDir <path>] [-KeepDays <n>]` — assíncrono; retorna `{jobId, pid, stream, result, watcher}`; abre janela de acompanhamento por padrão. Também usa runner temporário para evitar fragmentação de prompt pelo `Start-Process`.
- `Watch-OpenCodeJob.ps1 -JobId <guid> -ProcessId <pid> [-TempDir <path>] [-IntervalSeconds <1-30>] [-SilenceThresholdSeconds <30-3600>]` — monitor incremental; grava `<GUID>.result.json` ao fim (campos `status`, `finalText`, `error`, `tokens`, `totalCost`).

Backend codex (`codex exec`, GPT-5.5 por padrão, sandbox `read-only` fixo):
- `Invoke-Codex.ps1 <prompt> [-Model <m>] [-Oss] [-LocalProvider <ollama|lmstudio>] [-Profile <id>] [-Cd <dir>] [-CodexExe <path>] [-TimeoutSec <s>]` — síncrono (prompt → texto). Prompt via stdin; resposta final pelo `output-last-message`.
- `Start-CodexJob.ps1 <prompt> [-Model <m>] [-Oss] [-LocalProvider <p>] [-Profile <id>] [-Cd <dir>] [-CodexExe <path>] [-NoWatcher] [-TempDir <path>] [-KeepDays <n>]` — assíncrono; retorna `{jobId, pid, stream, lastmsg, result, watcher}`; abre janela de acompanhamento por padrão.
- `Watch-CodexJob.ps1 -JobId <guid> -ProcessId <pid> [-TempDir <path>] [-IntervalSeconds <1-30>] [-SilenceThresholdSeconds <30-3600>]` — monitor incremental do stream `--json`; grava `<GUID>.result.json` ao fim (`status`, `finalText`, `error`, `inputTokens`, `outputTokens`).
- `CodexCliSupport.ps1` (dot-source) — descoberta **fail-closed** do `codex.exe` compatível (app desktop sob `%LOCALAPPDATA%\OpenAI\Codex\bin`, maior versão; ignora o shim npm do PATH, rejeitado para GPT-5.5).

Backend Claude Code (`claude -p`, Opus 4.8 por padrão, externo Anthropic):
- `Invoke-ClaudeCode.ps1 <prompt> [-Model <m>] [-PermissionMode <mode>] [-Tools <list>] [-MaxTurns <n>] [-Cd <dir>] [-ClaudeExe <path>] [-TimeoutSec <s>]` — síncrono (prompt → texto). Prompt via stdin; por padrão usa consulta curta restrita (`PermissionMode=plan`, `Tools=Read,Glob,Grep`, sem persistência de sessão). `-MaxTurns` é aplicado somente quando a versão local do Claude Code expõe `--max-turns`.
- `Start-ClaudeCodeJob.ps1 <prompt> [-Model <m>] [-PermissionMode <mode>] [-Tools <list>] [-MaxTurns <n>] [-Cd <dir>] [-ClaudeExe <path>] [-NoWatcher] [-TempDir <path>] [-KeepDays <n>]` — assíncrono; retorna `{jobId, pid, stream, result, watcher}`; abre janela de acompanhamento por padrão. `-MaxTurns` é aplicado somente quando a CLI suportar a flag.
- `Watch-ClaudeCodeJob.ps1 -JobId <guid> -ProcessId <pid> [-TempDir <path>] [-IntervalSeconds <1-30>] [-SilenceThresholdSeconds <30-3600>]` — monitor incremental do stream `--output-format stream-json`; grava `<GUID>.result.json` ao fim (`status`, `finalText`, `error`).
- `ClaudeCodeCliSupport.ps1` (dot-source) — descoberta **fail-closed** do `claude.exe`, validação de versão/flags mínimas e extração de erros.

Latência por provedor: modelos externos OAuth (`openai/*`, GPT-5.5 do Codex; `anthropic/*`,
Opus 4.8 do Claude Code) podem passar de 180s — ajustar `-TimeoutSec`; `ollama-cloud/*` e
`opencode-go/*` costumam responder mais rápido.

Núcleo backend-agnóstico:
- `Resolve-OpenCodeModelLocality.ps1`, `Resolve-CodexModelLocality.ps1`, `Resolve-ClaudeCodeModelLocality.ps1` e `Resolve-LlmDelegateAuthorization.ps1` (ver `## ANATOMIA` e `## CONFIDENCIALIDADE`).

`PATH RESOLUTION`: este `SKILL.md` fica numa subpasta sob a raiz; os scripts ficam em
`../scripts/` relativos a esta pasta. Resolver caminhos a partir da raiz do repositório.

## WORKFLOW (uma delegação)

1. Confirmar o **gatilho humano**: o usuário pediu, ou aprovou explicitamente uma sugestão
   de delegar. Sem isso, não delegar.
2. Classificar a tarefa: é delegável (mecânica/segunda-opinião) ou é juízo GeneXus? Se for
   juízo, **não delegar** (ver `## O QUE NÃO DELEGAR`).
3. Classificar o payload: `public` (texto do repo público, molde sanitizado) ou
   `kb-sensitive` (conteúdo de pasta paralela). Na dúvida, tratar como `kb-sensitive`.
4. Escolher o backend e o modelo. Rodar `Resolve-LlmDelegateAuthorization.ps1` com modelo +
   sensibilidade + `-Backend opencode|codex|claude-code` (+ `-PolicyPath` quando em pasta paralela).
   - `allow` → seguir; **anunciar o destino** ao usuário (use `targetModelKey` do resultado).
   - `deny` → não enviar; informar o motivo e oferecer alternativa local.
   - `ask` → pedir autorização explícita ao usuário; se autorizado, oferecer **persistir** a
     escolha no `opencode-delegation-policy.json` (liberação durável).
5. Invocar o adapter do backend escolhido: opencode (`Invoke-OpenCode.ps1` / `Start-OpenCodeJob.ps1`),
   codex (`Invoke-Codex.ps1` / `Start-CodexJob.ps1`) ou Claude Code
   (`Invoke-ClaudeCode.ps1` / `Start-ClaudeCodeJob.ps1`) — síncrono (curto) ou assíncrono (longo).
6. **Validar a saída** com o agente forte antes de usá-la. Não confiar em timestamps/fatos
   reportados pelo subagente.

## LIMITE CONHECIDO — OPENCODE COM MODELO LOCAL PEQUENO

O backend opencode é **agêntico**: cada chamada carrega system prompt + schemas de todas as
ferramentas + o que estiver em `instructions` da config do opencode (ex.: um `AGENTS.md` global
extenso). Esse prompt por chamada pode passar de ~16k tokens.

Consequência em GPU de pouca VRAM (medido empiricamente em RX 580 8 GB, Vulkan, com placement
100% GPU e sem spill para RAM/compartilhada):

- modelo local pequeno com janela pequena (8k/16k) → o prompt enche a janela e a resposta sai
  truncada (`reason=length`, ~1 token de saída);
- janela grande (32k) → o prompt cabe, mas o processamento na GPU fica lento demais e estoura o
  timeout.

Ou seja: para modelo **local pequeno**, o gargalo não é VRAM nem janela — é o **tamanho do prompt
do opencode**. Conclusão operacional: usar o backend opencode com modelos **cloud** (janela grande,
validado) e reservar **modelo local pequeno** para o backend **one-shot** futuro (`llm`/`mods`),
que envia só o prompt — sem schemas de ferramentas nem `instructions` — então o modelo local
responde rápido e cabe folgado na VRAM.

## LIMITE CONHECIDO — CODEX É AGÊNTICO (HERDA O AGENTS.md, PODE EXECUTAR)

O `codex exec` também é **agêntico**: carrega o `AGENTS.md`/config do Codex como instruções e,
mesmo com sandbox `read-only` (fixo nos adapters), **pode ler o filesystem do workspace e
executar comandos read-only** para cumprir as instruções herdadas (medido: ~50k tokens de input
e execução espontânea de `Get-Date` por causa de uma regra do `AGENTS.md` global). Consequências:

- **Não** é um backend one-shot: o prompt por chamada é grande e o agente pode agir no workspace.
  Para segunda opinião limpa, confinar com `-Cd <dir>` e preferir um workspace sem dados sensíveis.
- O `read-only` **não** contorna o gate: o Codex envia para a OpenAI (externo). Em pasta paralela
  de KB, payload sensível continua exigindo autorização — o adapter agêntico não tem proteção
  nativa de leitura ali (mesmo alerta do opencode em `## CONTEXTOS DE USO`).
- Reserva-se ainda o backend **one-shot** futuro (`llm`/`mods`) para o caso que precisa enviar
  só o prompt, sem agente nem varredura de filesystem.

## LIMITE CONHECIDO — CLAUDE CODE É AGÊNTICO E EXTERNO

O `claude -p` também é **agêntico**: pode carregar instruções/configurações do Claude Code,
ler o workspace e executar ferramentas conforme permissões. Além disso, Opus 4.8 envia o
payload para Anthropic (`anthropic/claude-opus-4-8`) e, portanto, é externo. Consequências:

- O gate de confidencialidade continua obrigatório: payload `kb-sensitive` para Claude Code
  externo sem política durável devolve `ask`; `allow` exige anunciar `targetModelKey`.
- Para **consulta curta restrita**, usar os defaults do adapter: `-PermissionMode plan`,
  `-Tools Read,Glob,Grep`, persistência de sessão desabilitada e `-Cd` apontando ao menor
  diretório necessário. `-MaxTurns` só entra quando a CLI local suportar `--max-turns`.
- Para **revisor pré-push**, a rotina pode precisar de `git` e scripts locais; não reaproveitar
  cegamente o perfil restrito de consulta curta. Definir explicitamente ferramentas/permissões
  suficientes para leitura e comandos de validação, sem usar `bypassPermissions`.
- Os adapters `Invoke-ClaudeCode.ps1` e `Start-ClaudeCodeJob.ps1` bloqueiam
  `PermissionMode=bypassPermissions`; esse modo não faz parte da delegação XPZ.

## BACKENDS

Ativos: **opencode** (#1), **Codex** (#2) e **Claude Code** (#3). O Codex exerceu o ponto de
extensão do núcleo: o gate ganhou `-Backend` e passou a casar a política pelo `canonicalModel`
do resolvedor (chave de destino), sem renomear `LlmDelegate` nem tocar o resolvedor do
opencode. O Claude Code reaproveita o mesmo eixo: adapter próprio, resolvedor próprio e chave
de destino `anthropic/*`.

Futuros (ex.: CLIs one-shot tipo `llm`/`mods`, mais seguras para segunda opinião pois não varrem
o filesystem) entram do mesmo jeito: um adapter de invocação + um resolvedor de localidade
próprio, plugados no mesmo gate por `-Backend`.

---

## RELAÇÃO COM OUTRAS SKILLS

- `xpz-kb-parallel-setup`: oferta, no setup da pasta paralela, definir a política de
  delegação (`opencode-delegation-policy.json`), com opção de **adiar** — adiar mantém o
  comportamento `ask`, nunca abre brecha.
- `xpz-skills-setup`: registra esta skill nas ferramentas de agente instaladas.
