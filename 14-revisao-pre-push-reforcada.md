# 14 — Revisão pré-push reforçada (painel multi-modelo)

## Papel do documento

Tier **reforçado e opcional** da revisão pré-push. O [`13-revisao-pre-push.md`](13-revisao-pre-push.md) define a **rotina** — o que cada revisor executa: passo mecânico + fase semântica. Este documento define a **orquestração de um painel de revisores diversos** por cima dessa rotina, e a **régua de convergência** que decide quando o estado está pronto para push.

O **mecanismo** de delegação (como disparar revisores secundários: opencode, prompt, async + watcher, leitura do resultado) é da skill [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) — **não** é duplicado aqui. Este documento guarda apenas a **política**.

Acionamento é **sempre humano**, como toda delegação (ver `xpz-llm-delegate`). Este tier é **opcional**: a rotina do `13` basta para o fluxo normal; o painel é escalonamento quando se quer reforço por diversidade de modelo.

## A régua

- **Independência:** todos os revisores recebem o **mesmo prompt mínimo verbatim** (`execute a rotina pre push, sem push`), sem enriquecimento — para não contaminar a revisão com o que o agente principal já sabe ou fez.
- **Diversidade de modelo:** preferir revisores de **famílias diferentes** (cegos diferentes). Inclui subagentes locais e LLMs secundários via [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md).
- **Pára no 1º gap:** o primeiro revisor que acusar gap **interrompe a rodada** → **triagem humana** (nem todo apontamento é gap real — pode ser convenção da casa ou falso positivo) → correção → **commit imediato** da correção.
- **Painel _stale_ a cada commit:** todo commit novo **invalida** os vereditos anteriores — eles revisaram outro estado. Um "sem gap" só vale para o commit **exato** que foi revisado.
- **O ciclo não pára no meio.** Acionada uma vez, a reforçada é um **laço**: gap → triagem humana → correção+commit → **re-montar o painel sobre o novo HEAD automaticamente** (sem novo acionamento) → repetir até a convergência. Únicos pontos de parada: um **gap** (para triagem) e a **convergência** (para a decisão de push). **"Sem push" restringe só o push final — não interrompe o laço.** Corrigir um gap e parar, sem re-passar, deixa o laço pela metade.
- **Critério de push-ready:** *depois da última alteração do repositório*, **o painel inteiro** responde "sem gap" sobre **esse estado final**. Passe parcial — inclusive o do dissidente sozinho, ou de revisores que aprovaram um commit anterior — **não** conta.
- **Voltar ao dissidente:** após corrigir, **re-passar pelo revisor que objetou**, para confirmar que a correção fecha a objeção **nos termos dele** — não declarar vitória só porque os mais lenientes passaram.
- **Convergência é o pronto:** encerra quando o painel diverso inteiro converge em **zero gaps no HEAD atual**. Só então o estado é push-ready (o push em si continua exigindo autorização explícita do usuário, conforme o `13`).

## Papéis: montagem e opinião (agente) vs decisão (humano)

A reforçada tem **três** tipos de passo:

- **(a) Montagem mecânica do painel** — disparar os revisores diversos (modelos via [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) + subagentes), cada um com o prompt mínimo verbatim `execute a rotina pre push, sem push`, e **colher os vereditos**. Um agente **pode** fazer isso, como mãos do humano, **sob acionamento humano** (o pedido "execute a reforçada" é esse acionamento).
- **(b) Nós de decisão — a OPINIÃO do agente é esperada; a DECISÃO é humana.** Quem **decide** se o gap é real (vs convenção/falso positivo), **declara** a convergência e **autoriza** o push é o humano. Mas o agente, como orquestrador, **deve dar sua opinião e recomendação** sobre cada ponto — ele tem o contexto e o humano espera esse insumo **antes** de decidir. O que o agente **não** faz é **decidir e agir sozinho**: auto-triar e já aplicar a correção, declarar convergência por conta própria, ou dar push.
- **(c) Ser um revisor** — rodar a rotina do [`13`](13-revisao-pre-push.md). Qualquer revisor, humano ou agente.

**Composição do painel:** princípio — **famílias distintas da do orquestrador**, cegos independentes; descobrir os modelos disponíveis via `opencode models`. Lista **recomendada hoje** (sugestão, ajustável conforme o ambiente e a evolução dos modelos; o princípio prevalece sobre a lista): `deepseek-v4-pro`, `glm-5.1`, `minimax-m3` (externos via opencode), mais um subagente local como cego adicional.

**O que um agente DEVE fazer ao receber "Execute a Revisão Pré-Push Reforçada":** **montar o painel** (a) — disparar os revisores **em sequência**, pausando no **1º gap**. Ali, **entregar os vereditos com a sua própria triagem recomendada** — não fatos neutros e silêncio: dizer o que **você acha** que é gap real vs convenção, e por quê — deixando a **decisão** ao humano. Não disparar o lote inteiro de uma vez (perde-se o parar-no-1º-gap). **Concisão:** relatar cada veredito e a triagem recomendada de forma enxuta; não re-resumir o estado completo a cada passo.

**Proibição (o guardrail):** um agente **não** pode (1) **decidir e agir** no lugar do humano — auto-triar e aplicar correção, declarar convergência, dar push — nem (2) **fingir** que um solo (só o passo c) é a reforçada. A **decisão** de triagem/convergência/push é nó humano; sem ele, ou se colapsa a salvaguarda, ou se degenera na rotina do `13`. O erro **não** é montar o painel **nem opinar** (isso o agente deve); o erro é o agente **decidir/agir** no lugar do humano.

## Relação com os outros documentos

- **`13-revisao-pre-push.md`** — a **rotina** (o *quê* cada revisor executa). Este `14` é a **orquestração** (o *como conduzir vários*) por cima dela.
- **`xpz-llm-delegate/SKILL.md`** — o **mecanismo** de delegação a LLM secundário. O painel deste `14` é um caso de uso dirigido por humano desse mecanismo.
