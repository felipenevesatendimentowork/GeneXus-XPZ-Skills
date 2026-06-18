# 15 — Revisão por Pares (validação de plano/design por painel multi-modelo)

## Papel do documento

Metodologia **genérica** de revisão por pares: um autor submete a sua leitura de um problema e a solução proposta a um **painel de revisores independentes de modelos distintos**, que pensam por si, **leem as fontes por conta própria** e devolvem parecer; o autor revisa e ressubmete até o painel convergir. É a **fonte normativa** da régua de convergência usada no repositório.

Três documentos, três camadas:

- [`13-revisao-pre-push.md`](13-revisao-pre-push.md) — a **rotina** que cada revisor executa antes de um push.
- [`14-revisao-pre-push-reforcada.md`](14-revisao-pre-push-reforcada.md) — a **aplicação** da revisão por pares ao caso **pré-push** (painel sobre a rotina do `13`); herda a régua **deste** documento.
- **este `15`** — a **metodologia geral**, aplicável à **validação de plano/design** antes ou durante a implementação, não só a pré-push.

O **mecanismo** de delegação (como disparar revisores secundários — opencode, Codex, Claude Code, Copilot, Gemini —, prompt, job assíncrono + watcher, leitura do resultado) é da skill [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) — **não** é duplicado aqui. Este documento guarda a **metodologia**; a skill guarda o mecanismo.

Acionamento é **sempre humano** (como toda delegação — ver `xpz-llm-delegate`). O painel **não** se monta nem dispara por iniciativa do agente; o agente **sugere** e só executa a pedido ou com a concordância explícita do usuário.

## O que é

O autor (em geral o agente principal) produz um **manuscrito** — um documento curto com:

1. a **leitura do problema**;
2. a **solução proposta**;
3. as **fontes** que sustentam ou contradizem a proposta;
4. as **decisões em aberto**.

O manuscrito é submetido a um **painel de pares**. Cada par:

- **pensa por si** e devolve a sua versão (concorda / revisa / rejeita) com justificativa e recomendações priorizadas;
- **consulta as fontes por conta própria** (o repositório, e quando autorizado a pasta paralela/experimento, sob `-Cd`/cwd) para confirmar, refinar ou **refutar** o que o autor afirma — o manuscrito é insumo de avaliação, não verdade;
- o autor **reavalia a cada resposta e carrega a versão melhorada adiante** (*revise-and-resubmit*): v1 → v2 → … até o estado final.

## A régua (genérica)

- **Independência:** todos os revisores recebem o **mesmo manuscrito** e um **prompt mínimo**, sem enriquecimento que contamine a revisão com o que o autor já sabe ou fez — em particular, **sem personas/lentes atribuídas** por revisor (cada um recebe o mesmo prompt; personas seguem como futuro, ver `## Futuros`).
- **Diversidade de modelo:** preferir revisores de **famílias diferentes** (cegos diferentes da do autor). Inclui subagentes locais e LLMs secundários via [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md). **Piso:** a revisão por pares exige **≥2 famílias distintas** entre os revisores despacháveis; abaixo do piso **não há painel** — ver `## Composição do painel`. O piso vale para a **composição inteira**, qualquer que seja a forma de montar o painel (subagentes nativos **+** LLMs delegados), não só a rota `xpz-llm-delegate`.
- **Pára no 1º gap:** o primeiro revisor que acusar gap **interrompe a rodada** → **triagem humana** (nem todo apontamento é gap real — pode ser convenção da casa ou falso positivo) → correção → **nova versão do manuscrito**.
- **Painel _stale_ a cada versão:** toda versão nova **invalida** os vereditos anteriores — eles revisaram outra versão. Um "sem gap" só vale para a versão **exata** que foi revisada.
- **Voltar ao dissidente:** após corrigir, **re-passar pelo revisor que objetou**, para confirmar que a correção fecha a objeção **nos termos dele** — não declarar vitória só porque os mais lenientes passaram.
- **O ciclo não pára no meio:** acionada uma vez, a revisão é um **laço** — gap → triagem humana → nova versão → re-montar o painel sobre a versão nova → repetir até a convergência.
- **Convergência é o pronto:** encerra quando o painel diverso **inteiro** converge em **zero gaps sobre a versão final**. Passe parcial — inclusive o do dissidente sozinho, ou de revisores que aprovaram uma versão anterior — **não** conta. Convergência pressupõe **painel válido** (≥2 famílias distintas): um "painel" de uma família converge trivialmente e **não** é revisão por pares.
- **Execução liberável após nó humano:** a convergência torna o plano **liberável para execução** — mas a decisão de executar é **humana** (ver papéis), não automática do agente. No caso pré-push do `14`, o equivalente é "push-ready", e o push continua exigindo autorização explícita.

## Papéis: montagem e opinião (agente) vs decisão (humano)

- **(a) Montagem do painel** — disparar os revisores diversos (via [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) + subagentes), cada um com o manuscrito + o prompt mínimo, e **colher os vereditos**. O agente **pode** fazê-lo, como mãos do humano, **sob acionamento humano**. Antes de rotular o resultado como revisão por pares, **valida o piso de diversidade sobre a lista completa** de revisores (ver `## Composição do painel`); subagentes nativos contam como a família do orquestrador.
- **(b) Nós de decisão — a OPINIÃO do agente é esperada; a DECISÃO é humana.** Quem **decide** se um gap é real (vs convenção/falso positivo), **declara** a convergência e **autoriza** a execução é o humano. O agente, como orquestrador, **deve dar sua opinião e recomendação** sobre cada ponto — tem o contexto e o humano espera esse insumo **antes** de decidir. O que o agente **não** faz é **decidir e agir sozinho**: auto-triar e já aplicar a correção, declarar convergência por conta própria, ou executar.
- **(c) Ser um revisor** — rodar a avaliação do manuscrito contra as fontes. Qualquer revisor, humano ou agente.

**Proibição (o guardrail):** um agente **não** pode (1) **decidir e agir** no lugar do humano — auto-triar e aplicar correção, declarar convergência, executar —, nem (2) **fingir** que uma única opinião (um só revisor) é a revisão por pares. A decisão de triagem/convergência/execução é nó humano.

## Composição do painel

Princípio: **famílias distintas da do autor** e cegos independentes. Vale a política de modelos do [`README.md`](README.md) ("modelos de linguagem"), **por papel**: modelos de forte aderência a instruções são preferidos no núcleo; modelos menos fortes são admissíveis como **vozes adicionais** — nunca revisor **decisivo sozinho** (a objeção de cada voz ainda passa por **triagem humana**) —, pois, lendo as fontes, pegam pontos cegos; **veto duro** só para Mistral Large 3 e Nemotron 3 Ultra (baixo aterramento comprovado). Descobrir os modelos e backends disponíveis na máquina conforme a skill [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md), em vez de re-sondar a cada uso. Se houver uma **lista de revisores preferidos** (`preferred-reviewers.json`, ver `xpz-llm-delegate`), a oferta a usa para compor o painel; no 1º uso sem lista, oferece **calibrá-la** (nunca grava sozinha). A preferência é sugestão **subordinada** a esta política de papel e ao gate — nunca o substitui. O princípio e a política do `README` prevalecem sobre qualquer lista fixa de modelos.

**Piso de diversidade (mecânico).** Uma revisão por pares exige **≥2 famílias distintas** (família = provider de destino) entre os revisores **despacháveis** (`allow`); `ask` ainda não conta como painel montado — conta como **autorizável**. O agente roda `Resolve-LlmDelegatePanelDiversity.ps1` (consultivo, ver [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md)) sobre os candidatos + vereditos do gate, que devolve: **`panelReady`** (≥2 famílias em `allow`); **`needsBatchAuthorization`** (autorizar os `ask` listados fecha o piso → apresentá-los **juntos** ao humano, anunciando destinos + sensibilidade); ou **`insufficientDiversity`** (nem autorizando alcança ≥2 → **não** chamar de revisão por pares: rotular honestamente como **"segunda opinião (N)"**). Caso extremo de **0 pré-autorizados** (tudo `ask`): não é nem segunda opinião — é pedir autorização para **tentar montar** o painel. O agente **nunca** descarta `ask` em silêncio nem apresenta um painel de uma família como revisão por pares (guardrail acima). O motor é **consultivo**: não decide autorização — o gate (`Resolve-LlmDelegateAuthorization.ps1`) é soberano por destino.

**Vale para qualquer montagem do painel.** Antes de chamar de revisão por pares, o agente **materializa a lista completa de revisores** e **atribui família a todos** — inclusive **subagentes nativos**, que herdam a **família do orquestrador** (ex.: `anthropic/claude-opus-4-8` quando o orquestrador é Claude) — e valida o piso sobre a **lista inteira**, injetando os nativos como candidatos no `Resolve-LlmDelegatePanelDiversity.ps1`. Um painel só de subagentes nativos do mesmo orquestrador = **1 família** = "segunda opinião", **não** revisão por pares. O bug a evitar: montar painel "por fora" (só nativos, com personas) e nunca checar o piso.

## Confidencialidade

Antes de enviar, o **autor classifica o manuscrito** como `public` (texto do repositório de skills, molde sanitizado, diff público) ou `kb-sensitive` (conteúdo de pasta paralela de KB real). Para **cada** revisor, roda `Resolve-LlmDelegateAuthorization.ps1` (ver [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md)) — conteúdo sensível só vai a modelo externo com autorização; o gate reavalia destino e sensibilidade deterministicamente e **não** depende de inventário de capacidade. Revisores agênticos rodam com `-Cd` no **menor diretório** necessário. Validação de plano/design **na raiz de desenvolvimento das skills** é tipicamente `public` — é o caso nobre da diversidade de modelo.

## Livro-razão (opcional)

Para rastrear o ciclo de forma auditável, registrar o manuscrito (v1…vN), os prompts enviados, os vereditos por revisor/versão e o resumo da convergência em `Temp\revisao-por-pares\<timestamp-ou-guid>\`. É **opcional** — usado no reforçado/alto risco, dispensado no uso leve. Efêmero e **gitignored** (em pasta paralela, o `Temp/` já é ignorado pelo setup).

## Prompt mínimo

Distinto do verbatim do pré-push (o `14` usa `execute a rotina pre push, sem push`). Para validação de plano/design, o prompt mínimo instrui o revisor a **ler o manuscrito e as fontes citadas, não tratar o manuscrito como verdade, confirmar ou refutar cada afirmação contra as fontes, e reportar gaps e recomendações priorizadas** — sem enriquecimento que entregue a conclusão do autor.

## Relação com os outros documentos

| Documento | Papel |
|---|---|
| `13-revisao-pre-push.md` | A **rotina** que cada revisor executa antes de um push. |
| `14-revisao-pre-push-reforcada.md` | A **aplicação pré-push** da revisão por pares; painel sobre a rotina do `13`; herda a régua **deste** `15`. |
| `15` (este documento) | A **metodologia geral** de revisão por pares (plano/design); fonte normativa da régua. |
| `xpz-llm-delegate/SKILL.md` | O **mecanismo** de delegação a LLM secundário. O painel é um caso de uso dirigido por humano desse mecanismo. |

## Futuros

- **Harness de disparo** do painel (script/workflow que recebe o manuscrito e a lista de revisores, dispara cada um, coleta os vereditos no livro-razão) — hoje a orquestração é ad-hoc.
- **Backends one-shot** (`llm`/`mods`) para enviar só o prompt, sem camada agêntica.
- **Personas de revisão** (lentes distintas por revisor) — em tensão com a independência do prompt mínimo; pesquisa.
