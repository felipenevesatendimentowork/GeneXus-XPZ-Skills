# 14 — Revisão pré-push reforçada (painel multi-modelo)

## Papel do documento

Tier **reforçado e opcional** da revisão pré-push. O [`13-revisao-pre-push.md`](13-revisao-pre-push.md) define a **rotina** — o que cada revisor executa: passo mecânico + fase semântica. Este documento **aplica ao caso pré-push** a metodologia de **revisão por pares** definida em [`15-revisao-por-pares.md`](15-revisao-por-pares.md): orquestra um painel de revisores diversos por cima da rotina do `13` e aplica a **régua de convergência** — genérica e normativa no `15` — para decidir quando o estado está push-ready.

O **mecanismo** de delegação (como disparar revisores secundários: opencode, Codex, Claude Code, Copilot ou Gemini, prompt, async + watcher quando houver, leitura do resultado) é da skill [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) — **não** é duplicado aqui. Este documento guarda apenas a **política pré-push**; a metodologia genérica e a régua de convergência são normativas no [`15`](15-revisao-por-pares.md).

Acionamento é **sempre humano**, como toda delegação (ver `xpz-llm-delegate`). Este tier é **opcional**: a rotina do `13` basta para o fluxo normal; o painel é escalonamento quando se quer reforço por diversidade de modelo.

Esta política governa a pré-push do **repositório de skills** (a rotina do `13`). É distinta da skill [`xpz-kb-parallel-pre-push`](xpz-kb-parallel-pre-push/SKILL.md), que valida o estado de uma **pasta paralela de KB** antes do push dessa KB (gates mecânicos próprios, não painel multi-modelo). Aplicar este painel reforçado também àquela rotina é possível em frente futura, mas é **consultivo** — fora do escopo deste documento.

## A régua (aplicação pré-push)

A **régua de convergência** — independência, diversidade de modelo, pára-no-1º-gap, *stale* a cada alteração, voltar-ao-dissidente e convergência do painel inteiro sobre o estado final — é **genérica e normativa no [`15-revisao-por-pares.md`](15-revisao-por-pares.md)**. Abaixo, a sua **aplicação ao pré-push**, onde a "versão" do manuscrito é um **commit** e o "pronto" é **push-ready**:

- **Prompt mínimo verbatim:** todos os revisores recebem `execute a rotina pre push, sem push`, sem enriquecimento — para não contaminar a revisão com o que o agente principal já sabe ou fez.
- **Pára no 1º gap → commit:** o primeiro revisor que acusar gap **interrompe a rodada** → **triagem humana** (nem todo apontamento é gap real — pode ser convenção da casa ou falso positivo) → correção → **commit imediato** da correção.
- **Painel _stale_ a cada commit:** todo commit novo **invalida** os vereditos anteriores — eles revisaram outro estado; um "sem gap" só vale para o commit **exato** que foi revisado.
- **O ciclo não pára no meio:** gap → triagem humana → correção+commit → **re-montar o painel sobre o novo HEAD** (sem novo acionamento) → repetir até a convergência. **"Sem push" restringe só o push final — não interrompe o laço.**
- **Push-ready:** *depois da última alteração do repositório*, **o painel inteiro** responde "sem gap" sobre **esse estado final**; passe parcial — inclusive o do dissidente sozinho, ou de revisores que aprovaram um commit anterior — **não** conta. Só então o estado é push-ready, e o push em si continua exigindo autorização explícita do usuário (conforme o `13`).

## Papéis: montagem e opinião (agente) vs decisão (humano)

Os papéis — montagem e opinião pelo agente (sob acionamento humano) vs **decisão** (triagem, convergência e, aqui, **push**) pelo humano — e o guardrail (o agente não decide/age no lugar do humano, nem finge que um único revisor é o painel) são **genéricos e normativos no [`15-revisao-por-pares.md`](15-revisao-por-pares.md)**. No pré-push, a forma concreta:

- **(a) Montagem do painel** — disparar os revisores diversos (modelos via [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) + subagentes), cada um com o prompt mínimo verbatim `execute a rotina pre push, sem push`, e **colher os vereditos**; sob acionamento humano (o pedido "execute a reforçada" é esse acionamento).
- **(b) Decisão é humana** — quem decide se o gap é real, declara a convergência e **autoriza o push** é o humano; o agente **deve opinar e recomendar antes**, mas **não** auto-tria, não declara convergência sozinho nem dá push.
- **(c) Ser um revisor** — rodar a rotina do [`13`](13-revisao-pre-push.md). Qualquer revisor, humano ou agente.

**Composição do painel:** princípio — **famílias distintas da do orquestrador**, cegos independentes, e **modelos fortes**. Vale a política de modelos do [`README.md`](README.md) ("modelos de linguagem"), **por papel**: modelos de forte aderência a instruções são preferidos no núcleo; modelos menos fortes são admissíveis como **vozes adicionais** do painel — nunca revisor **decisivo sozinho** (a objeção de cada voz ainda passa por triagem) —; **veto duro** só para Mistral Large 3 e Nemotron 3 Ultra (baixo aterramento comprovado). O princípio prevalece sobre qualquer lista fixa de modelos. Descobrir os disponíveis pelo inventário de capacidade da [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) (`Build-LlmDelegateCapabilityManifest.ps1`), em vez de re-sondar a cada uso; `opencode models` quando for atualizar a sondagem do opencode. Backends via [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md): **opencode** (externos em formato `provider/modelo`, como `ollama-cloud/deepseek-v4-pro`), **Codex** (`gpt-5.5`, família OpenAI), **Claude Code** (`claude-opus-4-8`, família Anthropic), **GitHub Copilot CLI** (`gpt-5-mini`, destino `github-copilot/*`) e **Gemini CLI** (`gemini-3-flash-preview`, destino `google/*`). Exemplos **recomendados hoje** (sugestão, ajustável; o princípio e a política do `README` prevalecem sobre a lista): `ollama-cloud/deepseek-v4-pro` (opencode/Ollama Cloud), `gpt-5.5` (Codex), quando o orquestrador não for Anthropic, `claude-opus-4-8` (Claude Code), e, como cegos adicionais comprovados, Copilot ou Gemini em modo consultivo, mais um subagente local quando disponível.

**O que um agente DEVE fazer ao receber "Execute a Revisão Pré-Push Reforçada":** **montar o painel** (a) — disparar os revisores **em sequência**, pausando no **1º gap**. Ali, **entregar os vereditos com a sua própria triagem recomendada** — não fatos neutros e silêncio: dizer o que **você acha** que é gap real vs convenção, e por quê — deixando a **decisão** ao humano. Não disparar o lote inteiro de uma vez (perde-se o parar-no-1º-gap). **Concisão:** relatar cada veredito e a triagem recomendada de forma enxuta; não re-resumir o estado completo a cada passo.

**Proibição (o guardrail):** um agente **não** pode (1) **decidir e agir** no lugar do humano — auto-triar e aplicar correção, declarar convergência, dar push — nem (2) **fingir** que um solo (só o passo c) é a reforçada. A **decisão** de triagem/convergência/push é nó humano; sem ele, ou se colapsa a salvaguarda, ou se degenera na rotina do `13`. O erro **não** é montar o painel **nem opinar** (isso o agente deve); o erro é o agente **decidir/agir** no lugar do humano.

## Relação com os outros documentos

- **`15-revisao-por-pares.md`** — a **metodologia genérica** de revisão por pares e a **fonte normativa** da régua de convergência. Este `14` é a **aplicação pré-push** dessa metodologia.
- **`13-revisao-pre-push.md`** — a **rotina** (o *quê* cada revisor executa). Este `14` orquestra um painel de revisores por cima dela.
- **`xpz-llm-delegate/SKILL.md`** — o **mecanismo** de delegação a LLM secundário. O painel deste `14` é um caso de uso dirigido por humano desse mecanismo.
