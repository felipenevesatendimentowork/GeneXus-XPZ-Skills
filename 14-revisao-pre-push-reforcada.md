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
- **Critério de push-ready:** *depois da última alteração do repositório*, **o painel inteiro** responde "sem gap" sobre **esse estado final**. Passe parcial — inclusive o do dissidente sozinho, ou de revisores que aprovaram um commit anterior — **não** conta.
- **Voltar ao dissidente:** após corrigir, **re-passar pelo revisor que objetou**, para confirmar que a correção fecha a objeção **nos termos dele** — não declarar vitória só porque os mais lenientes passaram.
- **Convergência é o pronto:** encerra quando o painel diverso inteiro converge em **zero gaps no HEAD atual**. Só então o estado é push-ready (o push em si continua exigindo autorização explícita do usuário, conforme o `13`).

## Proibição: a reforçada NÃO é delegável a um agente só

**Não** delegar a Revisão Pré-Push Reforçada inteira a um único agente ou subagente — por exemplo, mandar a um subagente um prompt do tipo "Execute a Revisão Pré-Push Reforçada". Esta proibição existe para impedir que mantenedores recaiam nessa ideia.

O motivo **não** é falta de mecanismo: um agente até consegue disparar outros modelos (via [`xpz-llm-delegate`](xpz-llm-delegate/SKILL.md) / opencode) ou tentar gerar sub-subagentes. O motivo é que a **triagem de gaps é um nó humano da régua** ("pára no 1º gap → triagem humana → o humano decide a correção"). Sem esse nó, no primeiro gap o agente só pode:

- **auto-triar** o próprio gap — colapsa a salvaguarda (a régua existe justamente para o revisor _não_ julgar os próprios gaps);
- **auto-corrigir** — viola "pré-push pára no relatório, correção só após aprovação humana";
- **só reportar e parar** — degenera na rotina do [`13`](13-revisao-pre-push.md), não é a reforçada.

Tirar o humano não "automatiza" a reforçada — **desmonta** ela. O que se delega a um revisor (humano ou agente) é a **rotina** do `13` (prompt mínimo `execute a rotina pre push, sem push`); a **orquestração** reforçada inteira, nunca.

## Relação com os outros documentos

- **`13-revisao-pre-push.md`** — a **rotina** (o *quê* cada revisor executa). Este `14` é a **orquestração** (o *como conduzir vários*) por cima dela.
- **`xpz-llm-delegate/SKILL.md`** — o **mecanismo** de delegação a LLM secundário. O painel deste `14` é um caso de uso dirigido por humano desse mecanismo.
