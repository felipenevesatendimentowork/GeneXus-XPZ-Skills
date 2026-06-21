# Ideias Pendentes

## Política de retirada de pendências

Quando uma entrada deste arquivo for resolvida, implementada ou incorporada ao contrato metodológico vigente, ela deve ser movida para o arquivo mensal correspondente em `historico/IdeiasImplementadas_YYYYMM.md` antes de ser retirada daqui. Este arquivo deve manter apenas ideias ainda pendentes ou subfrentes residuais explicitamente abertas.

Cada entrada usa dois campos curtos logo abaixo do titulo:

- **Importância** — quanto dói se a ideia nunca for implementada. Valores: `baixa` (útil mas dispensável), `média` (gap real com workaround manual), `alta` (risco de dano efetivo, como contaminação de KB, perda de trabalho ou falso negativo crítico).
- **Maturidade** — quão pronta a ideia está para virar frente de implementação. Valores: `ideia` (direção identificada, decisões de design em aberto), `pesquisa feita` (direção técnica resolvida, falta gatilho de caso real), `pronta para implementar` (caso concreto identificado, decisões fechadas, falta executar).

Entradas legadas sem avaliação carregam `FALTA AVALIAR` em ambos os campos até que sejam revistas em sessão dedicada.

## Cobrir padrões de delegação não-auditados pelo check `forwards_unknown_engine_param`

- **Importância** — baixa (limite conhecido declarado, sem falso-positivo). O check `forwards_unknown_engine_param` (helper `scripts/XpzWrapperEngineParamSupport.ps1`) audita o repasse wrapper→motor-compartilhado só para o padrão seguro `& $V` com `$V = Join-Path … 'scripts\<Leaf>.ps1'` (literal `'scripts'` no AST, resolução transitiva profundidade 1). Por desenho conservador (falso-positivo bloqueia pré-push de pasta paralela), **pula** — sem auditar — padrões reais possíveis em wrappers materializados: repasse **posicional** (`& $engine $valor`), splat por variável automática `@PSBoundParameters`, raiz **totalmente dinâmica**/concatenada (`"scripts\$leaf"`), resolução **multi-hop** (`$d = Join-Path $S 'scripts'; $e = Join-Path $d 'X.ps1'`), reatribuição não-rastreável da variável-raiz/intermediária, `Invoke-Expression`/dot-source/pipeline. Nenhum molde atual usa esses; o risco é um wrapper local divergir do molde nessas formas e escapar à auditoria (falso-negativo, nunca falso-positivo). Caso-borda residual: `Join-Path $repoRoot 'scripts\<X>.ps1'` apontando para arquivo LOCAL cujo leaf coincide com motor canônico (fora do padrão dos moldes).
- **Maturidade** — ideia (decisões de design em aberto). Direção: estender a resolução AST por forma, sempre preservando a postura conservadora (na dúvida, pular sem sinalizar); um caso-prova real (wrapper que escape e cause erro de binding em runtime) seria o gatilho para priorizar. Sub-ideia da mesma frente: **mecanizar a regra de engine-path da 8.a.ii reusando o helper** — hoje a 8.a.ii é texto single-literal (`Join-Path $SharedSkillsRoot 'scripts\<nome>.ps1'`), e o helper já cobre as formas aninhada/multi-arg/raiz-renomeada; a 8.a.ii poderia passar a apontar para o sinal mecanizado em vez de só descrever o caso por texto.

## Atualizar wrappers locais `Update-*KbFromXpz.ps1` em pastas paralelas para o contrato JSON do sync

- **Importância** — média (gap real com workaround). O `Sync-GeneXusXpzToXml.ps1` passou a emitir JSON de máquina no stdout (texto humano no stderr); os wrappers locais clonados em pastas paralelas — "hardcoded em praticamente todas" — ainda foram escritos para a saída textual antiga. Até atualizá-los, o consumo nominal programático do resultado fica comprometido nessas pastas (o `-ReportPath` segue como contorno).
- **Maturidade** — pronta para implementar. O molde `xpz-kb-parallel-setup/examples/Update-KbFromXpz.example.ps1` já foi corrigido nesta frente e serve de referência: consumir o JSON via `ConvertFrom-Json`, rotear todo diagnóstico humano para stderr (`Write-Host`/`Write-Warning`/`Write-Information` vazam para o stdout capturado de processo filho), `.Count`→`[int]` em `FullSnapshotMissing/Extra`, e re-emitir só a linha JSON no stdout.

Derivada da frente do contrato JSON do `Sync-GeneXusXpzToXml.ps1` (ver `CHANGELOG`). A propagação aos clones deve passar pela skill `xpz-kb-parallel-setup`. Sub-ideia relacionada: um **checador de conformidade portátil** ("o wrapper local emite JSON conformante no stdout?") com casa natural na `xpz-kb-parallel-pre-push`, para um agente confirmar a conformidade do clone local após a migração. Caveat de gate: trabalhar dentro de uma pasta paralela aciona `xpz-kb-parallel-setup`.

## Trava contra o agente reduzir o painel de revisão por pares por conta própria (oferecer ≠ decidir)

- **Importância** — média (gap de governança real). A régua (`15-revisao-por-pares.md`/`14-revisao-pre-push-reforcada.md`/`xpz-llm-delegate`) diz "não descartar revisor preferido em silêncio" e que reduzir o painel exige **decisão humana explícita**, mas **não há trava** que impeça o agente de declarar suficiência no **piso** (≥2 famílias) e **recomendar convergência/push** por conta própria. Incidente real (2026-06-20, pré-push reforçada da frente do contrato JSON do sync): o agente rodou só 2 revisores, declarou "piso atingido" e recomendou o push; o usuário corrigiu — o agente pode **oferecer** painel menor, nunca **decidir** reduzi-lo. Parar no piso e recomendar push é justamente o que o guardrail do `14`/`15` proíbe.
- **Maturidade** — ideia (decisões de design em aberto). Direção: regra **positiva** no `15` (composição/régua) e `14` — por padrão o agente despacha a **lista preferida inteira**; painel menor só como **pergunta**, e parar no piso + recomendar convergência/push fica proibido sem decisão humana de reduzir. Avaliar suporte mecânico (ex.: o closeout/`Resolve-LlmDelegatePanelDiversity` sinalizar "preferidos despacháveis não despachados" como bloqueio de recibo, análogo ao que o closeout já faz para estados auditáveis incompletos). A própria correção deve passar por revisão por pares.

Reforça a lição "consultar a lista INTEIRA, não parar no piso" registrada na frente Revisão por Pares formalizada.

## URGENTE — Reduzir as variações de chamada dos adapters de delegação que disparam prompt de autorização

- **Importância** — alta (atrito operacional recorrente: está atrasando e incomodando o usuário em sessões reais; cada prompt desnecessário prende o fluxo). O gargalo **não é falta de script** — são duas causas: (1) o **prompt passado como argv entre aspas** somado a `-Cd "<path>"` entre aspas (vários segmentos entre aspas no meio do comando) **quebra o match** da allowlist (que casa literal), além do **limite ~32KB de linha de comando do Windows** para prompts grandes; (2) **deriva de forma** — a mesma ação chamada de N jeitos (`& "<absoluto>"` com aspas vs. `pwsh -NoProfile -File scripts/<X>.ps1` relativo sem aspas), cada variante exigindo uma entrada de allowlist distinta. Caso real 2026-06-21: `Invoke-Codex.ps1` chamado como `& "<abs>\Invoke-Codex.ps1" "<prompt>" -Model gpt-5.5 -Cd "<abs>" -TimeoutSec 420` promptou apesar das entradas `PowerShell(& "…\scripts\*")` existentes.
- **Maturidade** — pronta para implementar (há referência pronta: o `Invoke-OpenCode.ps1` já tem `-MessagePath`). Direção, em ordem de retorno:
  - **(a) Dar `-MessagePath <arquivo>` ao `Invoke-Codex.ps1`, `Invoke-Gemini.ps1` e `Invoke-Copilot.ps1`**, espelhando o `Invoke-OpenCode.ps1`. Com o prompt vindo de **arquivo**, o comando que o agente digita perde o blob entre aspas e o `-Cd` pode ir sem aspas (path sem espaços) → `pwsh -NoProfile -File scripts/Invoke-Codex.ps1 -MessagePath <arquivo> -Model gpt-5.5 -Cd C:/Dev/… -TimeoutSec 420`, **zero aspas embutidas**, casando a entrada `Bash(pwsh -NoProfile -File scripts/*)` já existente. **Isto desacopla o conserto do atrito de allowlist da pendência de stdin/assinatura** (ver entrada seguinte): o `-MessagePath` resolve a fricção mesmo que internamente o adapter ainda use argv; só o limite de 32KB para Gemini/Copilot continua dependendo da migração stdin.
  - **(b) Documentar UMA forma canônica de invocação** desses scripts na `xpz-llm-delegate/SKILL.md` e no `AGENTS.md` (repo serve vários agentes — Claude Code, Codex, Cursor, OpenCode —, então a convenção tem que morar onde **todo** agente lê, não na memória pessoal de um), e **enxugar a allowlist** para cobrir essa forma única em vez de N variantes.
- **NÃO** criar um wrapper guarda-chuva novo só para driblar o matcher: custa inventário (`09`), paridade e manutenção; o ganho real vem de (a)+(b). Um único `Invoke-PeerReviewer.ps1` seria só ergonomia opcional, não a raiz. Princípio: **menos variação > mais scripts**.
- **Relacionada:** absorve o eixo de atrito da entrada seguinte (migração stdin de `Invoke-Gemini`/`Invoke-Copilot`) para o caso `-MessagePath`; a parte de **stdin + limite de 32KB** dessas duas continua dependente de assinatura para validação empírica e fica naquela entrada.

## Migrar `Invoke-Gemini`/`Invoke-Copilot` para stdin e/ou guard de tamanho de prompt

- **Importância** — baixa (workaround trivial existe). Os adapters argument-based `Invoke-Gemini.ps1` e `Invoke-Copilot.ps1` ainda passam o prompt por **argv**, sujeitos ao **limite ~32KB de linha de comando do Windows** (`Argument list too long`) e ao sintoma não-determinístico `StandardOutputEncoding` em host com stdout não-redirecionado. Workaround atual: invocá-los pela ferramenta Bash (stdout em pipe) com prompt enxuto.
- **Maturidade** — ideia (decisões em aberto + dependência externa). Bloqueado por **não haver assinatura** de Gemini/Copilot nesta máquina para validar empiricamente se aceitam o prompt por stdin (como o opencode aceita). Direções: (a) quando houver assinatura, testar `gemini -p`/`copilot -p` lendo stdin e, se aceitarem, migrá-los ao padrão **stdin-based** espelhando o opencode (`Invoke-OpenCode`/`Start-OpenCodeJob`, frente concluída — ver `CHANGELOG`); (b) enquanto isso, avaliar um **guard de tamanho** que rejeite com erro claro quando o prompt exceder o limite por argv, em vez do `Argument list too long` cru. Derivada da frente de endurecimento dos adapters opencode (escopo (i): só opencode).

## Follow-up: versão-de-contrato confrontável + gate consultivo de lockstep (etapa 2 da auditoria de drift de consumo)

- **Importância** — média (a etapa 1 já fecha o caso atual; isto endurece contra bumps futuros e mecaniza a regra de método).
- **Maturidade** — ideia (versão-de-contrato tem design em aberto; o gate consultivo é direto).

**Já implementado (etapa 1, migrado para `historico/IdeiasImplementadas_202606.md`):** o motivo `INVENTORY_CUSTOMIZED(reason=consumes_legacy_text_stdout)` em `scripts/Test-XpzWrapperInventory.ps1` (heurística texto-vs-molde para `Update-*KbFromXpz.ps1` × `Sync-GeneXusXpzToXml.ps1`) + 8.a.ii / tabela 8.h / regra de `INVENTORY_CUSTOMIZED` por motivo no `SKILL.md` + self-test; e a **regra-doc de lockstep** no `13` (§3 Comparação documental) e no `AGENTS.md` raiz (Revisão pré-push). Origem: relato de agente de pasta paralela após o push do contrato JSON do sync (`e11ffbc`/`ef8530b`, ver [[project_sync_json_contract]]).

**C (etapa 2) — versão-de-contrato confrontável:** amarrar o `SchemaVersion`/`Kind` que o motor `Sync-GeneXusXpzToXml.ps1` carimba a uma noção de versão-de-contrato que a auditoria confronte. Motivo concreto: a heurística textual da etapa 1 é **cega a drift de versão dentro do JSON** — um wrapper que parseia v1 com `ConvertFrom-Json` passa **mesmo** com o motor em `SchemaVersion=2`. Também não detecta migração parcial nem parsers alternativos (`System.Text.Json`). Gatilho de revisão = **próximo bump de contrato** do motor de sync (até lá só há v1 em campo).

**Gate consultivo (opcional) — lockstep mecânico:** um gate no orquestrador da pré-push análogo ao `scripts/Test-PrePushSharedScriptSkillCoverage.ps1`, mas focado em **skill que AUDITA consumidores**: quando o diff toca um motor compartilhado com contrato de saída e existe skill de auditoria de consumidores conhecida não-tocada, avisar. Hoje a regra de lockstep vive só como pergunta-doc (etapa 1); este gate a tornaria mecânica. Ver [[project_xpz_kb_parallel_pre_push]] para o precedente do mecanismo.

**Relacionada:** a frente derivada (lado pasta paralela) "atualizar wrappers locais `Update-*KbFromXpz.ps1`" — corrige os clones reais nas pastas paralelas; esta etapa apenas torna o **gate** mais robusto a versões.

## Rebaixar o warning `envelope-minimo`/`panel-envelope-minimo` de "apto com ressalvas" para informativo no pacote seletivo normal

- **Importância** — baixa (ruído de status, sem dano). Todo pacote seletivo de objeto único gerado sem `--template-package-path` sobe com `status="apto com ressalvas"` por causa do warning `envelope-minimo` (`scripts/New-XpzImportPackage.py:101`; `panel-envelope-minimo` em `:265` para Panel), mesmo sendo o caminho normal e correto. O rótulo "ressalvas" perde sinal: o operador não distingue o caso esperado do caso que realmente merece atenção (pacote misto/complexo).
- **Maturidade** — ideia (decisão de design em aberto). Direção: quando o pacote for pequeno/seletivo e não houver `--template-package-path` comparável disponível, rebaixar `envelope-minimo`/`panel-envelope-minimo` de warning para `information` (ou nível equivalente que **não** dispare `apto com ressalvas`), preservando o aviso real para pacotes mistos/complexos e **sem** enfraquecer o gate de `error :` no log. O status é decidido em `scripts/New-XpzImportPackage.py:414`/`:463` (`apto com ressalvas` sempre que há `warnings`); avaliar mover esses dois avisos para a lista `information` nesses casos, mantendo `warnings` para envelope ausente em pacote que de fato precisaria do template.

Skills consumidoras: `xpz-builder`, `xpz-msbuild-import-export`. Motor: `scripts/New-XpzImportPackage.ps1` / `.py`. Origem: tarefa secundária opcional levantada no prompt de um agente de pasta paralela (2026-06-21), fora do escopo da frente do `.ContainsKey`/OrderedDictionary; registrada aqui para outra sessão cuidar.

## Maturar a Fase 2b da rotina pré-push de pasta paralela de KB (Fase 2b da skill `xpz-kb-parallel-pre-push`, hoje classificador documental)

**Importância:** média (o sub-caso **destrutivo** tende a `alta` — falso negativo de regressão por dependente não enumerado; hoje mitigado só pelo build)
**Maturidade:** ideia (decisões de runbook em aberto por `decisao-001`; alguns sub-achados abaixo já são "pesquisa feita")

**Origem:** sessão 2026-06-12, a pedido do usuário. Estudo do experimento incubado em `C:\Dev\Prod\Gx_FabricaBrasil\pre-push-routine` (8 experimentos + `decisao-001`) e coleta de dados **read-only (consulta de fora)** contra o push real pendente da KB FabricaBrasil (10 commits, frente "OperacaoItem — Título Intermediário"). O experimento ainda **não** é referenciado em nenhuma skill nem no `09`.

### O experimento existente (resumo)

Rotina pré-push específica para pasta paralela de KB, em 3 fases: **Fase 1 mecânica** (orquestrador `Invoke-FabricaBrasilPrePushPhase1.ps1`, 11 gates G1–G5/K1–K4/K8/K9/K11, exit codes, `-AsJson`, princípio de delegação — K8/K9 consomem gates canônicos), **Fase 2a estrutural** (parcial scriptada: higiene de frente/pacote + checklist de agente) e **Fase 2b regressão** (deliberadamente **não** scriptada — `decisao-001`). Conclusão empírica dos experimentos 005/006: o cheque **autoritativo** de regressão é o **Specify+Build** (`xpz-msbuild-build`), não a análise estática de XML; o estático é triagem barata antes do build.

### O buraco empírico: perfil estrutural-aditivo

Os 8 experimentos só exercitaram mudança em rules `[web]` (003) e em corpo de Procedure (004-piloto). O perfil **Transaction ganhando atributos via FK de subtype** nunca foi coberto. Caso real estudado: `OperacaoItem` ganha 5 atributos via `SubTypeGroup OperacaoItemTituloIntermediario` (FK a `Pessoa`), todos nullable, **zero removidos**.

### Achados coletados (dados)

1. **Eixo 2 incompleto** [pesquisa feita]: `who-uses(Transaction:OperacaoItem)` = **6** (só BC Load/Save + binding WorkWith); `who-uses(Table:OperacaoItem)` = **14** (navegadores `For each`, relação `navigates_explicit_table`). Os experimentos só consultaram a Transaction. Receita correta para mudança estrutural: **`who-uses(Transaction)` ∪ `who-uses(Table)`** — senão os navegadores `For each` somem do relatório. Prova: `procAtualizaLancamentoItens...` navega `for each OperacaoItem` (linha 197) e **consome os atributos novos** (linhas 264–267), mas é invisível no who-uses da Transaction.
2. **who-uses de atributo recém-criado** retorna só auto-declarações estruturais (Table index member + Transaction level attribute), não consumidores — semântica diferente da dependência-de-consumo que os experimentos assumiram.
3. **Sutileza cabeça-detalhe no F1**: `Operacao.xml` é SAME (descartada pelo filtro) mas é a **cabeça** cujo detalhe mudou; carrega 20 dependentes. "Descartar SAME cedo" está certo para o arquivo, mas o analista não pode concluir que a cabeça está fora do escopo.
4. **Roteamento por perfil de risco**: zero atributos removidos ⇒ o eixo `quebrado`-por-referência-órfã é **no-op por construção**; o esforço migra para o eixo de **omissão**. Sinal mecânico: F1 + "algum `<Attribute>` removido no diff?".
5. **Status novo `suspeito-por-omissão`** [pesquisa feita como heurística]: 11 navegadores da Table, **2 tocados, 9 intocados**. Ranqueados por afinidade de nome ao conceito novo, os 2 de topo (`procAtualizaTituloDaTroca`, `procCompensacaoDeTitulos`) validaram-se como candidatos de domínio **real** (ambos manipulam `Titulo`/`TituloFavorecido`/parte do título). Heurística = **sinal, não ruído** (2/2 checados). **Não** confirmados como bugs — confirmar exige intenção de negócio + dev + build. A shortlist sai de graça do cruzamento `who-uses(Table)` × diff git.
6. **Assinatura mecânica da FK-de-subtype aditiva**: `SubTypeGroup` NEW (mapeando subtipos a supertipos de `Pessoa`) + `Table` ganha índice **`Automatic` Duplicate** sobre as colunas FK + Transaction ganha level attributes nullable. Reconhecível por padrão ⇒ um motor futuro baixa o nível de alarme de quebra automaticamente e redireciona atenção à omissão.

### Direção proposta para a "Fase 2b madura"

Para o caso estrutural, a 2b não é um runbook que dá selo de "sem regressão" — é um **classificador de perfil de risco**:

- Consulta de Eixo 2 = `who-uses(Transaction)` ∪ `who-uses(Table)`.
- F1 + "algum atributo removido?" roteia: **removido** → eixo de quebra (build é autoritativo); **nenhum removido** → eixo de omissão.
- Novo status `suspeito-por-omissão` com shortlist de navegadores intocados ranqueada por afinidade.
- Reconhecimento mecânico da FK-de-subtype aditiva para calibrar o alarme.

### Sub-caso destrutivo (caracterizado em 2026-06-12)

O sub-caso **destrutivo** (atributo removido/renomeado, domínio trocado, chave alterada) — onde o eixo de quebra realmente morde — foi caracterizado por sondagem em atributo estabelecido (`OperacaoItemContaId`, sem mudança real; experimento mental sobre estado atual):

- **Índice cego**: `who-uses(Attribute:OperacaoItemContaId)` = **2**, ambos auto-declarações estruturais (Table index member + Transaction level attribute). O extrator **não modela** "objeto X referencia atributo A no `Source`/conditions".
- **Verdade textual**: **119 ocorrências em 25 arquivos** (~21 objetos consumidores reais: DataSelectors, ~15 Procedures de relatório/lançamento, WebPanels, SDTs).
- Para uma remoção, o `who-uses` reportaria **2 (ambos estruturais = "ninguém")** contra **~21 que quebrariam**. Ponto cego catastrófico.
- **Nem `who-uses(Table)` basta**: os consumidores grep incluem `procRelatorioTitulos*`, `dsRelatoriosDeTitulosViaLancamentos`, `sdtTituloParametros` — **nenhum** deles estava nos 14 navegadores da Table.

**Receita de Eixo-2 para o caso destrutivo** (diferente do aditivo): o enumerador confiável é **grep textual do nome do atributo** (estilo D1, com filtro de comentário `//`), **não** `who-uses`; o veredito de quebra é o **build**. Isso fundamenta, por caminho direto, a conclusão dos experimentos 005/006 de que o build é autoritativo: para remoção/rename de atributo, a análise estática via índice **não enumera** sequer o raio de impacto.

**Assimetria aditivo↔destrutivo** (fato de design central): aditivo → eixo de quebra é no-op, `who-uses(Table)` dá superfície útil + shortlist de omissão (sinal); destrutivo → eixo de quebra morde, `who-uses` cego, só grep+build enumeram/julgam. O roteamento "algum `<Attribute>` removido no diff?" (achado 4) é o que separa os dois regimes.

### Experimento real de rename (2026-06-12, KB `wsEducacaoSpTeste`)

Atributo `DistribuidoraNome` → `DistribuidoraNomeTeste` produzido sob medida pelo dev (rename na IDE + sync). Achado: o rename do GeneXus **propaga perfeitamente** para todo código/estrutura antes do export — **zero órfãos** nos ~7 consumidores. As 27 ocorrências do nome antigo que sobraram no acervo são todas legítimas: variável homônima `&DistribuidoraNome` (variável não renomeia com o atributo), nome do objeto `procDistribuidoraNome`, e o arquivo-resíduo de sync. A única referência ao atributo nu (`procDistribuidoraNome:9`, RHS) foi atualizada para o novo nome.

**Conclusões:** (1) rename **não** é destrutivo — sai do regime; o destrutivo real é **remoção** (delete), sem alvo de propagação — é o que a próxima probe deve testar. (2) **Prova empírica de que grep sozinho dá falso alarme**: o grep ingênuo deu 27 ocorrências/8 arquivos (leitura ingênua = "KB quebrada"), mas a classificação precisa deu **zero órfãos** — só parser/build distinguem atributo nu de variável homônima. Valida o build como autoridade e o `references_attribute` do Plano A (que faria essa distinção que o grep não faz).

**Cross-validação pelo full sync do dev (mesmo episódio):** GUID idêntico nos dois arquivos confirma rename (não delete+add); full export limpo (485 objetos, exitCode=0, sem Categoria B). Dois aprendizados: (a) **detectar** o regime destrutivo é barato — o `-FullSnapshot` acusou o nome antigo como `Extra=1` (reconciliação de full export sinaliza rename/remoção de graça; no incremental, `git diff` mostra o arquivo deletado/criado). O difícil não é detectar, é **enumerar consumidores + veredito** (grep ambíguo, build autoritativo). (b) Gap de tooling **identificado na época e já resolvido**: na verdade **não havia limpeza de resíduo nenhuma** — o sync apenas lançava `throw` em `Extra > 0`, deixando o arquivo de nome antigo como resíduo no acervo (a premissa original da ideia, de que existiria limpeza por GUID cobrindo `<Object>` e ignorando `<Attribute>`, foi corrigida na implementação). **Resolvido** pela frente Sync GUID-aware (`Resolve-GuidAwareRenames` em `scripts/Sync-GeneXusXpzToXml.ps1`), que sob `-FullSnapshot` reconcilia o rename pela identidade `guid` cobrindo **`Attribute` e `Object`** desde a introdução (renomeia o arquivo existente em vez de deixar resíduo); ver `CHANGELOG.md` e `xpz-sync/SKILL.md`.

### Experimento real de remoção (2026-06-12, KB `wsEducacaoSpTeste`) — a IDE bloqueia

Tentar deletar o atributo (`DistribuidoraNomeTeste`) na IDE GeneXus 18 retornou: **"Object(s) could not be deleted: Attribute 'DistribuidoraNomeTeste' is referenced at least by Attribute 'EscolaDistribuidoraNome'. (Artech.Layers.BL)"**. A IDE **bloqueia** a deleção de atributo referenciado (fail-fast no primeiro referenciador — aqui, o subtipo). A probe se resolveu sem sync.

**Implicação (fecha o regime destrutivo):** combinado com a probe de rename (a IDE propaga), o GeneXus **previne estruturalmente os dois caminhos** pelos quais uma mudança de atributo orfanaria consumidores: rename → propaga; delete → bloqueado enquanto referenciado. Para deletar, o dev precisa **remover todas as referências antes** — e nesse ponto os consumidores já foram atualizados, então o diff mostra mudança **coordenada**, não órfão silencioso. O regime destrutivo de "referência órfã de atributo chegando ao acervo" é **essencialmente inalcançável** pelo desenvolvimento normal mediado pela IDE — coerente com os 223 commits sem nenhum caso destrutivo (não só raro: estruturalmente impedido).

**Recalibração honesta do Plano A:** isso **enfraquece a motivação destrutiva** do `references_attribute` (o caso que ele enumeraria é o que a IDE previne). O Plano A mantém valor para **troca de domínio** (dois saltos, não bloqueada) e impacto geral / `who-uses(Attribute)` significativo, mas sua **urgência cai** — reavaliar prioridade à luz disto.

**Nuance aberta (última ponta):** o bloqueio aqui foi por referência **estrutural** (subtipo). Se a guarda da IDE também cobre referência **só em código** (`<Source>`, sem subtipo/transação) é o que falta confirmar; mas a direção está clara e a conclusão central se sustenta.

### Sub-caso troca de domínio (caracterizado em 2026-06-12) — consulta de dois saltos

Sonda em `Domain:Aliquota`: `who-uses(Domain:Aliquota)` = **64**, relação **`based_on_domain`** (Property `idBasedOn`). O índice **cobre** o salto 1 (Domain → atributos baseados nele). Mas o salto 2 (cada atributo afetado → quem o consome e quebraria) **cai no mesmo buraco** do caso destrutivo (consumo de atributo no corpo é cego). Receita = `who-uses(Domain)` para o conjunto de atributos (índice) → por atributo, **grep + build** para consumidores.

### Experimento real de troca de tipo (2026-06-12, KB `wsEducacaoSpTeste`) — build OK, reorg não-backward-compatible

Atributo `ContratoNumero` (que é a **PK** da Contrato) trocado de `Numeric(10)` → `Character(15)` na IDE.
- **IDE:** aceitou salvar **sem bloquear nem avisar** (assimetria com o delete, que bloqueia).
- **Build:** **SUCCESS, zero erro de cast/compilação** — o GeneXus propagou o novo tipo a todos os consumidores e **auto-gerou conversão de dados** (`ContratoNumero.tostring(10,0)`).
- **Database Impact Analysis:** `nfo0003: reorganization not backward compatible` — `ALTER COLUMN ContratoNumero TYPE CHAR(15)`, **DROP/ADD da PK**, e **cascata para a tabela `GuiaPed`** (FK via subtipo `GuiaPedContrato`).

**Conclusão:** troca de tipo (mesmo em PK) **não é risco de regressão de código** — o GeneXus resolve o código e gera a migração. É **risco de schema/dados**: reorg não-backward-compatible em produção. A autoridade é a **Database Impact Analysis / detecção de reorg**, que o `xpz-msbuild-build` **já porta** via `FailIfReorg` (uma troca de tipo dispara `ReorgDetected=true`). Análise estática de XML e o índice **não enxergam** isto.

**Reavaliação cumulativa (4 probes em `wsEducacaoSpTeste`):** aditivo → triagem estática; rename → IDE propaga (não-evento); delete → IDE bloqueia (prevenido); troca de tipo/chave → build + reorg detection (gate já existe). O **build** (Specify + Impact Analysis + `FailIfReorg`) é a autoridade dos regimes estrutural/tipo/chave. A motivação de **detecção de regressão** do Plano A (`references_attribute`) encolhe a cada probe — resta valor de impacto geral / `who-uses(Attribute)` significativo, não de regressão. **Reavaliar a prioridade do Plano A à luz disto.**

### Caracterização precisa do índice SQLite (refinada em 2026-06-12)

O índice **não é cego em bloco** — a cegueira é **estreita e específica**. Cobre bem: objeto→objeto (`calls_procedure`, `navigates_explicit_table`, `loads/saves_business_component`, `formula_*`, `workwith_*`), casas estruturais do atributo (`has_level_attribute`, `has_index_member_attribute`) e **`Attribute → Domain` (`based_on_domain`)**. O **único** buraco material é **"objeto X lê/escreve atributo A no `Source`/conditions"** — relação faltante, não carência ampla.

**Decisão de design A↔B** (em aberto): (A) **melhorar o índice** adicionando relação `references_attribute` (consumo de atributo no corpo) — fecha de uma vez os saltos-2 do destrutivo **e** do domínio; esforço comparável ao fix `fdb4b3f` (Formula-em-Attribute), que é precedente exato do mesmo tipo de extrator; vs (B) **não mexer no índice** e a rotina rotear por ferramenta (`who-uses` objeto / grep atributo / build veredito). Como o buraco é uma única relação estreita e precedente-corrigível, (A) é mais tratável do que parecia. **Preferência do usuário (2026-06-12): (A)** — baixo custo de manutenção do índice e capacidade de atender mais consultas.

**Quantificação do ruído do grep (caminho B) — sonda em `OperacaoItemContaId`, 2026-06-12:** grep ingênuo = 119 ocorrências / 25 arquivos; com word-boundary cai para 102/24 (~17 falsos positivos por substring, ~14%); ~20 ocorrências são linhas de comentário `//`; ~16 são casas estruturais (Transaction 14, Table 1, SubTypeGroup 1), não consumo. Net ≈ 66 referências de consumo real em ~21 objetos. O caminho B exige **dois filtros** (boundary + comentário) e ainda assim devolve "o nome aparece aqui", não "o atributo é consumido aqui" (não distingue leitura de escrita, código de literal). Uma relação `references_attribute` no índice seria **exata** (como `navigates_explicit_table`/`based_on_domain` já são, com linha + evidência). Conclusão: **(A) é a escolha de engenharia melhor, não só aceitável** — endossada pelo usuário.

**Nota de escopo para o extrator (A) — mapa de formas (sondado em 2026-06-12 sobre `OperacaoItemContaId`):**

| Contexto | Forma da referência | Mecânica de extração |
|---|---|---|
| Procedure / DataSelector / WebPanel | `<Source><![CDATA[ código ]]>` | tokenizar código (já existe para `navigates_explicit_table`) |
| SDT member | `<Item><Property>idBasedOn → Attribute:X</Property>` | XPath estruturado — **reusa máquina do `based_on_domain`** |
| WorkWith coluna | `<attribute attribute="GUID-Nome"/>` | XPath (resolver GUID→nome) |
| WorkWith filtro | `<filterAttribute name="X"/>` | XPath estruturado |
| WorkWith condition | `<condition value="X = &amp;... ">` | XPath + parsear código embutido (XML-escapado) |

Dois aprendizados: (a) parte do extrator **reusa máquina existente** (`idBasedOn` para SDT; tokenizer de Source para código) — custo menor que parecia; cobre **mais que `<Source>`**, mesma lição incremental de `122a171`/`fdb4b3f`. (b) Precisão exige distinguir **atributo nu** de **membro de SDT** (`&sdt.X`) de **variável** (`&X`) de mesmo nome — o que grep não faz e parser faz (reforça (A)).

### Caveat de generalização (para promoção a skill)

Tudo hoje é `FabricaBrasil`-hardcoded (gates K8/K9 delegam a wrappers locais; catálogo de padrões aceitos é específico da KB). O padrão de skill (como `xpz-sync`) é **motor compartilhado em `scripts/` + wrappers locais finos** cujos nomes o README local define; o catálogo de padrões aceitos vira arquivo **por-KB**. Esse é o "passo da promoção" que a `decisao-001`/D1 adiou.

### Sub-casos chave e volume (sondados em 2026-06-12) — confirmam, não abrem regime novo

- **Mudança de chave**: `who-uses(Attribute:OperacaoItemId)` (atributo-chave) = 3, todas estruturais (`has_key_attribute`, `has_index_member_attribute`, `has_level_attribute`). Mesma cegueira de consumo do caso destrutivo + 1 relação estrutural; stakes maiores (rippla a tabelas-filhas via FK e a contratos BC). Regime = **destrutivo amplificado**; build essencial.
- **Procedure com muitos callers**: `who-uses(procParametroDinamicoConteudo)` = **204**, todas `calls_procedure` (relação única). Em volume assim, tabela linear é inviável e não há agregação por `relation_kind` (todas iguais) — revisão manual não escala, **o build é o cheque**. Formato de tabela só importa no regime de **baixo volume** (≤~15-20, onde `Transaction ∪ Table` cabe em sub-tabelas).

### Relação com `decisao-001` (reorientação proposta)

A `decisao-001` adiou o runbook 2b até 2 experimentos (003 Transaction + 004 Procedure >10 callers); 003 existe e o dado de >10 callers agora existe (204 em `procParametroDinamicoConteudo`). Ele **dissolve parcialmente a premissa Q1**: "melhor formato de tabela para 10+ dependentes" importa menos que reconhecer **alto volume = território de build**, baixo volume = território de tabela. O eixo de design central que emergiu desta coleta é **(a)** classificar o regime (aditivo / destrutivo / domínio / chave) + **(b)** melhorar o índice (caminho A, `references_attribute`) — **não** o formato de tabela. Proposta: reorientar o critério de desbloqueio do runbook 2b em torno de (a)+(b).

## Plano A — Implementar relação `references_attribute` no índice KbIntelligence

**Importância:** baixa (rebaixada em 2026-06-12 — ver «Reavaliação» abaixo; a motivação de detecção de regressão ficou largamente coberta por IDE+build)
**Maturidade:** tecnicamente pronta para implementar, mas **gatilho reaberto** — decidir se ainda vale, dado que IDE+build cobrem o caso de regressão (ver «Reavaliação»)

**Origem:** diagnóstico da entrada "Maturar a Fase 2b da rotina pré-push..." (2026-06-12). **Ler aquela entrada primeiro** — contém a evidência (índice cego para consumo de atributo no corpo: `who-uses(Attribute:OperacaoItemContaId)` = 2 estruturais vs ~21 consumidores reais; grep como fallback é ~30% ruidoso e impreciso).

**Para o agente da sessão futura:** frente no repositório de skills (`C:\Dev\Knowledge\GeneXus-XPZ-Skills`), motor compartilhado. **Não** precisa setar a pasta paralela; usar a KB FabricaBrasil só como corpus de validação (consulta de fora, read-only).

### Reavaliação após as probes de 2026-06-12 (wsEducacaoSpTeste)

As 4 probes mostraram que a motivação **original** (detecção de regressão) está largamente coberta **a montante**: **delete** de atributo referenciado é **bloqueado pela IDE**; **rename** é **propagado pela IDE**; **troca de tipo/domínio** (mesmo em PK) é pega pela **Database Impact Analysis / `FailIfReorg`** do build. Logo, usar `who-uses(Attribute:X)` para "impacto de remoção/rename/troca-de-domínio" é, na prática, **redundante com IDE+build**. **Valor remanescente** do `references_attribute`: consultas de **impacto geral** (tornar `who-uses(Attribute)` significativo para exploração/triagem) — um nice-to-have, **não** segurança contra regressão. Decidir se vale implementar à luz disto antes de tratar como "pronta".

### Objetivo

Adicionar ao extrator a relação **`references_attribute`** ("objeto X referencia atributo A no corpo/estrutura"). Hoje o índice modela só as casas estruturais do atributo (`has_level_attribute`, `has_key_attribute`, `has_index_member_attribute`) e `based_on_domain` — não o consumo. Isso torna `who-uses(Attribute:X)` cego ao consumo no corpo — útil para **impacto geral**; para **regressão** de remoção/rename/troca-de-domínio, ver «Reavaliação» (IDE+build cobrem).

### Arquivo e âncoras (estado em 2026-06-12)

`scripts/Build-KbIntelligenceIndex.py`:
- `EXTRACTOR_SIGNATURE_VERSION = "6"` (linha ~42) → **bump para "7"** ao concluir; o bump muda `extractor_signature_version`, e **qualquer edição no `.py` muda o hash SHA-256 dos bytes** (também parte da assinatura). O gate canônico `Test-*KbIndexGate.ps1` **lê a assinatura** (via `GeneXusKbIntelligenceExtractorContract.ps1`) e **bloqueia com `BLOCK:`** quando a metadata do índice diverge do motor (ver `scripts/README-kb-intelligence.md:124-125` e `xpz-kb-parallel-setup/examples/Test-KbIndexGate.example.ps1:122-132`); o que o gate **não** faz é **executar** o rebuild. Logo: **rodar o rebuild explicitamente** após editar o extrator. (A instância local `Test-FabricaBrasilKbIndexGate.ps1` está **defasada** — sem o check de assinatura; wrapper stale, não o contrato canônico.)
- Cada `def extract_*` devolve `list[Evidence]` com `relation_kind` e é registrado; espelhar:
  - **Código em `<Source>`**: `extract_source_for_each_explicit_table_evidence` (~728, `navigates_explicit_table`) — reusar o tokenizador de Source/CDATA.
  - **idBasedOn**: `extract_attribute_idbasedon_domain_evidence` (~1577, `based_on_domain`) + regex `idBasedOn` (~96). O value pode ser `Domain:X` **ou** `Attribute:X` (membro de SDT é `Attribute:OperacaoItemContaId`). Hoje filtra Domain; **estender** para emitir `references_attribute` quando o value for `Attribute:` — quase uma extensão, não código do zero.
  - **WorkWith**: `extract_workwith_condition_evidence` (~1263), `extract_workwith_condition_attribute_evidence` (~1302) — estender/criar para `<attribute attribute="GUID-Nome"/>` (coluna), `<filterAttribute name="X"/>` (filtro), `<condition value="X = &amp;...">` (código XML-escapado).

### Escopo de contextos

Ver a tabela "mapa de formas" na entrada "Maturar a Fase 2b..." (seção "Nota de escopo para o extrator (A)"): Source code (Procedure/DataSelector/WebPanel), SDT idBasedOn, WorkWith coluna/filtro/condition. Cobre **mais que `<Source>`**.

### Precisão exigida

Distinguir **atributo nu** (`OperacaoItemContaId`) de **membro de SDT** (`&sdt.OperacaoItemContaId`) de **variável** (`&OperacaoItemContaId`) de mesmo nome. Só atributo nu (e membro de SDT via idBasedOn) é `references_attribute`. Em `<Source>`, identificador precedido de `&` é variável/SDT-member, não atributo nu — os extratores de Source já fazem essa distinção para navigates/calls; reusar.

### Precedentes (mesma natureza)

`122a171` (Transaction/API/DataSelector em INDEXED_SOURCE_TYPES), `ad69de79` (`WebComponent.Create`), **`fdb4b3f`** (Formula em Attribute — precedente mais próximo: novo extrator + bump de assinatura).

### Validação (caso canônico reproduzível)

Após implementar + rebuild:
- `who-uses(Attribute:OperacaoItemContaId)` deve saltar de **2** para **~21 consumidores** — incluindo `dsRelatoriosDeTitulosViaLancamentos`, `procRelatorioTitulosPor*`, `sdtTituloParametros`, `WorkWithWebOperacaoItem`, `procAtualizaLancamentoItens...` (os mesmos que o grep textual achou e o índice não).
- Conferir que **variável** homônima **não** gera falso positivo.
- O gate canônico **bloqueia** (`BLOCK:`) quando a assinatura do índice diverge do motor, mas **não executa** o rebuild — rodar o rebuild **explicitamente** (`Rebuild-...KbIntelligenceIndex.ps1`) após editar o extrator.

### Decisões fechadas / não fazer

- **Não** usar grep como solução (caminho B descartado).
- `references_attribute` é **aditiva** — não quebrar relações existentes.
- Rodar a rotina pré-push do repo de skills (`13`/`14`) antes de push; paridade doc: `02`, `08`, `09`, `scripts/README-kb-intelligence.md`, `kb-intelligence-guia-metodologico-agente.md` e skills que citam o extrator; entrada no `historico/IdeiasImplementadas_YYYYMM.md` ao mover esta entrada do `999`.

## Plano B — Promover a `pre-push-routine` a skill `xpz-kb-parallel-pre-push` — IMPLEMENTADO E MIGRADO

> Implementado e migrado para `historico/IdeiasImplementadas_202606.md` em 2026-06-15. Lado-repo: skill `xpz-kb-parallel-pre-push` (Fase 1 mecânica + Blocos A/C/D–G), PUSHADO. Lado pasta paralela (Bloco H): adendo de superação na `decisao-001` do experimento da FabricaBrasil + registro global via `xpz-skills-setup`; a `kb-parallel-pre-push.config.json` é dispensável na FabricaBrasil (wrappers locais resolvidos por convenção). A entrada-diagnóstico «Maturar a Fase 2b…» permanece **aberta** acima como direção de pesquisa independente.

## Formalizar o ciclo «Revisão por Pares» (validação de plano por painel multi-modelo) — IMPLEMENTADO E MIGRADO

> Implementado e migrado para `historico/IdeiasImplementadas_202606.md` em 2026-06-17. Estrutura **C pura**: `15-revisao-por-pares.md` (metodologia genérica, fonte normativa da régua) + `14` como aplicação pré-push + motor `scripts/Build-LlmDelegateCapabilityManifest.ps1` e gatilho de revisão por pares na `xpz-llm-delegate`. Decisões em aberto resolvidas (C pura; manifesto sanitizado dica-de-oferta-nunca-verdade-do-gate; livro-razão opcional em `Temp/`; ponto de autorização = autor classifica + gate por revisor). Resíduos seguem **abertos** como futuros: harness de disparo do painel, backends one-shot (`llm`/`mods`) e personas de revisão.

## Exceção "relay auditável" na oferta de 2ª rodada de revisão por pares (otimização do D2)

**Importância:** baixa (é otimização de custo; o caminho seguro já está adotado e cobre a correção)
**Maturidade:** ideia (a decisão de design foi adiar; a mecânica do marcador auditável fica em aberto)

**Origem:** frente dos 4 achados da revisão por pares, decisão D2, 2026-06-19. Ao sintetizar os pareceres do painel, o agente produz uma versão consolidada do manuscrito (vN+1). A régua atual (`15-revisao-por-pares.md:40`) trata qualquer vN+1 ainda não revisada como **convergência falsa** — exige re-submissão ao painel. O D2 perguntou qual o gatilho da oferta proativa de 2ª rodada no momento da síntese.

**Decisão tomada (opção 1, adotada agora):** *qualquer vN+1 autorada ⇒ oferecer 2ª rodada*. Painel: opção 1 (claude-opus + Codex) venceu opção 2 (minimax + autor); Codex desempatou. Motivo: não afrouxa o `15:40` e não reintroduz julgamento auto-interessado do agente no ponto vulnerável (declarar convergência).

**O que esta frente futura faria (a otimização adiada):** introduzir uma exceção em que uma vN+1 de **mero relay** (só agrupa/numera/marca convergência, sem acrescentar nada) **dispensa** a re-submissão, separando-a de uma **consolidação autoral** (que acrescenta afirmação que nenhum revisor escreveu, reordena divergências ou resolve conflito entre ressalvas). Requisitos para ser segura, **não** atendidos hoje:

- **emendar `15-revisao-por-pares.md:40`** para reconhecer a categoria `relay` (hoje a régua não tem exceção);
- **marcador auditável no recibo** (`vN+1Type=relay|authoredConsolidation`), nunca auto-certificado em silêncio;
- **checklist objetivo** (proposta do minimax) — a vN+1 exige 2ª rodada se QUALQUER for "sim": (1) inclui afirmação que nenhum revisor escreveu textualmente? (2) prioriza/ordena divergências de um modo que não estava no painel? (3) resolve um conflito entre ressalvas? (senão: só estrutura/agrupa = relay → dispensa);
- evidência comparável de que a vN+1 não introduziu afirmação, ordenação, resolução de conflito nem prioridade nova.

**Risco a vigiar se for implementada:** a linha relay-vs-consolidação é fácil de o próprio agente racionalizar a seu favor para pular a rodada custosa — exatamente o autoengano que o método quer evitar. Só vale a pena com o marcador auditável e a emenda da norma juntos.

**Rascunho da emenda ao `15:40`** (para a entrada ser auto-suficiente; texto-semente, a refinar quando a frente abrir):

> *Exceção (relay auditável):* uma vN+1 classificada como `relay` — que **apenas** agrupa, numera ou marca convergência, **sem** introduzir afirmação que nenhum revisor escreveu, reordenação de divergências, resolução de conflito entre ressalvas ou priorização ausente do painel — **dispensa** a re-submissão, desde que o recibo registre `vN+1Type=relay` e a classificação seja auditável pelo checklist abaixo. Qualquer vN+1 que falhe uma das perguntas é `authoredConsolidation` e **exige** re-submissão. Na dúvida, `authoredConsolidation`.

**Checklist objetivo** (a vN+1 exige 2ª rodada se QUALQUER for "sim"): (1) inclui afirmação que nenhum revisor escreveu textualmente? (2) prioriza/ordena divergências de um modo que não estava no painel? (3) resolve um conflito entre ressalvas (escolhe um caminho)? — senão, só estrutura/agrupa = `relay` → dispensa.

**Exemplo do marcador no recibo:**

```json
{ "vN+1Type": "relay", "roundId": "<id>", "checklist": { "newClaim": false, "reordered": false, "resolvedConflict": false }, "classifiedBy": "human" }
```

**Relacionado:** `15-revisao-por-pares.md` (régua `:40`); `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1` (onde o estado de re-submissão da vN+1 será mecanizado no Achado A); frente dos 4 achados da revisão por pares.

## Escolha de escopo do painel na revisão por pares (o agente não encolhe o painel sozinho)

**Importância:** média (gap real de metodologia; causou incidente em 2026-06-20 — gap de paridade trilíngue do CHANGELOG quase foi ao push)
**Maturidade:** plano refinado por painel de 6 modelos / 3 famílias (todos «aprovado com ressalvas»); vN+1 consolidada pendente de re-submissão

**Origem:** incidente 2026-06-20. Em pré-push reforçada com `preferred-reviewers.json` de 6 revisores, o agente despachou 2 (piso de 2 famílias), viu «0 gaps até aqui» e PAROU por decisão própria. O usuário mandou consultar os 4 restantes; o único gap real só apareceu no 6º revisor. Parar no piso teria mandado o gap ao push. Causa raiz (catch do minimax): terminação por **convergência intermediária** — 3ª regra implícita que nem o `14`/`15` vedavam.

**O que a frente faria (doc + motor; NÃO é doc-only):**
1. Vedar textualmente a terminação por convergência intermediária: painel só termina em (a) 1º gap *após* o piso atingido, (b) fim do escopo escolhido, (c) falha de comunicação.
2. Usuário decide o escopo: com lista preferida, o agente apresenta composição + opções (inteira / subconjunto / ad-hoc) + custo estimado; recomenda, não decide. Pergunta **depois** dos gates mecânico+semântico e após resolver `ask`/`allow`.
3. Default não-bloqueante = lista inteira (silêncio → inteira, registrado `scopeSource`); nunca cair ao piso.
4. Subconjunto deve manter ≥2 famílias; abaixo disso rebaixa o rótulo para «segunda opinião (N)». Ad-hoc não conta para diversidade nem dispensa o gate de autorização por destino.
5. Dono normativo no `15` (composição do painel); aplicação pré-push no `14`.
6. Recibo/motor `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1`: campos `scopeDecision`/`scopeSource`/`deviationReason` + enum de estado por preferido (`responded`|`skippedByUserScope`|`skippedByGapStop`|`notReached`|`failedCommunication`|`unavailable`).
7. `defaultScope` opcional em `preferred-reviewers.json` (`full`|`minimumValid`|`manual`) com guarda anti-erosão.
8. Paridade `02`/`08`/`09`/`README`/`xpz-llm-delegate/SKILL.md` + CHANGELOG trilíngue.

**Painel consultado (plano):** Codex (gpt-5.5) + deepseek-v4-pro + kimi-k2.7-code + glm-5.2 + minimax-m3 + síntese Anthropic. RoundId `plan-panel-scope-2026-06-20`; `vNextState=pendingResubmission`.

**Parcialmente implementado (2026-06-20):** a proibição de **enquadrar custo/latência do painel** para reduzi-lo a subconjunto (a faceta de viés de enquadramento) foi gravada como regra no `xpz-llm-delegate/SKILL.md` (reforço do Achado B); o restante do mecanismo de escolha de escopo (apresentar opções e deixar o usuário decidir, default = lista inteira, recibo de escopo) segue **aberto**.

**Relacionado:** `14-revisao-pre-push-reforcada.md`, `15-revisao-por-pares.md`, `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1`; exceção «relay auditável» acima (otimização distinta da mesma régua); correção do commit `f35bbe5` que motivou.

## Detecção de truncamento fora do opencode (paridade dos adapters stdin/JSONL)

**Importância:** baixa-média (rede de segurança; o vazamento crítico já está fechado)
**Maturidade:** pesquisa feita (varredura estática concluída; falta teste empírico + eventual código)

**Origem:** frente dos 4 achados da revisão por pares, Achado D / G1-R, 2026-06-20. O D-fix da Fase 1 detecta truncamento (`reason` do `step_finish`) **só no opencode**. A varredura confirmatória dos demais adapters (inspeção **estática** do código em 2026-06-20) concluiu: o **vazamento-do-D** (preâmbulo virar parecer) **não se reproduz** em Codex/Claude Code/Gemini/Copilot — todos entregam a mensagem final canônica (campo terminal nomeado; Copilot por last-wins de stream). **Mas** nenhum dos quatro detecta **truncamento por limite de tokens** (não há equivalente a `reason=length`).

**O que esta frente futura faria:**

- **Plano de teste empírico** (a varredura foi estática, não ao vivo): injetar resposta longa que force corte por limite em cada adapter não-opencode e verificar se a extração devolve parcial como se fosse completo; definir critério pass/fail e registrar versões das ferramentas.
- **Risco residual do last-wins do Copilot:** se o agente reescrever a resposta e a "última" `assistant.message` não for a final canônica, a extração pode errar. Confirmar empiricamente e, se real, ancorar a extração num sinal mais forte.
- **Eventual paridade de detecção:** se algum adapter expuser sinal de término, aplicar verdito análogo ao `Get-OpenCodeCompletionVerdict`; senão, declarar contrato explícito "sem sinal de completude disponível; risco aceito/mitigado por X".

**Relacionado:** `xpz-llm-delegate/SKILL.md` (seção «Detecção de truncamento (Achado D)», cobertura por adapter); `scripts/Invoke-Codex.ps1`, `scripts/Invoke-ClaudeCode.ps1`, `scripts/Invoke-Gemini.ps1`, `scripts/Invoke-Copilot.ps1`, `scripts/CopilotCliSupport.ps1`; frente dos 4 achados da revisão por pares.

## Normalizar a caixa do -VNextState no eco do closeout

**Importância:** muito baixa (cosmético; a lógica do gate já está correta)
**Maturidade:** ideia

**Origem:** frente dos 4 achados, revisão do diff (minimax), 2026-06-20. O `ValidateSet` do `-VNextState` em `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1` é **case-insensitive** (default do PowerShell), então `-VNextState NOTPRODUCED` é aceito. O **gate funciona em qualquer caixa** (o `-eq` do PowerShell também é case-insensitive, então os bloqueios disparam corretamente); o único efeito é o campo `vNextState` no objeto/`receiptAddendum` ecoar a caixa que o chamador passou, em vez da forma canônica.

**O que esta frente faria:** normalizar `$VNextState` para a forma canônica (`notProduced`/`pendingResubmission`/`resubmitted`/`resubmissionDeclinedByHuman`) antes de ecoar/emitir, para um consumidor downstream que faça comparação case-sensitive do JSON não tropeçar. Risco prático hoje ~nulo (o ecossistema é PowerShell, case-insensitive).

**Relacionado:** `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1`; frente dos 4 achados da revisão por pares.

## Unificar build sob fundação desacoplada (janela vira visualizador plugado)

**Importância:** média
**Maturidade:** pesquisa feita

**Origem:** frente do modo desacoplado de build (`Start-GeneXusKbBuildDetached.ps1`), 2026-06-12. Decisão (b) do usuário: janela visível continua o default; desacoplado é opt-in. Durante a frente, o usuário perguntou se a janela default ganharia proteção contra fechamento acidental — e ela **não** ganha: o paliativo de título/aviso `NÃO FECHAR` em `Watch-GeneXusMsBuildLog.ps1` reduz o acidente humano, mas não impede o fechamento.

### Problema concreto que motiva a ideia

O fluxo de janela visível (default) continua acoplado à console/sessão do agente: fechar a janela ainda derruba wrapper + MSBuild + GeneXus. A frente cobriu o build longo (modo desacoplado opt-in via Tarefa Agendada), mas o default segue tecnicamente frágil para builds curtos.

### Direção técnica proposta

Tornar **todo** build sempre desacoplado por baixo (fundação `Start-GeneXusKbBuildDetached.ps1`), e a janela visível passar a ser apenas um **visualizador** (`Watch-GeneXusMsBuildLog.ps1` lendo `msbuild.stdout.log` + sentinela). Fechar a janela perderia só a visão, nunca o build; reabrir um visualizador reconectaria.

### Por que **não** foi feito agora

Custo: pôr o mecanismo desacoplado (Tarefa Agendada) no caminho mais usado da skill — ainda não comprovado em uso real — arrisca regredir o build comum, hoje confiável; e paga overhead de registro/limpeza de tarefa em todo build, inclusive curtos. Decisão consciente do usuário: introduzir só **depois** que o desacoplado provar valor no uso real, quando deixa de ser código novo no caminho crítico e vira promoção segura.

### Decisões em aberto

- Overhead real da Tarefa Agendada em builds curtos desta skill (medir).
- Fallback quando o registro da tarefa falhar em algum ambiente (voltar à janela acoplada atual?).
- Política/elevação do Task Scheduler no caminho comum.

## Estender o modo desacoplado opt-in ao import real longo

**Importância:** baixa
**Maturidade:** ideia

**Origem:** mesma frente, 2026-06-12. O modo desacoplado foi restrito a `xpz-msbuild-build` (`BuildAll`/`SpecifyGenerate`) por escopo. O import real (`Invoke-GeneXusXpzImport.ps1`) também pode ser longo e tem gate de watcher visível — mais estrito: na **Decisão pós-gates** é obrigatório, sem exceção por justificativa.

### Direção técnica proposta

Avaliar um orquestrador análogo (ou generalizar `Start-GeneXusKbBuildDetached.ps1`) para import real longo, preservando o gate de import — "monitoramento legível obrigatório — janela **ou** sentinela" — sem afrouxar a barragem da Decisão pós-gates.

### Decisões em aberto

- Generalizar o orquestrador existente ou criar um por trilha.
- Como o gate mais estrito da Decisão pós-gates interage com o monitoramento por sentinela.

## Eliminar globalmente o uso de `-AsJson`

**Importância:** média
**Maturidade:** ideia

**Origem:** fechamento da frente de padronização JSON nos wrappers XPZ de pacote, 2026-06-06. A frente já removeu `-AsJson` dos scripts compartilhados de empacotamento, inventário, sanidade e wrappers locais derivados, mas deixou scripts fora dessa frente com contrato humano/JSON próprio.

### Problema concreto que motiva a ideia

O contrato misto `texto humano por padrão` versus `JSON com -AsJson` ainda existe em outros scripts públicos da base. Mesmo que esses scripts não façam parte da frente de empacotamento, a existência de dois padrões mantém risco operacional para agentes:

- tentativa-erro de flag em scripts diferentes;
- parse frágil quando um wrapper espera JSON e outro ainda alterna formato;
- documentação e exemplos precisando explicar exceções;
- chance de wrappers locais em pastas paralelas perpetuarem contratos antigos.

### Ideia de melhoria

Fazer uma frente separada para inventariar todos os `-AsJson` restantes e decidir, script a script, o novo contrato:

1. scripts de motor/automação devem emitir JSON de máquina por padrão no stdout e remover `-AsJson`;
2. scripts que ainda precisem de saída humana devem usar outro contrato explícito, por exemplo `-HumanReadable`, ou ter wrapper humano separado;
3. chamadas internas, exemplos `.example.ps1`, skills e documentos devem ser atualizados juntos;
4. pastas paralelas devem receber wrappers atualizados por `xpz-kb-parallel-setup`, sem promessa de compatibilidade com wrappers locais antigos.

### Decisões em aberto

- Se algum script deve manter saída humana como contrato primário.
- Se `-HumanReadable` vale a complexidade ou se JSON sempre é suficiente.
- Ordem de migração para scripts MSBuild, gates de setup, diagnósticos de runtime e helpers de edição XML.

## LlamaIndex / LangChain + vector store como alternativa ao indice SQLite atual

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** sugestao recebida em 2026-04-25 para exploracao futura.

### Problema concreto que motiva a ideia

Hoje o usuario GeneXus que trabalha com a pasta paralela via agente e obrigado a informar o nome exato do objeto que quer consultar. O custo de um agente varrer ate 15 mil arquivos XML do acervo em `ObjetosDaKbEmXml` sem um nome preciso e proibitivo — em tokens e em tempo. O indice SQLite mitiga isso com triagem estrutural, mas a busca continua dependendo de nome exato ou tipo conhecido.

O efeito pratico: o usuario que nao lembra o nome do objeto nao consegue explorar a KB de forma fluida; precisa saber o que procura antes de perguntar.

### Framework de orquestracao: LlamaIndex ou LangChain

Ambos resolvem o mesmo problema e suportam os mesmos vector stores (ChromaDB, Redis Stack). A escolha e de preferencia de ecossistema:

- **LlamaIndex**: especializado em indexacao e recuperacao de dados; API mais direta para RAG puro; escolha natural quando o unico objetivo e "indexar e buscar".
- **LangChain**: framework mais abrangente (agentes, chains, memoria, ferramentas, RAG); comunidade maior; util se o mesmo framework ja for usado em outras partes do projeto.

Para o caso especifico de indexar XMLs GeneXus e buscar por intencao funcional, ambos chegam no mesmo resultado.

### O que a camada vetorial resolveria

**Busca por intencao funcional**
Com embeddings vetoriais, uma pergunta como "qual procedure atualiza o saldo de estoque mensal?" localizaria o objeto correto mesmo sem o nome exato. O usuario descreveria o que precisa em linguagem natural e o agente encontraria os candidatos relevantes — invertendo a dependencia atual de nomenclatura precisa.

**Contexto recortado (chunking)**
Cada XML de objeto GeneXus pode ser extenso. Em vez de enviar o XML inteiro ao agente, o framework fatiaria em blocos logicos (`Source`, `Rules`, `Events`). A resposta usaria apenas os trechos realmente relevantes, reduzindo tokens e ruido.

**Custo de busca constante**
O vector store organiza vetores matematicamente. O custo de busca nao degrada com o crescimento do acervo.

### Opcoes de vector store

**ChromaDB**
Proposito unico, simples de instalar, disk-first por padrao. Boa opcao para comecar.

**Redis Stack**
Redis com modulo de busca vetorial (RediSearch / HNSW). Open source e gratuito. Nao tem versao nativa para Windows, mas roda sem custo via WSL2 ou Docker Desktop — ambos gratuitos e funcionais no Windows 11 Pro. Com 32 GB de RAM, o custo de memoria e irrelevante: os 15 mil XMLs da KB grande ocupam 180 MB em disco; os embeddings correspondentes ficam estimados em 200-300 MB de vetores (modelo de 1536 dimensoes, ~2,5 chunks por objeto). Redis tem vantagem em velocidade bruta por ser in-memory, e o LlamaIndex ja o suporta como backend nativo.

### Perguntas a responder antes de decidir

- Qual o custo de geracao dos embeddings para o acervo? Precisa de API externa ou modelo local funciona com qualidade suficiente?
- O ganho de descoberta por intencao compensa a complexidade de manter dois indices (SQLite estrutural + vetorial)?
- Adotar LlamaIndex/LangChain + vector store exigiria reescrever os wrappers locais (`Query-*KbIntelligence.ps1`, gate, etc.) em todas as pastas paralelas?
- O chunking por bloco logico do XML (`Source`, `Rules`, `Events`) e viavel dado o formato dos XMLs GeneXus?

## Baseline conhecido no sanity e na revisao de objeto legado

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** ideia discutida em 2026-04-29 e adiada para frente separada.

### Problema concreto que motiva a ideia

Hoje a trilha distingue bem `xmlWellFormed`, `sourceSanityStatus` e os gates minimos de `Source`, mas ainda nao expressa de forma curta e operacional a comparacao entre um delta novo e o XML oficial ja aceito do mesmo objeto.

Em objeto legado grande, isso gera ruido de decisao:

- warning antigo do baseline oficial pode ser lido como defeito novo do delta
- piora nova pode passar despercebida sob o argumento de que "o objeto ja era ruim"
- o agente pode misturar sanidade absoluta do XML com comparacao relativa contra o estado oficial anterior

### Ideia de melhoria

Adicionar, em frente separada, uma camada comparativa explicita e distinta do sanity absoluto, com saidas como:

- `same as official baseline`
- `worse than official baseline`
- `better than official baseline`
- `no official baseline compared`

Essa camada nao substituiria `xmlWellFormed`, `sourceSanityStatus` nem os gates metodologicos atuais. Ela serviria para comparar o delta com o baseline oficial quando houver XML oficial comparavel do mesmo objeto.

### Perguntas a responder antes de decidir

- O que exatamente conta como `official baseline` em cada fluxo: XML oficial atual em `ObjetosDaKbEmXml`, ultimo delta aceito, ou outro marco explicitamente documentado?
- A comparacao deve nascer primeiro como regra metodologica de handoff/revisao, ou ja como evolucao automatizada do `Test-GeneXusSourceSanity.ps1`?
- Como impedir que baseline ruim vire permissao implicita para aceitar piora nova?

## Rename de `kb-source-metadata.md` para `kb-parallel-state.md`

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliacao de resultado de setup em 2026-05-03.

### Problema concreto que motiva a ideia

O arquivo `kb-source-metadata.md` acumula tres responsabilidades distintas: dados de envelope de importacao (blocos `KMW` e `Source` extraidos do XPZ), timestamps operacionais de materializacao (`last_xpz_materialization_run_at`) e, com a adicao de `last_setup_audit_run_at`, timestamps de auditoria de setup. O nome atual descreve apenas a primeira responsabilidade e induz leitura incorreta da funcao real do arquivo.

Nome proposto: `kb-parallel-state.md` — descreve o estado corrente da pasta paralela como um todo, independente de qual dado especifico estiver armazenado.

### Impacto do rename

Alto. O nome atual esta hardcoded em praticamente todos os wrappers locais de cada pasta paralela (`Update-*KbFromXpz.ps1`, `Get-*KbMetadata.ps1`, `Test-*KbIndexGate.ps1`, `Test-*KbStructure.ps1`) e nos scripts do motor compartilhado (`Sync-GeneXusXpzToXml.ps1`, `Test-XpzKbMetadataWrapper.ps1` e outros). Um rename exige atualizar o motor compartilhado, todos os exemplos sanitizados da skill e cada wrapper local de cada pasta paralela existente.

### O que justificaria implementar agora vs. aguardar

Aguardar ate que haja uma frente de refatoracao maior no motor compartilhado ou nos exemplos sanitizados que justifique o custo de migracao em cascata. Nao implementar de forma isolada so por higiene de nomenclatura.

### Perguntas a responder antes de decidir

- Ha outras renomeclaturas de campo ou arquivo pendentes que pudessem ser agrupadas na mesma frente de migracao para amortizar o custo?
- O rename deve ser feito com compatibilidade retroativa (suporte temporario aos dois nomes) ou como corte limpo?

## Tríade de diagnóstico de schema: WriteDatabaseSchema + WriteKnowledgeBaseSchema + CompareSchemas

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de inventário de tasks MSBuild — domínio Database, 2026-05-06.

### Problema concreto que motiva a ideia

Quando uma KB apresenta reorgs inesperadas, erros de impacto ou comportamento anômalo após migração, o desenvolvedor precisa entender se o banco físico está em sincronia com o modelo definido pela KB. Hoje esse diagnóstico depende da IDE. As três tasks permitem fazer essa análise headless, gerando XMLs comparáveis e um arquivo de diferenças.

### Confirmação técnica

Todas as três confirmadas por reflexão do assembly e documentadas em `3908.html`:

- `WriteDatabaseSchema`: lê o banco físico real (via conexão do Environment) e grava um XML com o schema atual. Parâmetro obrigatório: `File` (String).
- `WriteKnowledgeBaseSchema`: lê o modelo da KB (sem acessar o banco) e grava um XML com o schema esperado. Parâmetros: `File` (obrigatório), `DesignModel` (Boolean — `true` = modelo de design, `false` = modelo alvo, default `false`), `SortByName` (Boolean, default `false`).
- `CompareSchemas`: compara os dois XMLs e grava as diferenças. Parâmetros: `DBFile` (obrigatório), `KBFile` (obrigatório), `DiffFile` (opcional — arquivo de saída das diferenças).

`CompareSchemas` **não exige KB aberta** — opera sobre arquivos já gerados. `WriteDatabaseSchema` e `WriteKnowledgeBaseSchema` exigem KB aberta.

### Distinção operacional importante

`WriteDatabaseSchema` conecta ao banco físico (SQL Server, LocalDB). Pode falhar se a conexão não estiver disponível no contexto headless — risco diferente de `WriteKnowledgeBaseSchema`, que opera apenas sobre o modelo da KB. Implementar os dois de forma independente, não acoplada.

### Enquadramento correto de uso

Não é um gate pré-import. Import trata de objetos GeneXus; o schema do banco é alterado por Reorg. O caso de uso real é diagnóstico de estado: "por que minha reorg falhou?", "o banco está alinhado com o que a KB espera?", "qual o impacto de uma migração recente no schema físico?"

### Perguntas a responder antes de decidir

- Um único script combinado (`Test-GeneXusSchemaSync.ps1`) que executa as três etapas em sequência é melhor do que três scripts separados?
- Onde esse script deve ficar: nova skill `xpz-msbuild-db`, ou adicionado como diagnóstico complementar na `xpz-msbuild-build`?
- `WriteDatabaseSchema` exige que o Environment tenha uma conexão de banco válida e acessível no contexto headless? Isso precisa de teste empírico.
- O `DiffFile` de `CompareSchemas` tem formato legível diretamente, ou exige parsing para ser útil ao usuário?

### Limiar para implementar

Implementar quando houver caso concreto de diagnóstico de drift DB-KB que a IDE não consiga resolver de forma conveniente, ou quando o fluxo de `Invoke-GeneXusDbImpact.ps1` precisar de contexto de schema para interpretar o script de impacto gerado.

## DeleteObject — limpeza headless pós-import

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

A skill `xpz-msbuild-import-export` documenta explicitamente no bloco `WWP IMPORT ORDER` que `import_file` não remove objetos antigos automaticamente. A limpeza de Transactions antigas substituídas, SubtypeGroups obsoletos, PatternInstances antigas e Procedures/WebPanels gerados automaticamente é feita hoje de forma manual na IDE.

`DeleteObject` é a task MSBuild oficial que remove objetos da KB. Parâmetros documentados: `Objects` (obrigatório), `IncludeChildren` (true/false, para pastas e módulos), `FailWhenNone` (true/false). Não requer GeneXus Server e não pressupõe estrutura de Team Development.

### Posicionamento

Candidato prioritário entre as tasks do domínio de versionamento. Fecha gap concreto e documentado no fluxo atual da skill, sem exigir nova skill — caberia como extensão de `xpz-msbuild-import-export`.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.DeleteObject` está exposta no assembly `Genexus.MsBuild.Tasks.dll` com as propriedades documentadas (`Objects`, `IncludeChildren`, `FailWhenNone`)
- Definir gate de segurança alto: confirmação nominal por objeto (ou lista) + declaração explícita ao usuário de que não há rollback automático
- Avaliar se o usuário fornece a lista de objetos explicitamente ou se há mecanismo auxiliar para derivá-la (por comparação entre estado pré e pós-import)

### Perguntas a responder antes de decidir

- `Objects` aceita lista separada por vírgula no mesmo formato de `Export`/`Import`, ou tem sintaxe própria?
- `IncludeChildren` é seguro como default `false` ou deve ser proibido sem confirmação explícita adicional?
- O gate deve exigir confirmação por objeto individualmente ou basta confirmação da lista completa?

## CreateVersion — snapshot pré-import de baixo risco

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

Antes de uma importação de XPZ arriscada, criar uma versão frozen da KB serve como ponto de restauração. `CreateVersion` cria uma versão frozen a partir da versão ativa ou especificada. Parâmetros documentados: `VersionName` (obrigatório), `VersionDescription` (opcional), `Parent` (nome da versão pai; `*Trunk` ou nome da KB para raiz). Operação não-destrutiva: apenas cria, não altera nem remove nada.

A alternativa existente para o mesmo problema — cópia da pasta da KB (LocalDB) ou backup `.bak` via SQL Server — não exige task MSBuild, mas também não deixa rastreabilidade dentro da própria KB.

### Condições antes de implementar

- Verificar empiricamente se `CreateVersion` está exposta no assembly com os parâmetros documentados
- Avaliar se o público-alvo da skill usa estrutura de múltiplas versões — em KB local simples sem Team Development, criar versões frozen antes de cada import pode ser overhead sem benefício claro
- Se o public-alvo não usa versões, documentar `CreateVersion` como capacidade disponível mas não recomendar como passo padrão do fluxo

### Relacionamento com RevertToVersion

`CreateVersion` sozinha é de baixo risco. `RevertToVersion` como par de rollback é avaliada separadamente abaixo e depende de análise de perfil de versões da KB.

### Perguntas a responder antes de decidir

- O público-alvo desta skill usa estrutura de múltiplas versões de desenvolvimento (Team Development) ou KB local com versão única (Root)?
- `CreateVersion` com `Parent=*Trunk` cria versão diretamente de Root sem abrir fluxo de merge?

## RevertToVersion — rollback de snapshot, gate muito restritivo

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

Par com `CreateVersion` para o fluxo snapshot+rollback: se o import deu errado, reverter para a versão frozen criada antes. Parâmetro: `VersionName` (obrigatório).

### Risco crítico que bloqueia implementação imediata

A documentação oficial é explícita: `RevertToVersion` **sobrescreve a versão Root com a versão especificada**. Qualquer alteração feita na versão Root após o snapshot é perdida permanentemente. Isso é mais destrutivo que uma importação mal-sucedida.

Consequência para o fluxo XPZ: se o import foi feito diretamente na Root (cenário mais comum em KB local), `RevertToVersion` desfaz o import — mas também desfaz todo e qualquer outro trabalho feito na Root desde o snapshot. Se o import foi feito em versão de teste separada, `RevertToVersion` não desfaz aquela versão de teste — afeta Root.

### Condições antes de implementar

- Dependente de `CreateVersion` estar implementada e em uso real
- Dependente de evidência de que o público-alvo usa múltiplas versões com Root claramente separada do fluxo de trabalho cotidiano
- Gate precisa ser mais restritivo que os gates atuais de importação real: confirmação explícita + listagem das alterações que serão perdidas, se houver mecanismo para derivá-las
- Verificar empiricamente a task no assembly antes de qualquer implementação

### Perguntas a responder antes de decidir

- Há mecanismo headless para listar diferenças entre a versão Root atual e a versão frozen antes de executar o revert?
- O fluxo snapshot+rollback é mais seguro do que a alternativa já documentada (cópia da pasta da KB)?

## RestoreRevision — desfazer cirúrgico por objeto

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

`RestoreRevision` restaura um objeto específico para uma revisão específica de sua história. Parâmetros: `Object` (formato `"ObjectType:ObjectName"`), `RevisionId`. Mais cirúrgico que `RevertToVersion`: desfaz apenas o objeto indicado, sem afetar o restante da KB.

### Bloqueio atual

Para usar `RestoreRevision` é necessário saber o `RevisionId` concreto do estado anterior desejado. Não há task headless documentada para listar o histórico de revisões de um objeto. Sem esse mecanismo, o fluxo não é autônomo: o usuário precisaria obter o `RevisionId` manualmente pela IDE antes de invocar o wrapper.

### Condições antes de implementar

- Identificar task ou mecanismo headless que permita listar revisões de um objeto e seus IDs
- Sem esse mecanismo, `RestoreRevision` só seria utilizável como wrapper de conveniência para `RevisionId` já conhecido pelo usuário

### Perguntas a responder antes de decidir

- Existe task headless que liste o histórico de revisões de um objeto GeneXus?
- Se não houver, faz sentido implementar o wrapper mesmo exigindo que o usuário forneça o `RevisionId` explicitamente?

## Leitura da wiki 24612 (Team Development MSBuild Tasks)

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Motivação

A documentação offline instalada do GeneXus 18 indexa as tasks MSBuild em `3908.html`. O agente externo identificou que a wiki oficial tem página dedicada ao domínio Team Development (`id=24612`) com potencialmente mais tasks que as listadas no índice local.

As tasks avaliadas nesta frente (`CreateVersion`, `RevertToVersion`, `MergeVersions`, `RestoreRevision`, `DeleteObject`) foram analisadas com base nas informações disponíveis no prompt externo. A leitura da wiki 24612 pode revelar tasks adicionais, parâmetros não documentados na instalação local ou restrições de uso não identificadas até agora.

### Condições

- Pesquisa de inventário — não bloqueante para as decisões registradas acima
- Útil antes de qualquer implementação concreta de task deste domínio
- Não requer GeneXus Server: a wiki documenta também o uso local das tasks

### O que buscar na wiki 24612

- Tasks não listadas em `3908.html`
- Parâmetros adicionais de `CreateVersion`, `RevertToVersion`, `MergeVersions`, `RestoreRevision` e `DeleteObject`
- Restrições ou pré-condições de uso das tasks em contexto sem GeneXus Server
- Mecanismo de listagem de revisões de objetos (necessário para `RestoreRevision`)

## RestoreModule — pré-requisito de build para KBs com dependências de módulo

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Documentação oficial confirmada em `46830.html` da instalação local. Task registrada em
`Genexus.Tasks.targets` e mapeada para `Genexus.MsBuild.Tasks.dll`.

### Problema concreto que motiva a ideia

A skill `xpz-msbuild-build` não trata o caso em que a KB tem módulos instalados (AWSCore,
AzureCore, etc.) e esses módulos precisam estar restaurados antes de o build ter sucesso. Sem
`RestoreModule`, o build falha com erro de referência não resolvida — mas o erro parece ser
do XPZ importado, não da ausência de módulo. O agente pode diagnosticar incorretamente a causa.

`RestoreModule` sem parâmetro `ModuleName` restaura a implementação de todos os módulos instalados
na KB a partir do cache local (`%USERPROFILE%\.gxmodules\.cache\`). É o equivalente de `npm install`
antes de `npm build`. Não requer GeneXus Server — funciona com o cache já populado pela IDE
ou pela instalação do GeneXus (servidor `Local`).

### Parâmetros documentados

- `ModuleName` (string, opcional): nome do módulo a restaurar. Se omitido, restaura todos.

### O que justificaria implementar agora vs. aguardar

Implementar quando houver KB concreta com módulos instalados no portfólio onde o build headless
falhe por ausência de restauração. O gate de adição ao pipeline da `xpz-msbuild-build` seria:
verificar antes do build se a KB tem módulos instalados e, em caso afirmativo, executar
`RestoreModule` automaticamente como etapa anterior ao `BuildAll`.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.RestoreModule` expõe `ModuleName` como
  propriedade pública no assembly desta instalação
- Confirmar que `RestoreModule` sem parâmetro opera sobre módulos referenciados pela KB aberta,
  não sobre o cache global
- Definir se deve ser etapa automática do pipeline ou gate explícito com confirmação do usuário

### Perguntas a responder antes de decidir

- `RestoreModule` sem `ModuleName` já é idempotente (não falha se não há módulos)? Ou exige
  que haja ao menos um módulo instalado?
- O cache `%USERPROFILE%\.gxmodules\.cache\` já existe numa instalação limpa com módulos
  instalados pela IDE? Ou precisa de pré-aquecimento headless?
- Qual o comportamento quando o servidor de origem do módulo não está acessível? `RestoreModule`
  falha ou usa o cache existente?

## InstallModule / UpdateModule / GetModulesServer / AddModulesServer — gestão de dependências headless

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Documentação oficial confirmada em `46830.html` e `45933.html` da instalação local. Tasks
registradas em `Genexus.Tasks.targets`.

### Contexto

Módulos GeneXus não requerem GeneXus Server. Funcionam com três tipos de servidor:

- `Directory` — pasta local no sistema de arquivos (sem servidor de rede)
- `Nexus-Maven` / `Nexus-NuGet` — repositórios Maven ou NuGet genéricos (Nexus OSS)
- Servidores pré-configurados: `Local` (módulos da instalação GeneXus) e `Global Matrix`
  (repositório público da GeneXus, visível na IDE em "Manage Module References")

### O que cada task faz

- `InstallModule(ModuleName, Version?)` — instala módulo do servidor configurado na KB aberta
- `UpdateModule(ModuleName, Version?)` — atualiza módulo instalado para versão especificada
  ou mais recente
- `GetModulesServer` — lista servidores de módulo configurados (saída: `Servers`)
- `AddModulesServer(Type, Name, Source, Preserve?, OverwriteDefinition?, User?, Password?)` —
  registra novo servidor de módulos no ambiente headless

### Relevância para o fluxo de KB paralela

`GetModulesServer` é útil como diagnóstico: antes de um `RestoreModule` ou `InstallModule`,
confirmar quais servidores estão acessíveis no contexto headless. `AddModulesServer` com
`Type="Directory"` pode registrar um servidor local (pasta) sem acesso à rede.

`InstallModule` e `UpdateModule` abrem a possibilidade de um pipeline headless de atualização
de dependências: "instalar ou atualizar este módulo de terceiro na KB sem abrir a IDE".

### O que justificaria implementar agora vs. aguardar

Aguardar até que `RestoreModule` esteja implementado e validado. Só então avaliar se o caso
de uso de instalação/atualização headless de módulos aparece no portfólio. O cenário mais
provável de chegada não é importação de XPZ, mas setup inicial de KB de teste que precisa
das mesmas dependências de módulo que a KB de origem.

### Perguntas a responder antes de decidir

- `InstallModule` com `Version` vazio usa a versão mais recente disponível no servidor ou
  a versão especificada no arquivo de dependências da KB?
- `AddModulesServer` com `Preserve=true` persiste a configuração entre sessões MSBuild ou
  apenas para a sessão corrente?
- Em que arquivo ou estrutura o GeneXus armazena a lista de servidores configurados? É por
  KB ou por instalação?

## GetCategoryObjects — seleção de objetos por categoria para Export/Import

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Documentada no índice `3908.html` da instalação oficial.

### Problema concreto que motiva a ideia

Hoje, quando a skill `xpz-msbuild-import-export` faz export ou import com recorte, o
chamador precisa fornecer a lista de objetos explicitamente em `Objects`, `IncludeItems`
ou `ExcludeItems`. Em projetos que usam categorias GeneXus como convenção de organização
("todos os objetos da categoria `Faturamento`", "todos os da categoria `Integrações`"),
o usuário precisa enumerar os nomes manualmente ou extrair a lista de outra forma.

`GetCategoryObjects` retorna a lista de todos os objetos pertencentes a uma categoria.
O fluxo seria: chamar `GetCategoryObjects` com `CategoryName`, capturar a lista
resultante, usá-la diretamente como entrada de `Export` ou `IncludeItems` de `Import`.

### Parâmetros documentados

- `CategoryName` (obrigatório) — nome da categoria GeneXus
- Saída via `<Output TaskParameter="Objects" PropertyName="..."/>` — lista capturável
  em propriedade MSBuild nomeada pelo chamador

### Distinção importante

Categorias GeneXus são agrupamentos organizacionais criados manualmente pelo desenvolvedor
na IDE — diferentes de tipos (`Procedure`, `WebPanel`), módulos e pastas. A task opera
sobre essa classificação visual, não sobre a estrutura interna de tipos.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.GetCategoryObjects` está exposta no
  assembly com o parâmetro documentado
- Confirmar que o formato de saída é compatível com `IncludeItems`/`ExcludeItems` de `Import`
  sem transformação intermediária

### Perguntas a responder antes de decidir

- `Genexus.MsBuild.Tasks.GetCategoryObjects` aparece no assembly com `CategoryName`
  como propriedade pública?
- O formato de saída é lista plana de nomes de objeto no mesmo formato que `IncludeItems`
  aceita, ou exige transformação?
- O que a task retorna quando a categoria está vazia ou não existe — falha, lista vazia ou
  `exitCode` diferente?
- "Categoria" aqui corresponde exatamente ao conceito visual da IDE ou a outro agrupamento
  interno do GeneXus?

### Limiar para implementar

Implementar quando houver: (a) reflexão do assembly confirmando a task acessível com os
parâmetros documentados, e (b) caso concreto de projeto que usa categorias como convenção
de organização de objetos, tornando a seleção por categoria mais prática que a lista manual.

---

## CalculateChecksums + AreObjectsEqual — diagnóstico de integridade de objeto pré/pós-operação

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Tasks registradas em `Genexus.Tasks.targets`; **sem documentação oficial em `3908.html`**.

### Problema concreto que motiva a ideia

O fluxo de verificação pós-import hoje depende de `importedItems` (lista de o que entrou),
`exitCode` e varredura de stdout/stderr. Nenhum desses verifica se o objeto que entrou
é de fato diferente do que estava antes, nem se o objeto na KB de destino ficou idêntico
ao objeto da KB de origem. Há um gap de evidência objetiva entre "o import foi executado"
e "o objeto mudou da forma esperada".

### O que cada task faz (hipótese — sem documentação oficial confirmada)

`CalculateChecksums` — calcula checksums de um conjunto de objetos da KB. Potencial uso:
registrar o checksum dos objetos antes do import, recalcular depois, comparar para
confirmar quais mudaram e quais permaneceram inalterados.

`AreObjectsEqual` — compara dois objetos e retorna se são idênticos. Potencial uso:
comparar o estado de um objeto na KB de destino com o mesmo objeto na KB de origem,
ou comparar o estado antes e depois de uma operação dentro da mesma KB.

### Distinção entre as duas

São mecanismos complementares mas de granularidade diferente. `CalculateChecksums` opera
sobre um conjunto de objetos em lote; `AreObjectsEqual` opera sobre dois objetos
comparados par a par. Para o fluxo de verificação pós-import, `CalculateChecksums` seria
mais prático: calcula o checksum do conjunto importado antes e depois da operação.

### Risco adicional desta dupla

Diferente das tasks documentadas em `3908.html`, estas duas são registradas apenas em
`Genexus.Tasks.targets` sem documentação offline correspondente. O risco de comportamento
imprevisível ou interface não estável é maior. A investigação começa pela reflexão do
assembly antes de qualquer uso.

### Condições antes de implementar

- Verificar empiricamente se ambas estão expostas no assembly com propriedades acessíveis
- Para `CalculateChecksums`: qual é a granularidade do checksum? Objeto inteiro ou por
  part-type? A saída é capturável via `TaskOutput`/`CaptureOutput`?
- Para `AreObjectsEqual`: os dois objetos são da mesma KB aberta (dois estados) ou de
  duas KBs distintas? Como se passa o segundo objeto para comparação?

### Perguntas a responder antes de decidir

- `CalculateChecksums` e `AreObjectsEqual` aparecem no assembly com propriedades públicas
  acessíveis?
- `CalculateChecksums` opera sobre a KB aberta no contexto headless corrente ou precisa
  de parâmetro de escopo adicional?
- A saída de `CalculateChecksums` é legível e comparável entre duas execuções, ou é
  representação interna não determinística?
- `AreObjectsEqual` compara objetos da mesma KB ou permite comparar entre KBs distintas?
- O resultado de `AreObjectsEqual` é capturável programaticamente ou apenas emitido em
  stdout?

### Limiar para implementar

Implementar quando houver: (a) reflexão do assembly confirmando ambas as tasks acessíveis,
(b) formato de saída de `CalculateChecksums` legível e determinístico, e (c) caso concreto
de verificação pós-import em que a lista de `importedItems` não for evidência suficiente
de que o objeto mudou da forma esperada.

---

## CompressKB — manutenção da KB após importações de grande volume

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Arquivo `CompressKB.msbuild` confirmado como presente na instalação oficial do GeneXus 18,
idêntico em todas as instalações inspecionadas (21 linhas).

### Problema concreto que motiva a ideia

Importações de grande volume inserem e atualizam muitos registros no banco interno da KB
(SQL Server ou LocalDB). Com o tempo, o banco pode ficar fragmentado internamente. A operação
`CompressKB` abre a KB com o parâmetro `CompressData='true'` em `OpenKnowledgeBase` e a
fecha — possivelmente acionando compactação ou reorganização interna do banco da KB.

Diferente da reorg do GeneXus (que altera o banco da **aplicação**), `CompressKB` afeta
o banco **interno da KB** — o repositório de objetos, regras e metadados.

### Distinção técnica importante

`CompressData` não é uma task separada — é um parâmetro de `OpenKnowledgeBase`. O arquivo
`CompressKB.msbuild` já é o wrapper pronto entregue pela instalação oficial. A skill não
precisaria gerar um `.msbuild` dinamicamente: apenas invocaria `CompressKB.msbuild` com o
parâmetro `-p:kbLocation=<caminho>`, reusando o arquivo permanente da instalação.

### Condições antes de implementar

- Verificar empiricamente o que `CompressData='true'` faz de fato no banco interno da KB:
  compressão SQL Server (ROW/PAGE), compactação lógica interna do GeneXus ou outro mecanismo
- Verificar se é seguro executar sem confirmação interativa — a operação não importa nem
  exporta objetos, mas altera o banco interno da KB
- Medir o tempo de execução em KBs de médio e grande porte
- Verificar se há efeito colateral ao reabrir a KB na IDE depois da operação

### Perguntas a responder antes de decidir

- O que `CompressData='true'` faz exatamente no banco interno da KB? É seguro executar
  sem confirmação interativa?
- O `CompressKB.msbuild` existente aceita apenas `-p:kbLocation` ou há outros parâmetros?
- Qual o tempo de execução típico em KBs de médio porte (~5.000 objetos)?
- A KB reabre normalmente na IDE após `CompressKB`? Há warning ou efeito colateral observável?
- A operação é idempotente — executar duas vezes seguidas é seguro?

### Limiar para implementar

Implementar quando houver: (a) verificação empírica do efeito real de `CompressData='true'`
confirmando operação segura sem efeito colateral grave, e (b) caso concreto de KB com
degradação de performance pós-import que se beneficiaria da compactação.

## Diagnóstico SQL somente leitura do banco interno da KB para provider/item desconhecido

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** sugestão recebida de agente externo em 2026-05-10, verificada empiricamente na
mesma sessão contra `GX_KB_wsEducacaoSpTeste`.

**Status em 2026-05-20:** a subfrente conceitual de classificação e comunicação foi registrada em `historico/IdeiasImplementadas_202605.md`. Esta entrada permanece pendente apenas quanto à capacidade operacional de diagnóstico SQL somente leitura.

### Problema concreto que motiva a ideia

As skills XPZ operam sobre XPZ/XML exportados, acervo `ObjetosDaKbEmXml` e índice derivado
SQLite (`KbIntelligence`). Nenhuma dessas camadas cobre o banco interno da KB (`GX_KB_*`
no SQL Server ou LocalDB). Metadados de designer de providers como K2BTools são persistidos
diretamente no banco interno em tabelas como `EntityType`, `Entity`, `EntityVersion` e
`EntityVersionComposition` — e nunca aparecem em XPZ exportado.

O risco prático é o **falso negativo**: agente busca `FormDesigner`, `K2B Object Designer`
ou o GUID do provider no XPZ/XML, não encontra nada, e conclui prematuramente que não há
resíduo do K2BTools na KB. No caso real (verificado empiricamente), havia resíduo — 36
entidades `FormDesignerPart` e 3 registros de tipo de designer com `ProviderId` do K2BTools
— mas tudo confinado ao banco interno.

O risco inverso também existe: ao encontrar os registros no SQL, o agente se sentir
autorizado a propor deleção. As tabelas envolvem metamodelo, versionamento e composição
interna da KB. Diagnóstico SQL serve para evidência e suporte; nunca para limpeza direta.

### Contexto empírico verificado — KB wsEducacaoSpTeste (2026-05-10)

**Ambiente:**
- KB: `C:\KBs\wsEducacaoSpTeste`
- Banco: `GX_KB_wsEducacaoSpTeste`
- `knowledgebase.connection`: `<ServerInstance>DESKTOPW11AJRS</ServerInstance>`, `<IntegratedSecurity>False</IntegratedSecurity>`, `<HostName>localhost</HostName>`
- String de conexão que funciona empiricamente: `Server=localhost;Database=GX_KB_wsEducacaoSpTeste;Integrated Security=True;Encrypt=False;TrustServerCertificate=True`
- Nota: o arquivo `knowledgebase.connection` registra `IntegratedSecurity=False` (campo GeneXus próprio), mas o SQL Server aceita Windows auth com `Integrated Security=True` normalmente. A leitura direta do campo `IntegratedSecurity` do XML não deve ser usada para montar a string de conexão sem esse ajuste.

**Achados confirmados empiricamente:**

*EntityType — tipos de designer registrados:*
```
EntityTypeId=155  EntityTypeName=WebPanelDesigner  EntityTypeNamespace=K2BTools
EntityTypeId=156  EntityTypeName=SDPanelDesigner   EntityTypeNamespace=K2BTools
EntityTypeId=161  EntityTypeName=FormDesigner      EntityTypeNamespace=''  (vazio)
```
Importante: `FormDesigner` **não** tem `Namespace=K2BTools`. Uma query que filtre por
`Namespace='K2BTools'` **não** encontrará FormDesigner.

*EntityVersion — registros de tipo com ProviderId do K2BTools:*

Três registros em `EntityVersion` com `EntityTypeId=1` (Root), `EntityVersionId=1`:
```
EntityVersionName=WebPanelDesigner  GUID=562b39a3-dde2-4349-9252-e9e69090c53e  ProviderId=be15a055-f4cc-408a-9218-c71184d2bc61
EntityVersionName=SDPanelDesigner   GUID=a84e76c6-ccf5-4b03-a9d2-7c31c3d717e6  ProviderId=be15a055-f4cc-408a-9218-c71184d2bc61
EntityVersionName=FormDesigner      GUID=0b6c8a65-e172-4196-a2b6-abd64ebd96d6  ProviderId=be15a055-f4cc-408a-9218-c71184d2bc61
```
Os três compartilham o mesmo `ProviderId=be15a055` (K2B Object Designer). Esse GUID
`be15a055` é o identificador do provider K2BTools — aparece 3 vezes em
`EntityVersionProperties`.

O GUID `562b39a3` pertence ao **WebPanelDesigner**, não ao FormDesigner. A row em `Entity`
com `EntityGuid=562b39a3` tem `EntityTypeId=1` (Root) e `EntityId=155`. Não é uma entidade
FormDesigner. O detalhe estrutural: `EntityId=155` coincide com o `EntityTypeId` do
WebPanelDesigner — padrão que sugere que tipos de designer se registram como entidades Root
com `EntityId = seu próprio EntityTypeId`. Não documentado oficialmente; observação empírica
desta KB.

*EntityVersion — instâncias FormDesignerPart:*
```
EntityVersion WHERE EntityTypeId=161: 36 registros
  Todos com EntityVersionName='FormDesignerPart'  (não 'FormDesigner')
EntityVersion WHERE EntityVersionName='FormDesigner': 1 registro
  (é o registro de tipo, TypeId=1/Root, não uma instância FormDesigner)
```
Total de ocorrências com algum nome contendo "FormDesigner": 37 (1 + 36), mas são dois
nomes distintos — não 37 registros para o mesmo nome.

*Entity:*
```
Entity WHERE EntityTypeId=161: 36 entidades
  Cada uma com EntityLastVersionId=1
```

*EntityVersionComposition — pais das FormDesignerPart (18 WebPanels distintos, verificados 2026-05-10):*
```
CardPhotoActions, CardPhotoCompact, CardWithSummary, CardWithSummaryVariant1,
DetailPopOver, DetailVariant1, DetailVariant2, DetailWithPhoto,
GenericEntityList, GenericEntityListWithImage, K2BT_SimplePriceList,
NotificationList, PhotoWithTitle, SelectedItem, SelectedItemTag,
StructuredList, StructuredPeopleList, Timeline
```
Cada um aparece com 2 linhas de composição de `FormDesignerPart` (36 linhas totais / 18 pais).
Lista completa, não parcial: query verificada com `COUNT(DISTINCT CompoundEntityId)=18`
e `rows_not_matching_exact_version_join=0`.

Nota: WebPanelDesigner (EntityTypeId=155) e SDPanelDesigner (EntityTypeId=156) não possuem
entradas em `EntityVersionComposition` como componentes nesta KB — apenas FormDesigner (161)
tem linhas de composição. Isso implica que o escopo desta query é completo para
"WebPanels com composição de FormDesignerPart", mas incompleto para audit total de
resíduos K2BTools internos (que exigiria checar outros ângulos além de ComponentEntityTypeId=161).

**Divergências encontradas no relato do agente externo:**
1. `EntityTypeNamespace=K2BTools` atribuído ao FormDesigner (EntityTypeId=161) — **incorreto**; namespace é vazio.
2. `EntityVersion.EntityVersionName='FormDesigner': 37 ocorrências` — **incorreto**; são 1 para 'FormDesigner' e 36 para 'FormDesignerPart'.
3. GUID `562b39a3` associado ao "contexto FormDesigner" — **impreciso**; é o GUID do WebPanelDesigner na EntityVersionProperties; a row em Entity com esse GUID é Root (EntityTypeId=1), não FormDesigner.

Essas imprecisões não invalidam o diagnóstico central, mas afetam queries de busca: uma
query filtrando `Namespace='K2BTools'` não encontraria FormDesigner, gerando novo falso
negativo.

### Tabelas candidatas para diagnóstico

- `EntityType` — tipos de designer; campos úteis: `EntityTypeId`, `EntityTypeName`, `EntityTypeNamespace`
- `Entity` — instâncias; campos úteis: `EntityId`, `EntityGuid`, `EntityTypeId`, `EntityLastVersionId`
- `EntityVersion` — versões e propriedades XML; campos úteis: `EntityVersionId`, `EntityTypeId`, `EntityVersionName`, `EntityVersionProperties`, `EntityVersionTimestamp`
- `EntityVersionComposition` — composição pai-filho; campos úteis: `ComponentEntityTypeId`, `ComponentEntityId`, `CompoundEntityTypeId`, `CompoundEntityId`, `CompoundEntityVersionId`
- `[OBJECT]` — opcional, apenas para tentar correlacionar com objetos GeneXus comuns exportáveis

### Escopo de uso

- Usar apenas quando houver evidência de provider/item desconhecido na abertura/build/export da KB **e** a busca no XPZ/XML não localizar o item
- A consulta SQL é somente leitura; serve para diagnóstico e geração de relatório para suporte, não para correção
- Nunca recomendar remoção direta por SQL de entidades internas da KB

### Cuidados metodológicos para o diagnóstico SQL

Derivados da análise de três imprecisões introduzidas durante a investigação desta KB
(2026-05-10), cada uma com mecanismo de origem distinto:

- **Namespace**: citar o valor de `EntityTypeNamespace` somente com query literal que retorne
  a linha específica (`WHERE EntityTypeId = <id>`). Nunca inferir por proximidade com linhas
  vizinhas da mesma família — tipos de designer da mesma extensão podem ter namespaces
  diferentes entre si.

- **Contagem de EntityVersion**: citar contagem de linhas relacionadas a um nome somente
  com `GROUP BY EntityVersionName`. COUNT sem agrupamento por nome vira narrativa ambígua
  quando o critério de busca casa com nomes distintos (ex.: `FormDesigner` e
  `FormDesignerPart` são dois nomes, não um).

- **GUIDs**: citar GUID somente com a linha exata de origem, a coluna em que apareceu e o
  `EntityVersionName` da linha. GUIDs de providers distintos podem aparecer juntos na mesma
  busca textual; agrupar sem preservar a cardinalidade "tipo → GUID → coluna → linha de
  origem" produz associação incorreta.

### Questões abertas antes de implementar

1. A `xpz-kb-parallel-setup` já lê `knowledgebase.connection`? Se sim, a string de conexão pode ser derivada automaticamente no contexto de setup — esse seria o home natural para a capacidade.
2. O acesso deve ser via script PowerShell com `System.Data.SqlClient` no motor compartilhado, ou apenas documentado como procedimento narrativo para o agente executar inline?
3. O GeneXus documenta oficialmente o esquema `EntityType`/`Entity`/`EntityVersion`? Se não, há risco de quebra em upgrade — essa limitação precisa ficar documentada explicitamente junto com a capacidade.
4. A normalização `Server=localhost` a partir de `<HostName>localhost</HostName>` (e não de `<ServerInstance>`) é confiável em todos os ambientes? Verificar se `HostName` sempre está presente ou se a derivação deve usar `ServerInstance` como fallback.

### Frente de regras conceituais — encerrada em 2026-05-10

A dimensão de **regras de classificação e comunicação** desta ideia foi tratada como frente
separada, registrada em `historico/IdeiasImplementadas_202605.md` e aplicada diretamente nas skills e na base compartilhada:

- `02-regras-operacionais-e-runtime.md` — nova seção "Limite do XPZ/XML frente a providers
  e extensoes GeneXus" com as oito regras operacionais conceituais
- `xpz-reader/SKILL.md` — bullet de classificação de item antes de concluir ausência
- `xpz-index-triage/SKILL.md` — bullet análogo para resultado negativo do índice

O que permanece pendente nesta entrada é apenas a capacidade operacional de **diagnóstico SQL somente leitura** no banco interno da KB, coberta pelo limiar abaixo.

### Limiar para implementar (diagnóstico SQL)

Implementar quando houver: (a) resposta para a questão 1 acima (home no setup ou skill
própria), e (b) caso concreto adicional de warning de provider em KB diferente que confirme
o padrão de busca para além do caso K2BTools verificado aqui.

## Gate de mojibake/UTF-8 por bytes em XML pré-empacotamento

**Importância:** alta
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

### Problema concreto que motiva a ideia

Payloads textuais de objetos GeneXus podem entrar no fluxo de empacotamento com bytes corrompidos por interpretação dupla de encoding (clássico `Ã§` no lugar de `ç`, `Ã£` no lugar de `ã`, `NÃ£o` no lugar de `Não`, `usuÃ¡rio` no lugar de `usuário`). Causas típicas: arquivo salvo em CP1252 e lido como UTF-8, ou o inverso, com a conversão silenciosa em alguma etapa intermediária do fluxo (export da IDE, edição manual, conversão de encoding por ferramenta externa).

Se esse texto entra num `import_file.xml` e é importado pela IDE, o conteúdo fica permanentemente errado na KB de destino — só corrigível por novo import corretivo após localizar todos os pontos contaminados.

Detecção visual em terminal não é confiável: o terminal pode estar mascarando o problema (renderizando bytes incorretos como caracteres certos por configuração de fonte/encoding) ou inventando-o (mostrando lixo onde os bytes estão corretos). A verificação tem de ser **por bytes**, não por render.

### Direção técnica proposta

Wrapper `.ps1` no motor compartilhado, candidato a nome `Test-XmlMojibakeSanity.ps1`:

- entrada: path de arquivo XML, ou pasta + glob recursivo
- algoritmo: ler bytes brutos, procurar sequências características de mojibake UTF-8↔CP1252 (`Ã[\x80-\xBF]`, `Â[\x80-\xBF]` em contexto suspeito, etc.) com lista finita e bem documentada de assinaturas
- saída estruturada: `OK` ou lista de arquivos com ofsets e contexto suspeito
- política de falha: a definir entre bloqueio rígido e alerta

Skills consumidoras:

- `xpz-builder`: gate pré-empacotamento, chamado antes de gerar `import_file.xml`
- `xpz-msbuild-import-export`: gate opcional pré-import, como camada extra de defesa
- wrapper local da pasta paralela pode chamar no fluxo de empacotamento local

A escolha por script (e não por regra textual em SKILL.md) segue a preferência metodológica desta base: comportamento determinístico mora em `.ps1`, regra textual em skill fica reservada para o que exige julgamento de agente.

### Perguntas a responder antes de decidir

- Qual a lista exata de assinaturas de mojibake a detectar? Falso positivo aqui é caro — bloquear pacote legítimo é pior que deixar passar um caso raro.
- O gate **bloqueia** o empacotamento ou apenas **alerta**? Depende de quanto o repositório-alvo admite texto legado com acentuação degradada.
- O escopo cobre apenas `Source` e equivalentes textuais editáveis, ou inclui `Description`, `Documentation` e nomes de identificadores?
- Há caso real recente de mojibake em pacote dentro do portfólio que sirva para calibrar a heurística empiricamente?

### Limiar para implementar

Implementar quando houver: (a) caso real de mojibake detectado em pacote do portfólio para calibrar empiricamente as assinaturas e a política de bloqueio/alerta, e (b) decisão fechada sobre escopo de partes do XML cobertas.

## Gate de dependências GeneXus no empacotamento de delta

**Importância:** alta
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

### Problema concreto que motiva a ideia

Ao gerar um delta XPZ alterando um `Attribute` (ou qualquer objeto referenciado por outros), é tentador empacotar só o objeto modificado. Em GeneXus, porém, esse atributo aparece **estruturalmente embutido** em outros objetos:

- `Transaction` que tem o atributo no seu level
- `SDT` que espelha o atributo (campo de mesmo nome e mesmo tipo)
- `DataProvider` que produz ou lê o atributo
- `WebPanel`/Work With que exibe ou recebe o atributo
- `Procedure` que lê ou escreve o atributo

Se o pacote contém só o atributo e os dependentes ficam de fora:

- a Transaction importada ainda carrega a definição anterior embutida (não há rebuild automático da estrutura do level)
- SDTs continuam com o tipo antigo, gerando type-drift silencioso
- callers compilam contra o shape antigo
- o build pode até passar e a aplicação rodar errada sem erro visível

O extremo oposto também é problema: empacotar tudo que toca o atributo gera pacote inflado e arrasta objetos não relacionados ao delta real, aumentando risco do import.

Hoje a decisão do que entra no pacote é narrativa do agente, sem consulta sistemática à grade real de dependências.

### Direção técnica proposta

Separar duas camadas:

**Camada determinística (`.ps1`):** consulta de dependências. Dado um conjunto de objetos `S`, retornar todos os objetos da KB que referenciam algum objeto de `S`, classificados por tipo de referência (estrutural embutida em level vs uso por chamada em Source vs apenas leitura em Rules, etc.). Dado puro — se o SQLite de `KbIntelligence` já tem a grade de referências, é uma query nova; se não tem, há frente preparatória de extrair essa grade dos XMLs no build do índice.

**Camada de julgamento (regra textual em `xpz-builder`):** dado o resultado da consulta acima, o agente apresenta ao usuário a sugestão de "pacote mínimo coerente". O gate não automatiza a inclusão — força o agente a **declarar explicitamente** quais dependentes está deixando de fora e por quê. Regra mínima textual em `xpz-builder`: "ao empacotar um objeto que tem dependentes, listá-los explicitamente e justificar exclusões".

Handshake entre skills:

- `xpz-builder` é o consumidor (vai empacotar)
- `xpz-index-triage` é o provedor da consulta (já é o lugar natural de "quem chama/referencia quem")
- conecta também com os itens "callers/migração" do mesmo prompt externo (a serem avaliados separadamente)

### Parentesco com a frente de drift de tipagem

Esta entrada e "Drift de tipagem entre Attribute, SDT, DataProvider e callers" (entrada subsequente) são parentes próximas, mas com perguntas distintas:

- esta entrada pergunta **"quem mais precisa entrar no pacote?"**
- a entrada de drift pergunta **"o que está no pacote bate com o que está na KB de destino?"**

Ambas consomem a mesma grade de dependências, mas com semânticas diferentes. Mantidas como entradas separadas porque os limiares de implementação podem divergir; se uma virar frente, a outra deve ser reavaliada na mesma sessão para decidir se entra junto.

### Perguntas a responder antes de decidir

- O SQLite de `KbIntelligence` já registra a grade de referências entre objetos? Se sim, qual a granularidade — só "objeto A referencia objeto B" ou também o tipo de referência (embutida em level, chamada em Source, leitura em Rules)?
- Se a grade não existir no índice atual, qual o custo de extrair durante o build do índice? Há heurística estrutural confiável por tipo de objeto (level de Transaction, structure de SDT, source de Procedure, etc.)?
- O gate deve **bloquear** o empacotamento na ausência de declaração explícita sobre dependentes, ou apenas **exigir manifesto** que o agente liste e justifique?
- Como o gate se comporta quando a KB de destino é diferente da KB de origem (cenário de migração entre KBs)? A grade da KB de origem pode não cobrir referências que existem apenas na destino.

### Limiar para implementar

Implementar quando houver: (a) confirmação empírica de que o SQLite atual cobre (ou pode cobrir com custo aceitável) a grade de referências entre objetos com granularidade suficiente, e (b) caso real recente de empacotamento que deixou dependente importante de fora e contaminou KB de destino, para calibrar a política do gate.

## Drift de tipagem entre delta empacotado e snapshot oficial

**Importância:** alta
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

**Filiação editorial:** esta entrada é o caso prático concreto da camada de comparação proposta de forma abstrata em "Baseline conhecido no sanity e na revisao de objeto legado" (mesma seção 999). Se uma das duas virar frente de implementação, a outra deve ser reavaliada na mesma sessão.

### Problema concreto que motiva a ideia

Cenário típico: o agente recebe pedido para alterar o atributo `Email` e gera um delta XPZ declarando o tipo `Character(60)`. O snapshot oficial em `ObjetosDaKbEmXml` mostra que `Email` na KB atual está como `Numeric(15)`. Se o delta é importado, o tipo na KB é sobrescrito silenciosamente. A aplicação rodando depende do tipo atual — registros existentes, callers compilados, banco com coluna no tipo antigo — e quebra em cascata só depois, no build ou em runtime, longe do momento do import.

Causas típicas:

- agente gerou o delta a partir de premissa antiga (snapshot que tinha em contexto não era o snapshot atual)
- source do delta foi redigido com tipo errado por engano de transcrição
- drift interno na própria KB que já existia antes do delta — atributo com um tipo, SDT que deveria espelhar com tipo diferente — detectável só lendo o snapshot

Variações estruturais do mesmo problema:

- Attribute no delta com tipo X, snapshot com tipo Y
- SDT no delta com campo de tipo X, atributo homônimo no snapshot com tipo Y
- DataProvider no delta retornando shape que não bate com SDT consumidor já existente no snapshot
- Procedure no delta com parâmetro de tipo X, callers no snapshot chamando com tipo Y

Hoje `xpz-builder` valida XML bem-formado e sanity absoluto do `Source` do delta, mas não compara o tipo do que entra contra o tipo do que já está no snapshot. Há ponto cego entre "`import_file.xml` válido" e "`import_file.xml` coerente com o snapshot oficial da KB que vai recebê-lo".

### Direção técnica proposta

Mesmo padrão das outras frentes determinísticas: separar camadas.

**Camada determinística (`.ps1`):** para cada objeto no delta, extrair os tipos relevantes (tipo do Attribute, tipos dos campos do SDT, assinaturas de parâmetros de Procedure, etc.) e comparar contra o mesmo objeto em `ObjetosDaKbEmXml`. Saída estruturada por objeto: `same`, `drifted (tipo X → tipo Y)`, `new (não existe no snapshot)`.

Variante adicional sem delta: passar só o snapshot e detectar **drift interno** entre objetos que deveriam espelhar tipos (Attribute ↔ SDT homônimo, Procedure parameter ↔ caller signature).

**Camada de julgamento (regra textual em `xpz-builder`):** dado o resultado da comparação, o agente apresenta o drift detectado ao usuário com classificação de risco e exige confirmação explícita para drifts não triviais. Classificação proposta:

- drift estrutural em level de Transaction → alto risco
- drift em parâmetro de Procedure com callers existentes → médio risco
- novo objeto (não existe no snapshot) → baixo risco, apenas declarar

### Parentesco com item de dependências GeneXus

Esta entrada e "Gate de dependências GeneXus no empacotamento de delta" consomem a mesma grade de informações estruturais do snapshot, mas com perguntas distintas:

- gate de dependências pergunta "quem mais precisa entrar no pacote?"
- esta entrada pergunta "o que está no pacote bate com o snapshot?"

Mantidas separadas porque os limiares de implementação podem divergir; se uma virar frente, a outra deve ser reavaliada na mesma sessão.

### Perguntas a responder antes de decidir

- A extração de tipo é confiável por leitura estrutural do XML para todos os tipos de objeto envolvidos (Attribute, SDT, DataProvider, Procedure, Transaction level)? Quais part-types do XML carregam essa informação?
- O drift interno detectável só pelo snapshot (Attribute vs SDT homônimo) deve viver em script separado ou na mesma ferramenta de comparação delta-vs-snapshot?
- O gate deve **bloquear** o empacotamento quando houver drift de alto risco, ou apenas **exigir manifesto** que o agente liste e justifique?
- Como a saída se integra com o gate de dependências (1.2)? Drift de tipagem em objeto que tem dependentes não incluídos é cenário composto que precisa de tratamento conjunto.

### Limiar para implementar

Implementar quando houver: (a) caso real recente de drift de tipagem detectado tarde demais (no build ou em runtime) que tenha gerado dano efetivo, para calibrar a classificação de risco, e (b) decisão fechada se a frente vai junto com o gate de dependências (1.2) ou separada — depende de quanto da infraestrutura de leitura estrutural é compartilhada entre as duas.

## Parsing estruturado de log de build — agrupamento, classificação e resumo de impacto

**Importância:** média
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11. Fusão dos itens 3.1 (agrupador de causa raiz, P0 no prompt externo), 3.3 (classificador de erro por tipo, P1) e 3.4 (resumo de impacto — causa direta vs cascata, P1) do mesmo prompt. Os três sempre serão discutidos juntos: mesmo insumo (log do MSBuild), mesma técnica (heurísticas sobre mensagens), mesmo consumidor (`xpz-msbuild-build`).

### Problema concreto que motiva a ideia

Quando `Invoke-GeneXusKbBuildAll.ps1` retorna `compilou com erros`, hoje o agente reporta o status e expõe o log bruto. O usuário precisa ler dezenas ou centenas de linhas para identificar a causa real. Em casos típicos de GeneXus, dezenas de erros derivam de **uma única causa raiz** — um atributo com tipo errado pode gerar erros em cascata em todos os SDTs, DataProviders e Procedures que o consomem. Sem agrupamento, o usuário pode gastar tempo investigando um erro derivado em vez da causa.

A skill atual classifica o **resultado da operação** em categorias claras ("compilou com erros", "reorg detectada ou executada", etc.), mas não classifica nem agrupa **os erros individuais dentro do log**.

### Três camadas da mesma frente

**Agrupamento por causa raiz (item 3.1 do prompt externo):** dado um log com N erros, identificar quais são derivados de uma mesma causa estrutural e apresentar apenas a causa raiz com os derivados como "cascata de M erros relacionados".

**Classificação por tipo de causa (item 3.3 do prompt externo):** rotular cada causa raiz por categoria:

- erro de conteúdo — Source GeneXus mal-formado, sintaxe incorreta
- erro de tipagem — drift de tipo detectado em tempo de build
- erro de dependência — objeto chamado/referenciado não existe ou referência quebrada
- erro de encoding — bytes corrompidos detectados em compile
- erro de reorg — banco/schema desalinhado com o modelo

**Resumo de impacto (item 3.4 do prompt externo):** separar objetos que falharam por causa direta dos que falharam por efeito cascata, declarando explicitamente o grafo de impacto.

### Direção técnica proposta

Camada determinística (`.ps1`): parser estruturado do log do MSBuild que extrai erros, normaliza mensagens, identifica grafos de derivação por nome de objeto/atributo, agrupa por causa raiz, classifica por padrão de mensagem. Saída estruturada (JSON) consumível pelo agente.

Camada de julgamento (regra textual em `xpz-msbuild-build`): apresentação ao usuário do parsing estruturado, com formatação que enfatiza causa raiz e oculta derivações repetitivas até que o usuário peça.

### Loop de feedback com gates upstream

A categoria de classificação (1.1 encoding, 1.2 dependência, 1.3 tipagem) mapeia diretamente para os gates upstream propostos em outras entradas desta seção. Um erro classificado como "tipagem" que aparece no build é, em tese, um caso que o gate de drift de tipagem (1.3) deveria ter pego antes. Esse mapeamento fecha um loop de feedback: erro classificado X no build → revisar gate X upstream.

O valor real desse loop só se materializa quando pelo menos um gate upstream estiver implementado e gerando casos de teste reais de "erro que escapou".

### Perguntas a responder antes de decidir

- As mensagens de erro do GeneXus 18 nesta instalação têm formato estável o suficiente para heurística confiável? Em que medida mudam entre minor versions? É necessário um catálogo empírico de mensagens por categoria como pré-requisito.
- Como distinguir erros que vêm de specify do GeneXus, errors de generate, erros de compile (Java/C#) e erros de MSBuild puro? Cada fonte tem padrão próprio.
- Como tratar erros sem objeto identificável (erro de infraestrutura, erro de configuração de ambiente)? Categoria residual "ambiente"?
- Falso negativo (não identificar derivação que existia) é melhor ou pior que falso positivo (agrupar erros não relacionados)? Provavelmente falso negativo é menos ruim — não esconde nada do usuário.
- Quanto do parsing deve viver em script vs ser delegado ao agente? Pattern matching é determinístico; correlação semântica entre erros pode exigir julgamento.

### Limiar para implementar

Implementar quando houver: (a) pelo menos um gate upstream (1.1 mojibake, 1.2 dependências ou 1.3 drift de tipagem) implementado e em uso real, gerando casos concretos de "erro que escapou ao gate" para calibrar o classificador empiricamente; e (b) catálogo empírico de mensagens de erro do GeneXus 18 mapeado por categoria, construído a partir de logs reais de build com erro.

## Manifesto semântico de pacote — saída agregada dos gates de empacotamento

**Importância:** média
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

**Filiação editorial:** esta entrada é a saída agregada das frentes "Gate de mojibake/UTF-8 por bytes em XML pré-empacotamento", "Gate de dependências GeneXus no empacotamento de delta" e "Drift de tipagem entre delta empacotado e snapshot oficial" (todas em 999). Sem pelo menos uma dessas frentes implementada, o manifesto fica oco — o invólucro existe mas as seções "dependências confirmadas/presumidas" e "riscos" não têm conteúdo estruturado para preencher.

### Problema concreto que motiva a ideia

Hoje o agente narra o pacote durante a sessão de empacotamento: o que entrou, o que deliberadamente ficou de fora e por quê, riscos avaliados. Quando a sessão fecha, essa narrativa some. Restam apenas `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml` na pasta de pacotes — opaco para auditoria posterior.

Em frente longa, ou em handoff entre agentes (mesmo entre sessões consecutivas do mesmo agente), perder essa camada custa caro. Outro agente que pegue o mesmo `import_file.xml` daqui a duas semanas precisa reconstruir do zero o raciocínio de inclusão/exclusão. Não há fonte persistente da **intenção** de empacotamento, apenas do resultado.

Diferente do log de import (que registra o que aconteceu no MSBuild), o manifesto mostra o que se pretendia fazer e por quê.

### Conteúdo proposto

Quatro seções derivadas das frentes upstream:

- **objetos alterados** — lista de objetos no pacote (já trivial sem dependência de outra frente)
- **dependências confirmadas** — referenciados pelos objetos alterados que foram **incluídos** no pacote por decisão explícita; alimentada pelo gate de dependências
- **dependências presumidas** — referenciados pelos objetos alterados que foram **deixados de fora** por decisão explícita, com justificativa; alimentada pelo mesmo gate
- **riscos** — alertas detectados pelos gates de mojibake, drift e qualquer outro gate que vier a existir; categorizados por severidade

### Direção técnica proposta

Camada determinística (saída de scripts): cada gate upstream emite resultado estruturado (JSON) que serve como insumo do manifesto.

Camada de julgamento (regra textual em `xpz-builder`): consolidar os resultados estruturados, adicionar a narrativa de inclusão/exclusão deliberada e gerar o manifesto final como artefato persistente no momento do empacotamento.

### Decisões editoriais ainda em aberto

- **Formato:** JSON estruturado (consumível por outro agente), MD legível (consumível por humano), ou ambos? A combinação JSON + MD lado a lado tende a inflar custo de manutenção; um único formato consumível por ambos os públicos seria mais limpo.
- **Posição:** raiz de `PacotesGeradosParaImportacaoNaKbNoGenexus` junto com `import_file.xml`, ou subpasta dedicada? A regra atual exige que a pasta permaneça plana — manifesto na raiz parece natural.
- **Nomenclatura:** `NomeCurto_GUID_YYYYMMDD_nn.manifest.{ext}` segue o padrão atual de prefixo de frente.
- **Versionamento Git:** por default, `PacotesGeradosParaImportacaoNaKbNoGenexus` não é versionada; manifesto pode ser exceção por valor de auditoria, mas isso é decisão de política do repositório, não automatismo do agente.
- **Produtor:** `xpz-builder` é o consumidor natural; manifesto seria saída adicional do mesmo fluxo de empacotamento, não wrapper separado.

### Perguntas a responder antes de decidir

- A camada de "dependências presumidas" exige enumerar **todos** os referenciados não incluídos, ou apenas aqueles que o gate de dependências sinalizou como potencialmente relevantes? A primeira opção é exaustiva mas pode ser ruidosa; a segunda é seletiva mas depende de heurística confiável no gate.
- O manifesto deve ser regenerável a partir do `import_file.xml` sozinho, ou pressupõe acesso ao contexto da sessão de empacotamento? Regenerável tem custo (re-rodar gates contra o snapshot atual), mas dá robustez de auditoria.
- Há valor em manifesto também para a saída do build (causa raiz, classificação, impacto — entrada "Parsing estruturado de log de build")? Ou manifesto é estritamente da fase de empacotamento?

### Limiar para implementar

Implementar quando houver: (a) pelo menos um gate upstream (1.1 mojibake, 1.2 dependências ou 1.3 drift de tipagem) implementado e em uso real, gerando saída estruturada que sirva de conteúdo para uma das seções do manifesto; e (b) decisão editorial fechada sobre formato, posição, nomenclatura e política de versionamento Git.

## Expansão do índice SQLite para fingerprint de call site

**Importância:** média
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11. Surgiu como evolução adjacente à proposta original "Consulta de migração (Origem → Destino)" — a leitura cosmética foi descartada para 998; o ângulo estrutural sobrevive aqui.

### Problema concreto que motiva a ideia

A consulta `who-uses Procedure:X` no índice atual retorna a lista de objetos que referenciam o alvo — apenas os nomes. Para editar cirurgicamente cada caller (substituir referência antiga por nova, ajustar parâmetros, remover uso obsoleto), o agente precisa abrir o XML de cada caller e localizar o local exato da referência. Em uma migração que afeta 20 ou 30 callers, isso vira leitura manual extensiva mesmo com o índice ajudando a triagem inicial.

O índice já varre todos os XMLs uma vez durante o build (`Build-KbIntelligenceIndex.py`). Agregar **o local** de cada referência no mesmo passo de varredura é custo marginal frente ao trabalho já realizado.

### Direção técnica proposta

Estender o schema do SQLite para registrar, em cada relação de referência entre objetos, metadados de localização:

- `part` — qual part-type do XML contém a referência (Event, Action, Source, Rules, Conditions, Layout, etc.)
- `block` — nome do bloco nominal dentro do part (qual Event, qual Action, etc.) quando aplicável
- `line` — linha aproximada no Source quando aplicável
- `context` — trecho curto do XML em torno da referência, para o agente confirmar antes de editar

Resultado: `who-uses Procedure:X` passa a retornar não só "estes N objetos te referenciam" mas "te referenciam aqui — `WPRelatorio` no Event 'Refresh' linha ~47, `PRecalcular` no Source linha ~12, etc.".

### Por que **não** substitui a frente vetorial em 999

A frente "LlamaIndex / LangChain + vector store como alternativa ao indice SQLite atual" e esta entrada respondem perguntas diferentes:

- **Vetorial:** descoberta semântica por intenção em linguagem natural ("qual procedure atualiza o saldo de estoque mensal?"); ajuda a achar **o quê** quando o nome do objeto é desconhecido
- **Fingerprint no SQLite:** endereçamento estrutural preciso ("onde exatamente cada caller referencia este alvo?"); ajuda a achar **onde** quando os nomes já são conhecidos

São complementares. Implementar uma não dispensa a outra. Custos de implementação são muito diferentes — vetorial exige camada nova completa (embeddings, vector store, novo wrapper); fingerprint é evolução incremental do índice atual.

### Perguntas a responder antes de decidir

- Qual a granularidade de localização que de fato basta para edição cirúrgica? Part + bloco nominal é suficiente, ou precisa linha aproximada e trecho de contexto também?
- O custo de varredura adicional durante o build do índice é aceitável? Validar empiricamente em KB grande (~15k objetos).
- O schema atual do SQLite comporta a expansão sem migração disruptiva? Provavelmente sim (nova tabela de localizações vinculada à tabela de relações), mas precisa confirmação.
- A informação de fingerprint deve ser exposta como capacidade nova no wrapper local (`who-uses-detailed`?), ou enriquecer a saída de `who-uses` existente? Compatibilidade retroativa é uma decisão editorial.
- Como tratar referências em part-types com formato não-linear (Layout XML, Rules, Conditions)? "Linha aproximada" não faz sentido em todos os casos.

### Limiar para implementar

Implementar quando houver: (a) caso real recente de migração em lote (10+ callers) que tenha custado caro por leitura manual de XML após o `who-uses` apontar os nomes; e (b) decisão fechada sobre granularidade do fingerprint (qual nível de localização vale o custo de armazenar e manter).

## Enxugar o inventário de scripts do `09` para ponteiros (remover duplicação que drifta) — IMPLEMENTADO E MIGRADO

> Implementado e migrado para `historico/IdeiasImplementadas_202606.md` em 2026-06-15 (commits `d8844c4`/`45dbc2b`/`a259358`; veto de modelos em `33bd9aa`; trava `PUBLIC_TRACEABILITY_VERBOSE_LINE` no gate de rastreabilidade). As ~111 entradas de script do `09` viraram ponteiros de 1 linha (Caminho 1: tokens/sentinelas/exits nus, prosa de contrato no dono), com downstream em `AGENTS`/`08`/`13`/`998`/`CHANGELOG`; pré-push mecânica verde e fase semântica limpa; **não pushado** (decisão do usuário). O candidato 2 da trava (gêmeo `09↔dono`) ficou como ideia própria abaixo.

## Trava anti-regressão do `09` enxuto — gêmeo `09↔dono` (candidato 2)

**Importância:** baixa
**Maturidade:** ideia

**Origem:** fechamento do enxugamento do `09` (2026-06-15). O candidato 1 (sinal `PUBLIC_TRACEABILITY_VERBOSE_LINE`, que detecta entrada de script voltando ao formato verboso) foi implementado junto da frente. Sobra o candidato 2, mais complexo.

### Problema

O ponteiro curto realocou o risco de drift para `09`↔dono: o token-check do gate passa (tokens nus preservados), mas a referência pode ficar semanticamente errada quando o **dono** muda e o ponteiro do `09` não (ou vice-versa). O `Test-PrePushTraceabilityCoverage.ps1` hoje não cobre essa assimetria.

### Direção

Um "gêmeo" do `Test-PrePushSharedScriptSkillCoverage.ps1` para `09`↔dono: quando o diff altera um dono normativo (skill / `02` / `08` / `13` / catálogo) sem tocar o ponteiro correspondente no `09` (ou vice-versa), avisar como candidata a conferir. `warn`, não bloqueante.

### Dificuldade / limiar

O "dono" no ponteiro é texto livre (`Dono: <skill/doc>`), então mapear ponteiro→dono de forma robusta é o ponto duro (alto risco de falso positivo). Implementar quando aparecer a primeira regressão real de `09`↔dono, ou ao consolidar os gates consultivos da pré-push numa próxima rodada.

## Faceta b — gate "motor novo sem entrada no `09`" (ampliar `PUBLIC_TRACEABILITY_MISSING_SCRIPT`)

**Importância:** baixa
**Maturidade:** pesquisa feita (painel de pares 2026-06-15 mapeou as decisões abertas)

**Origem:** "faceta dependente (b)" da entrada do enxugamento do `09` (migrada ao histórico). Hoje o `Test-PrePushTraceabilityCoverage.ps1` só emite `PUBLIC_TRACEABILITY_MISSING_SCRIPT` quando o diff do script casa um token do `$scriptRiskPattern` (`INVENTORY_*`/`executionEvidence`/etc.); um motor novo que **não** emite esses tokens (ex.: `Set-GeneXusXmlLastUpdate.ps1`) passa batido mesmo ausente do `09`.

### Direção

Para todo `scripts/*.{ps1,py}` tocado no diff cujo basename **não** apareça no texto do `09` → `warn`, **independente** de token de risco (afrouxar a condição `$scriptHasTraceabilityRisk` da regra de basename, reusando o `code=PUBLIC_TRACEABILITY_MISSING_SCRIPT` existente). Consultivo, com teto; self-test no molde do `PUBLIC_TRACEABILITY_VERBOSE_LINE`.

### Decisões abertas (mapeadas pelo painel de pares 2026-06-15)

- **O `09` NÃO é índice nominal completo hoje** (premissa que o painel derrubou). Há ~12-17 `.ps1`/`.py` reais ausentes (`Extract-XpzObject`, `Query-KbIntelligenceIndex`, `Watch-GeneXusMsBuildLog`, `Test-XpzPowerShellRuntime`, `Update-XpzDocSection`, `Show-FileWhitespace`, gates 9-BC/9-IDO/9-PSM/9-WW, `Test-KbIntelligenceQueries.py`…) + ~14 fixtures `kb-intelligence-*.validation*.json`. A faceta b **alarga o contrato** do `09` de "índice de ponteiros das entradas que ele descreve" para "índice nominal completo de `scripts/`": decisão editorial — decidir o que o `09` promete cobrir e **reconciliar os ausentes** (ou documentar a exclusão) ANTES de ligar o gate, e registrar a virada de contrato no `13`/`08`/`02`.
- **`.json`**: excluir as fixtures de validação do escopo (senão toda frente que adiciona um caso de teste a uma bateria dispara falso positivo estrutural). Limitar a `.ps1`/`.py`, ou só catálogos/contratos `.json`.
- **`scripts-maintenance/`**: hoje o gate filtra `^scripts/` mas o `09` indexa `scripts-maintenance/` (entrada coletiva da campanha `exportTaskLabel`). Decidir: ampliar para `scripts(-maintenance)?/` ou remover do `09` a expectativa de indexar `scripts-maintenance/`.
- **`added` vs `added`+`modified`**: Claude recomenda só `added` (tocar um dos ~17 legados ausentes geraria warn); Codex/minimax recomendam `added`+`modified` (tocar um legado ausente é o momento barato de decidir se entra). Tratar `A`/`M`/`R`(destino), nunca `D`.
- **Match por fronteira de token**, não substring: `Foo.ps1` casa dentro de `Test-Foo.ps1`; usar `[regex]::Escape($base)` ancorado por fronteira. Manter a auto-exclusão do próprio gate (`$isTraceabilityDetector`).

### Distinção das outras travas do `09`

- `PUBLIC_TRACEABILITY_VERBOSE_LINE` (**implementada**): entrada existente que **re-incha** ao formato verboso.
- Gêmeo `09↔dono` (**candidato 2, acima**): dono muda e o ponteiro **não acompanha** (drift).
- Faceta b (**esta**): motor **novo nunca entrou** no `09` (lacuna no lado da adição).

### Limiar para implementar

Depois de reconciliar o contrato de cobertura do `09` (decidir e completar/excluir os ~17 ausentes + documentar no `13`/`08`). Só então abrir a frente do gate, com self-test.

## Correção de acentuação pt-BR degradada nos SKILL.md

**Importância:** alta
**Maturidade:** todos os segmentos versionados concluídos em 2026-06-11 — raiz `.md`, `skill-md`, `skill-satelite`, `outros-md`, comentários de `ps1` e `example-ps1` (ver as três subseções «Execução 2026-06-11» ao fim). Resíduo é só intencional (citações dos 3 arquivos do instrumento, conteúdo de string). **Dívidas abertas:** cópula geral `e/é` e textos pt-BR dentro de strings de `.ps1`

**Origem:** avaliação de prompt externo em 2026-05-11 com verificação empírica feita na mesma sessão.

### Problema concreto confirmado empiricamente

Varredura nos 10 SKILL.md do repositório em 2026-05-11 confirmou degradação de acentuação pt-BR generalizada. **Mojibake real (bytes corrompidos `Ã§`/`Ã£`/etc.) não existe** — o agente externo que reportou o problema possivelmente viu renderização errada de UTF-8 válido como CP1252 no terminal dele. O defeito real é de outra natureza: acentos perdidos por degradação a ASCII em palavras pt-BR. Exemplos colhidos diretamente de `xpz-index-triage/SKILL.md`:

- "indice derivado" → `índice derivado`
- **"O indice e artefato derivado"** → `O índice é artefato derivado` (caso clássico apontado pelo usuário — `e` conjunção onde devia ser `é` verbo, mudando completamente o sentido)
- "nao substitui... e nao autoriza conclusao funcional automatica" → `não substitui... e não autoriza conclusão funcional automática`
- "gate e obrigatorio... existencia" → `é obrigatório... existência`

Distribuição por arquivo (palavras inequivocamente acentuadas detectadas por regex restrito; número real é maior — cada `e`/`area`/`referencia` etc. é falso negativo do regex):

| arquivo | hits |
|---|---|
| xpz-kb-parallel-setup | 331 |
| xpz-sync | 99 |
| xpz-index-triage | 98 |
| xpz-msbuild-build | 22 |
| xpz-msbuild-import-export | 17 |
| xpz-builder | 10 |
| xpz-doc-builder | 5 |
| xpz-daemon | 3 |
| xpz-skills-setup | 3 |
| xpz-reader | 2 |
| **total** | **590+** |

> **Nota 2026-06-11 — a tabela acima (2026-05-11) está superada.** Veja a medição fresca abaixo.

### Medição fresca 2026-06-11 (nova baseline; substitui a tabela de 2026-05-11)

Re-medição empírica no estado do commit `e5b3e89`, com detector determinístico versionado (`scripts/Measure-PtBrAccentDegradation.ps1` + `scripts/ptbr-accent-wordlist.json` + self-test). **Não é comparável 1:1** com os 590+ de 2026-05-11: lista curada maior (165 palavras inequívocas), escopo ampliado (todos os `.md` versionados + `.example.ps1` + comentários de `.ps1`) e supressão de código/identificador. É **piso firme** (palavras cuja forma sem acento é sempre erro), não teto. A medição já inclui os próprios arquivos do medidor (contribuição pequena, nos comentários `.ps1`). `numero` foi movido ao teto solto por ser também forma verbal (*eu numero*, de *numerar*), mantendo `numeros` no piso firme — alinhado às exclusões de `referencia`/`publico`/`pagina`. Casos de borda `sao`/`ja`/`numeros` foram avaliados e mantidos no piso firme: a forma sem acento nunca é lexema pt-BR válido (inclusive o topônimo `São` também leva acento).

**Total no trabalho pendente: 7.812 ocorrências inequívocas** (+ 745 ambíguas "teto solto", não confirmadas).

| Segmento | No total? | Arquivos | Com defeito | Inequívocas | Ambíguas (teto) |
|---|---|---|---|---|---|
| skill-md | sim | 11 | 4 | 1412 | 162 |
| skill-satelite | sim | 9 | 1 | 1 | 5 |
| raiz-md | sim | 37 | 32 | 5304 | 459 |
| outros-md | sim | 2 | 2 | 213 | 12 |
| example-ps1 | sim | 25 | 22 | 101 | 6 |
| ps1 (comentários) | sim | 174 | 118 | 781 | 101 |
| historico/ | não (diagnóstico) | 53 | 48 | 1591 | 72 |
| aportes-comunidade | não (diagnóstico) | 0 | 0 | 0 | 0 |

Achados que mudam o enquadramento:

- **O grosso não está nos SKILL.md.** Os `.md` numerados da raiz (base empírica `01*`–`12`) concentram 5.304 ocorrências; os comentários de `.ps1` somam 781. A medição de 2026-05-11 só olhava SKILL.md, por isso subdimensionava o trabalho real.
- **A campanha interrompida corrigiu parte.** Dos 11 SKILL.md, só 4 ainda têm defeito (7 já limpos) — confirma o relato de que a frente foi iniciada e parada no meio.
- **`historico/` (1.591)** fica fora do total: registro imutável, não se corrige (só diagnóstico da dívida histórica preservada).
- **`AportesDaComunidadeParaAvaliacao/`** é git-ignored (não versionado) → fora do universo medido.

O **mapa cirúrgico** (`arquivo:linha:palavra`) é gerado em `work/ptbr-accent-map.{md,json}` (git-ignored, transitório), regenerável a qualquer momento pelo detector; a sessão de correção parte dele.

> **Distinção do `998`:** o `998-ideias-descartadas-e-porque.md` descartou um *gate por-KB sobre payload de objeto* (e-mail/HTML), que dependeria de vocabulário calibrado por KB. Este medidor é outra coisa — *auto-QA das próprias docs do repositório de skills*, corpus único e conhecido, lista curada fixa mais supressão de código —, por isso não reabre aquele descarte.

### Direção técnica proposta

**Correção manual contextual, não substituição cega por regex.** Algumas palavras têm forma válida com ou sem acento:

- `esta` pode ser `está` (verbo) ou `esta` (pronome demonstrativo — válido sem acento)
- `tem` pode ser `tem` (3ª p. singular, válido) ou `têm` (3ª p. plural)
- `vem` pode ser `vem` (3ª p. singular, válido) ou `vêm` (3ª p. plural)
- `e` é a conjunção (válida) ou `é` o verbo
- `so` é forma estrangeira (raramente válida no contexto) ou `só`

Substituição em massa por regex causaria regressões. A correção precisa ser decisão contextual linha a linha.

### Por que é frente própria, dedicada e sequencial

Três motivos para frente separada:

- **Volume**: 590+ hits no regex restrito; número real maior. `xpz-kb-parallel-setup` sozinho concentra 331 — execução não cabe em sessão genérica.
- **Risco de revisão cega**: substituição mecânica gera regressões nas palavras ambíguas listadas acima.
- **Política de edição segura de MD longo**: regra do `AGENTS.md` global exige edições pequenas, locais, ancoradas por seção, com releitura imediata após cada gravação. Aplicar isso em centenas de pontos pede sessão dedicada.

### Plano de execução proposto

> **Nota 2026-06-11:** a medição fresca acima re-prioriza o plano — o grosso está nos `.md` numerados da raiz (5.314) e em comentários de `.ps1` (734), não nos SKILL.md; e 7 dos 11 SKILL.md já estão limpos. Antes de corrigir cada arquivo, rodar o detector (`scripts/Measure-PtBrAccentDegradation.ps1`) para o estado atual e usar o mapa em `work/`.

1. Sessão dedicada para a correção, com escopo declarado: "correção de acentuação pt-BR degradada nos SKILL.md".
2. Atacar um SKILL.md por vez, começando pelos menores (xpz-reader, xpz-daemon, xpz-skills-setup, xpz-doc-builder, xpz-builder) para calibrar a estratégia.
3. Para cada arquivo: ler integralmente, gerar lista de correções propostas, aplicar em edições pequenas e ancoradas por seção, reler trecho alterado após cada gravação.
4. `xpz-kb-parallel-setup` (331 hits) provavelmente exige sessão própria adicional só para ele.
5. Atualizar lista quando concluir cada arquivo; preservar rastreabilidade do progresso.

### Perguntas respondidas em 2026-05-11 (antes de iniciar execução)

- **Há regras editoriais que justifiquem manter alguma palavra sem acento?** Não. Todos os hits são defeitos.
- **O escopo cobre só SKILL.md ou também outros `.md`?** Todos os `.md` do repositório, incluindo `historico/` (~70 arquivos).
- **Os `.example.ps1` com comentários pt-BR entram?** Sim — qualquer `.ps1` com texto em português legível por agente deve ter acentuação correta.

### Regra operacional para palavras ambíguas

Qualquer palavra cujo acento muda o sentido — `e/é`, `esta/está`, `tem/têm`, `vem/vêm`, `so/só`, e análogos — deve ser perguntada ao usuário antes de alterar. Nunca corrigir por inferência mecânica nesses casos.

### Limiar para implementar

**Pronto agora.** Não há gate técnico, não há pesquisa pendente, não há decisão de design em aberto. Falta apenas alocar sessão dedicada com escopo declarado.

### Execução 2026-06-11 (raiz `.md` concluída)

Sessão dedicada executou a correção nos `.md` da raiz, partindo do mapa regenerado pelo detector. Resultado e decisões:

- **Inequívocas:** corrigidas em todos os `.md` da raiz pelo aplicador determinístico versionado `scripts/Repair-PtBrAccentDegradation.ps1` (contraparte do detector; reusa lista, regex e supressão de código; preserva caixa, EOL LF e UTF-8 sem BOM). O total do repositório caiu de 7.812 para 2.535 inequívocas; na raiz, de 5.304 para 0 reais — o resíduo medido na raiz (43) são apenas os exemplos degradados de propósito deste `999` e do `998`.
- **Tokens ambíguos:** `so`→`só` (verificado: nenhum «so» inglês na prosa pt-BR; as duas ocorrências inglesas em `README`/`CHANGELOG` foram excluídas), `numero`→`número` (substantivo) e `esta`→`está` decididos linha a linha (verbo vira `está`; demonstrativo «esta base/família/frente/seção/raiz» permanece). `tem`/`vem` no singular permanecem.
- **`e/é` — molduras de alta precisão** aplicadas por serem determinísticas: `não e`, `qual e`, `(esta|este|esse|essa|isso|isto) e`, `e:`. A **cópula geral** (`<sujeito> e <predicado>`) **não** é coberta: o detector não a mede, a forma colide com a conjunção e o risco de regressão é alto. Fica como **dívida documentada**; só o `02-regras-operacionais-e-runtime.md` recebeu a cópula completa (caso-modelo, com âncoras verificadas a mão).

Endurecimentos do instrumento (detector + lista curada), feitos nesta frente:

- **Demoção de 7 formas verbais** de `entries` para `ambiguousTokens`: `analise`, `calculo`, `especifico`, `especifica`, `pratico`, `pratica`, `modulo` — são substantivo/adjetivo acentuado **e** flexão verbal válida sem acento (mesma natureza do `numero` já demovido antes). Motivador: o aplicador trocou uma forma imperativa («analise o impacto») por «análise» no `AGENTS.md`, revertido. Os plurais (`especificos`/`especificas`/`modulos`) permanecem no piso firme. Há guard no self-test travando a regressão.
- **Consciência de seção pt-BR** no detector e nos aplicadores (`Get-PtBrLineCount`/`Get-PtBrText`): em arquivos trilíngues (PT/ES/EN — `README`, `CHANGELOG`, `CODE_OF_CONDUCT`, `SECURITY`, `CONTRIBUTING`), só a faixa pt-BR (até o primeiro cabeçalho `## Español`/`## English`) é medida e editada. Motivo: várias entradas colidem com **espanhol** válido sem acento (`repositorio`, `usuario`, `criterio`, `experiencia`, `existencia`, `transferencia`); a lista, vetada apenas contra inglês, corrompeu o espanhol antes do fix (revertido e reaplicado só à faixa pt-BR). O self-test ganhou golden multilíngue (18 asserts no total).

Pendente (frentes separadas, fora do «maior retorno = raiz» desta sessão): `skill-md` (~1.396), comentários de `.ps1` (~786), `outros-md` (~211) e `.example.ps1` (~98). A cópula geral `e/é` permanece como dívida em toda a base.

### Execução 2026-06-11 (continuação: `skill-md`, `skill-satelite`, `outros-md` concluídos)

Sessão seguinte, mesmo dia, partindo do mapa regenerado pelo detector. Resultado e decisões:

- **Inequívocas:** o aplicador determinístico `scripts/Repair-PtBrAccentDegradation.ps1` corrigiu 1.608 ocorrências nos 7 `.md` com defeito (`xpz-kb-parallel-setup/SKILL.md` 1.380, `scripts/README-kb-intelligence.md` 208, `xpz-msbuild-build`/`xpz-msbuild-import-export` 6 cada, `xpz-sync` 4, `scripts-maintenance/README.md` 3, satélite `transaction.md` 1). Total do repositório caiu de 2.549 para 941 inequívocas (o resíduo são `ps1`/`example-ps1` + os 43 exemplos propositais da raiz neste `999` e no `998`).
- **Ambíguas (85, decididas linha a linha com o usuário):** uniformes — `so`→`só` (42; as 2 de `transaction.md` são **inglês** e ficaram), `especifico`→`específico` (12), `especifica`→`específica` (4), `analise`→`análise` (2, ambas substantivo); posicionais — `esta`→`está` (24 casos-cópula, ex.: «está pronta/apto/limpa/disponível/fora do escopo») e `tem`→`têm` (1, plural «motores diferentes têm contratos» em `xpz-kb-parallel-setup/SKILL.md:972`). Preservados: `vem` e `tem` no singular, todos os `esta` demonstrativos («esta skill/seção/regra»), e o `so` inglês de `transaction.md`. Aplicadas por aplicador transitório em `work/` (git-ignored) que reusa boundary, supressão de código e faixa pt-BR do detector; `esta`/`tem` por âncora (linha + predicado), nunca por troca cega.
- **Estado dos segmentos `.md`:** `skill-md`, `skill-satelite` e `outros-md` ficaram com **0 inequívocas e 0 ambíguas-defeito**; o resíduo ambíguo medido nesses segmentos (104+5+3) são demonstrativos/singulares/inglês corretos, não defeito.

Pendente após esta continuação (estado **ao fim da continuação 1**, superado pela continuação 2 abaixo): comentários de `.ps1` (800 inequívocas + 125 ambíguas) e `.example.ps1` (98 + 9). À época, o aplicador `Repair-PtBrAccentDegradation.ps1` ainda rejeitava não-`.md` por construção, e atacar `.ps1` exigiria um aplicador irmão que operasse **apenas** comentários (`#` de linha e `<#…#>` de bloco), reusando a mesma lista/regex e a detecção de comentário do detector — **resolvido na continuação 2** (commit `8633225`), que estendeu o próprio Repair para `.ps1` via tokenizer. A cópula geral `e/é` segue como dívida em toda a base.

### Execução 2026-06-11 (continuação 2: comentários `.ps1` e `.example.ps1` concluídos)

Mesma sessão. Aplicador **tokenizer-based** (tokens `Comment` do PowerShell, offset exato — nunca toca código nem strings; mais seguro que o split-por-`#` do detector). Decisões:

- **Inequívocas:** 802 corrigidas em 138 arquivos (`example-ps1` zerado; `ps1` reduzido). Parse dos 200 scripts: 0 erros; self-test do detector: OK; EOL LF preservado.
- **Ambíguas (68 de 108, decididas linha a linha):** uniformes `so`→`só` (34; 1 `so` **inglês** em `Test-PyScriptsParse.ps1:8` ficou), `módulo` (8), `específico` (3), `cálculo` (2), `número` (2), `prática` (1) — as 4 formas demovidas e `especifico` apareceram **todas** como substantivo/adjetivo nos comentários; posicionais `esta`→`está` (16), `tem`→`têm` (1 em `Start-OpenCodeJob.ps1:66`), `vem`→`vêm` (1 em `Test-XpzGlobalInstructionsSelfTest.ps1:15`). Preservados: `tem`/`vem` singular, `esta` demonstrativo.
- **3 arquivos do próprio instrumento** (`Measure`/`Repair`/`Test-Measure…SelfTest`): tratados à parte por misturarem prosa degradada e **citações ASCII deliberadas**. Corrigida só a prosa clara de `Measure` (27) e `Repair` (15); **preservadas** as citações — 6 palavras-exemplo de colisão com espanhol (`repositorio/usuario/criterio/experiencia/existencia/transferencia`), id de segmento `historico`, token-exemplo `"nao."`, exemplos de caixa `NAO -> NAO`/`Padrao -> Padrao`. O `Test-Measure…SelfTest.ps1` (quase só citações de golden, ex.: `# L1 funcao,nao (2)`) ficou **intacto** — análogo aos 43 resíduos propositais da raiz no `999`/`998`.

Resíduo medido após esta etapa (tudo correto-a-permanecer): `ps1` 66 inequívocas + 52 ambíguas = self-test intacto (~36) + 18 conteúdo de **string** (mensagens/fixtures/doc gerada, falso-positivo do detector pelo `#`) + citações preservadas de Measure/Repair + singular/demonstrativo. **Dívida remanescente:** a cópula geral `e/é` em toda a base, e os textos pt-BR dentro de **strings** de `.ps1` (ex.: mensagens `-Message "...nao..."`, doc gerada por `generate-kb-*`) — fora do escopo "comentários" desta frente.

### Frente derivada — detector de `e/é` por molduras de alta precisão (proposta 2026-06-11)

**Origem:** pergunta do usuário ao fim da frente de acentuação — vale uma ferramenta que um agente rode a qualquer tempo para conferir erros que **mudam o sentido**, em especial `e`↔`é`? O detector `Measure-PtBrAccentDegradation.ps1` já sinaliza `esta/tem/vem/so/numero` + formas verbais (teto solto), mas **não** mede `e/é`: a conjunção «e» é válida e ubíqua, então uma lista simples geraria falso-positivo em massa (motivo documentado na `ptbr-accent-wordlist.json`).

**Ideia:** detector consultivo dedicado que cobre só o **subconjunto determinístico** onde «e» é quase certamente «é» — as **molduras de alta precisão** já validadas a mão na frente da raiz: `não e`→`não é`, `qual e`→`qual é`, `(esta|este|esse|essa|isso|isto) e`→`… é`, `e:` em fim de oração, e análogas a calibrar. Pega o mais perigoso com ruído baixo; **não** cobre a cópula geral `<sujeito> e <predicado>` (essa permanece dívida que exige julgamento humano/LLM). Cobertura **parcial e honesta** por construção.

**Decisões de design em aberto:**
- Ferramenta avulsa (`Measure-`/`Test-` irmão, com self-test e mapa em `work/`) **vs.** gate consultivo integrado ao `Invoke-PrePushMechanicalChecks.ps1`. Se virar gate, exige paridade em `13` (lista de gates do orquestrador), `09` e possivelmente `08`.
- Aplicador opcional (corrigir as molduras) ou só detector (sinalizar para revisão).
- Calibração das molduras contra o corpus real (medir falso-positivo antes de promover a gate — falso-positivo em gate destrói a confiança).

**Por que ficou para frente dedicada (e não no push da acentuação):** a frente de acentuação não usou `e/é` (dívida assumida); construir antes do push invalidaria o painel reforçado já convergido e misturaria escopos. Ferramenta ortogonal → frente própria, idealmente em sessão de contexto limpo. Ver a dívida no parágrafo acima.

## Síntese operacional pós-build — descoberta de URL/hosting da aplicação gerada

**Importância:** média
**Maturidade:** ideia

**Origem:** relato de agente em pasta paralela `C:\Dev\Test\Gx_wsEducacaoSpTeste` em 2026-05-17. Após build bem-sucedido, o agente precisou descobrir manualmente como abrir a aplicação gerada, com caminhos diferentes por generator.

### Problema concreto que motiva a ideia

Build bem-sucedido gera aplicação acessível, mas o caminho para abrir varia por generator/environment e não é exposto pela skill `xpz-msbuild-build`. Casos relatados:

- **NETPostgreSQL / .NET Core**:
  - web dir: `C:\KBs\wsEducacaoSpTeste\NETPostgreSQL155\web`
  - hospedagem: `dotnet GxNetCoreStartup.dll` self-host
  - URL: `http://127.0.0.1:50155`

- **NETFrameworkSQLServer / .NET Framework**:
  - web dir: `C:\KBs\wsEducacaoSpTeste\NETFrameworkSQLServer004\web`
  - hospedagem: IIS
  - virtual directory em `applicationHost.config`: `/wsEducacaoSpTesteNETFrameworkSQLServer`
  - URL: `http://localhost/wsEducacaoSpTesteNETFrameworkSQLServer/wwescola.aspx`

A informação existe no ambiente (estrutura de pastas da KB, `applicationHost.config` do IIS) mas o agente precisa reconstruí-la manualmente.

### Direção de implementação

Etapa complementar ao classificador principal de `xpz-msbuild-build`, **não parte dele**. Sugestão de wrapper novo: `scripts/Get-GeneXusRuntimeLaunchInfo.ps1`, retornando JSON com:

- `activeEnvironment` — nome do environment ativo
- `generatorType` — `dotnet-self-host` ou `iis` ou `unknown`
- `webOutputDirectory` — caminho absoluto do diretório `web` gerado
- `hostingStrategy` — string descritiva
- `probableUrl` — URL provável (para self-host: porta do `appsettings.json`; para IIS: virtual directory + entrypoint padrão)
- `entrypoints` — lista de entrypoints conhecidos no `web` (ex.: `developermenu.html`, `wplogin.aspx`, e qualquer objeto web identificado por triagem)

### Escopo recomendado para primeira versão

Cortar pelo caso mais simples primeiro: **só `dotnet self-host`**. IIS exige ler `applicationHost.config` (caminho pode variar, ACL pode bloquear leitura sem elevação) — superfície grande para uma primeira entrega. Adicionar IIS em segunda iteração, somente se houver caso concreto.

### Decisões em aberto

- Onde reside a porta canônica do self-host: `appsettings.json`, `web.config`, ou arquivo gerado pelo build?
- O wrapper deve invocar o runtime para validar que a URL responde, ou só inferir? (Inferir é mais barato e não acopla a wrapper a estado do host.)
- Integração com `Test-GeneXusRuntimeFreshness.ps1` (que verifica frescor do runtime, não descobre URL): coordenação ou independência?

### Relacionado

- `scripts/Test-GeneXusRuntimeFreshness.ps1` — verifica frescor, não cobre descoberta de URL.
- Skill `xpz-msbuild-build` — classificador de build atual, foco no resultado da compilação, não no acesso à aplicação gerada.

## Sinalização de snapshot paralelo defasado após import real

**Importância:** média
**Maturidade:** ideia

**Origem:** relato de agente em pasta paralela `C:\Dev\Test\Gx_wsEducacaoSpTeste` em 2026-05-17. Após importar `Domain DasNeves` via MSBuild na KB nativa `C:\KBs\wsEducacaoSpTeste`, a pasta paralela (`ObjetosDaKbEmXml/` e índice `KbIntelligence/`) permaneceu refletindo o último XPZ full materializado anterior à importação.

### Problema concreto que motiva a ideia

Import real bem-sucedido muda a KB nativa, mas:

- `ObjetosDaKbEmXml/` na pasta paralela só reflete a mudança após novo export/sync/materialização
- `KbIntelligence/` (índice SQLite) idem
- Triagem por índice continua "cega" para o objeto recém-importado até nova materialização

Isso não é erro do wrapper de import — é uma **lacuna de handoff** entre `xpz-msbuild-import-export` e `xpz-sync`/`xpz-doc-builder`. O risco é o usuário (ou outro agente em sessão seguinte) consultar o índice e concluir erroneamente que o objeto não existe.

### Direção de implementação

Ao concluir `Invoke-GeneXusXpzImport.ps1` com sucesso real (import efetivado), enriquecer o JSON de saída com campos de sinalização:

- `kbNativeChanged: true`
- `parallelSnapshotStale: true`
- `importedItems: ["Domain:DasNeves", ...]` (já planejado pela ideia de pós-processamento resiliente)
- `suggestedNextSyncScope: "importedItems"` (sugere escopo mínimo de re-sync, não sync total)
- `parallelSnapshotPath` e `kbIntelligenceIndexPath` quando inferíveis do `kb-source-metadata.md`

A skill **sinaliza**, não **automatiza**. O re-sync continua sendo responsabilidade explícita de `xpz-sync` invocado em frente separada. Acoplar import a sync aumentaria superfície e blast radius do wrapper de import.

### Critério de aceite

Após import real bem-sucedido na KB nativa, o JSON do wrapper precisa expor de forma máquina-legível que (a) houve mudança efetiva na KB nativa, (b) o snapshot paralelo desta pasta está defasado, (c) quais objetos foram importados. O agente seguinte deve conseguir tomar decisão de re-sync apenas lendo esse JSON, sem inspecionar manualmente a KB nativa.

### Decisões em aberto

- Onde fica a inferência de `parallelSnapshotPath`/`kbIntelligenceIndexPath`: dentro do wrapper de import (leitura de `kb-source-metadata.md`) ou em camada separada?
- Comportamento quando o wrapper rodar **fora** de pasta paralela conhecida (caso de uso direto na KB nativa, sem snapshot paralelo): omitir os campos ou marcar `parallelSnapshotKnown: false`?
- Coordenação com a ideia de pós-processamento resiliente (Problema 2): os dois mexem no contrato de saída do mesmo wrapper, melhor consolidar em uma frente.

### Relacionado

- Skill `xpz-sync` — receptora natural da próxima ação sugerida.
- `kb-source-metadata.md` — fonte canônica para localizar pasta paralela e índice.

## Auditoria de drift de identidade estável da KB

**Importância:** média
**Maturidade:** ideia

**Origem:** revisão crítica pós-fechamento da frente `Resolve-GeneXusKbIdentity` em 2026-05-20. A frente original de preenchimento de metadata vazio foi registrada em `historico/IdeiasImplementadas_202605.md`; esta é uma frente nova, limitada a auditoria de drift quando o metadata já está preenchido.

### Problema concreto

A auditoria atual detecta `kb-source-metadata.md` ausente, campos críticos vazios, GUID inválido e wrapper `Get-*KbMetadata.ps1` incapaz de expor os campos documentados. Isso cobre metadata incompleto ou quebrado.

Ela não prova, porém, que identidade preenchida e sintaticamente válida ainda corresponde à KB nativa local atual. Casos possíveis:

- GUID antigo depois de recriar, mover ou substituir a KB nativa
- `kb-source-metadata.md` copiado de outra pasta paralela
- `username` ou `UNCPath` defasados, com GUID ainda válido
- valores preenchidos manualmente no passado

Nesses casos, `Test-XpzKbMetadataWrapper.ps1` pode retornar `METADATA_WRAPPER_OK`, porque compara o wrapper contra o próprio `kb-source-metadata.md`; `Test-XpzSetupAudit.ps1` propaga essa dimensão, mas não chama `Resolve-GeneXusKbIdentity.ps1` para comparar metadata gravado contra identidade resolvida agora.

### Direção de investigação

Adicionar uma comparação somente leitura de identidade estável ao fluxo de auditoria, sem transformar `Resolve` em fallback ad hoc de `xpz-sync`, `xpz-builder` ou import MSBuild.

Alternativas a avaliar:

- estender `scripts/Test-XpzSetupAudit.ps1` para executar uma comparação read-only quando houver caminho de KB nativa local confiável
- criar gate dedicado, por exemplo `scripts/Test-XpzKbIdentityDrift.ps1`
- reaproveitar `scripts/Update-XpzKbSourceMetadataIdentity.ps1 -WhatIf` se a saída for suficientemente estável e legível para auditoria

### Critério de aceite

Uma pasta com `kb-source-metadata.md` preenchido, wrappers de metadata OK e identidade divergente da KB nativa local deve produzir finding explícito de drift de identidade. A correção automática continua proibida: preenchimento ou sobrescrita de campos deve seguir por frente aprovada de reconciliação via `Update-XpzKbSourceMetadataIdentity.ps1`.

### Relacionado

- `historico/IdeiasImplementadas_202605.md` — caso concluído de preenchimento de metadata a partir da KB nativa quando o XPZ vem com `Source` vazio
- `scripts/Resolve-GeneXusKbIdentity.ps1`
- `scripts/Update-XpzKbSourceMetadataIdentity.ps1`
- `scripts/Test-XpzSetupAudit.ps1`
- `scripts/Test-XpzKbMetadataWrapper.ps1`

## Dry-run com diff unificado padronizado em scripts de escrita XPZ

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `00ecd7d feat(worker): standardized dryRun plan with unified diff and impact seam`
- `5331ca1 feat(worker): genexus_edit returns post_state.diff by default`

Anti-duplicata: buscado em 999/998 por `dry.?run|diff unificado|post.?state|WhatIf` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado nesta sessão — detalhes finos de formato/contrato devem ser confirmados nos commits-âncora antes da implementação.

### Problema concreto que motiva a ideia

Skills que escrevem em disco — `xpz-builder` (gera `import_file.xml`), `xpz-sync` (materializa XMLs a partir de XPZ exportado), `xpz-msbuild-import-export` (consome XPZ na IDE) — hoje executam mutação sem mostrar consistentemente um plano "antes/depois" para o agente. PowerShell tem `-WhatIf` nativo, mas adoção e formato não são padronizados entre wrappers.

No FBgx18MCP, o padrão adotado é: toda escrita devolve `post_state.diff` por padrão, em formato diff unificado. O agente vê o que vai mudar antes de aplicar (ou imediatamente após, com chance de rollback declarado).

### Design em aberto

- **Formato do diff**: texto unificado linha-a-linha (universal, fácil de ler) vs XML diff por part (semântico, mais útil pra XPZ mas exige biblioteca). Escolha provavelmente varia por contexto.
- **Adoção gradual ou universal**: começar por `xpz-builder` (alto risco, escrita de pacote final), depois `xpz-sync`?
- **`post_state` ou `pre_state` + plano**: o MCP devolve `post_state.diff` após a operação real; em PowerShell faz mais sentido oferecer `-DryRun` que devolve o plano sem executar.

### Decisões em aberto

- Qual estrutura de saída adotar? JSON com campo `diff` (string), ou objeto estruturado com `added[]/removed[]/changed[]`?
- Como sinalizar quando o diff é truncado por tamanho (ver ideia "Resposta mínima por padrão" abaixo)?

### Relacionado

- `xpz-builder/SKILL.md`, `xpz-sync/SKILL.md`, `xpz-msbuild-import-export/SKILL.md`
- `02-regras-operacionais-e-runtime.md` (sede natural da regra geral)
- Ideia "Idempotência declarativa" abaixo tem sobreposição: dry-run mostra; idempotência detecta repetição.

## Idempotência declarativa em wrappers de escrita XPZ

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commit-âncora:

- `6e266ee feat(gateway): IdempotencyCache + IdempotencyMiddleware on write tools`

Anti-duplicata: buscado em 999/998 por `idempot|colis|hash do payload` em 2026-05-17. Matches encontrados foram restritos a perguntas sobre operações específicas (`RestoreModule`, `CompressKB`), não cobrem a ideia generalizada. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

A regra `Test-XpzPackageCollision.ps1` (já citada em `README.md`) é exatamente um caso particular de idempotência: chave = `NomeCurto_GUID_YYYYMMDD_nn`; em colisão, aborta e sugere próximo `nn` livre. O conceito ainda **não foi promovido a princípio operacional** aplicável a outras escritas (geração de XMLs em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, snapshots de metadados, recriação de pasta paralela).

No FBgx18MCP, `IdempotencyCache` é middleware: toda escrita declara chave por hash do payload; chamada repetida com mesma chave é no-op declarada (não silenciosa).

### Design em aberto

- **Chave canônica por contexto**: pacote = nome+nn; geração de XML = guid+lastUpdate; metadados = hash do conteúdo. Cada escrita declara sua chave.
- **Onde mora o cache**: arquivo `.idempotency.json` na pasta da frente (`NomeCurto_GUID_YYYYMMDD/`)? Tabela no `KbIntelligence/`? Em memória apenas?
- **No-op declarado vs silencioso**: usuário sabe que "rodada repetida foi detectada", não só vê sucesso silencioso.

### Decisões em aberto

- TTL/expiração do cache? Pacotes ficam por tempo indeterminado; chave de geração talvez expire por sessão.
- Como integrar com `-DryRun` (ideia anterior): dry-run também consulta a chave e reporta "essa operação já foi feita"?

### Relacionado

- `Test-XpzPackageCollision.ps1` (caso particular já existente)
- `02-regras-operacionais-e-runtime.md` (sede natural da regra)
- Wrappers candidatos: `Sync-GeneXusXpzToXml.ps1`, `xpz-builder` (geração de pacote)

## Resposta mínima por padrão + `empty_reason` + `suggested_next` em scripts de consulta

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `915750b feat(worker): minimal-by-default list shape; verbose=true opt-in`
- `2447965 feat(worker): _meta.suggested_next on list_objects`
- `35d4afc feat(worker): _meta.suggested_next on query/structure/search`
- `545ac74 feat(worker): _meta.aggregates and empty_reason on list responses`

Anti-duplicata: buscado em 999/998 por `empty_reason|suggested_next|resposta m[ií]nima|verbose` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

Os scripts `-Query` da trilha `KbIntelligence` (em `scripts/`) e a saída de `xpz-index-triage` hoje retornam estruturas razoavelmente verbosas mesmo quando o agente só precisa de uma confirmação curta. Pior: quando o resultado é vazio, **não dizem por quê**, e o agente "chuta" o próximo passo. Isso queima tokens e turnos.

No FBgx18MCP, o contrato adotado é:

- Lista vem **mínima por padrão**; `verbose=true` traz detalhes.
- Quando vazio, devolve `empty_reason` estruturado ("nenhum objeto com tipo X", "filtro Y excluiu N candidatos", etc.).
- Devolve `suggested_next`: próximo passo recomendado em forma executável (ex: `tente Get-XpzObjects -Type WebPanel sem filtro de Family`).

### Design em aberto

- **Onde aplicar primeiro**: `xpz-index-triage` é o candidato natural (vocação de triagem curta). Scripts `-Query` do `KbIntelligence` em segundo.
- **Forma do `suggested_next`**: string com comando literal? Objeto com `command`+`reason`? Lista de alternativas?
- **`empty_reason` taxonômico**: vocabulário fechado (ex: `no-matches`, `filter-too-narrow`, `index-stale`, `kb-not-resolved`) vs string livre.

### Decisões em aberto

- Como conviver com o `-Verbose` nativo do PowerShell? Provável: `verbose=true` como parâmetro próprio do contrato JSON, distinto do `-Verbose` switch.
- Output em PowerShell é "objeto" por natureza; aplicar literalmente "resposta mínima por padrão" exige `Select-Object` por padrão e `-Full` opt-in.

### Relacionado

- `xpz-index-triage/SKILL.md`
- `scripts/README-kb-intelligence.md`
- `02-regras-operacionais-e-runtime.md` (regra geral de contrato de saída)

## Did-you-mean / sugestão por edit-distance em erros de parâmetro de scripts XPZ

**Importância:** baixa
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commit-âncora:

- `8218122 feat(gateway): genexus_whoami MCP tool, edit schema validation with did-you-mean, GeneXus version check`

Anti-duplicata: buscado em 999/998 por `did.?you.?mean|fuzzy|edit.?distance` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

Scripts PowerShell que recebem `-Type`, `-Family`, `-Name` ou outros enums frequentemente falham com erro genérico ("parâmetro X não é válido") quando o agente passa valor próximo do correto ("Transactioon" em vez de "Transaction"). O agente então gasta turno experimentando variações.

No FBgx18MCP, o validador de schema de `genexus_edit` calcula edit-distance contra valores conhecidos e sugere o termo provável ("did you mean: ...").

### Design em aberto

- **Dicionário-fonte por parâmetro**: enum hardcoded? Lê do índice (`KbIntelligence/` para nomes de objeto)? Mix?
- **Threshold de edit-distance**: 1, 2, ou proporcional ao tamanho?
- **Onde aplicar primeiro**: parâmetros com domínio fechado e pequeno (`-Type`) trazem mais benefício; `-Name` contra catálogo de 15k objetos é caro e talvez fora de escopo.

### Decisões em aberto

- Implementação: helper compartilhado em `scripts/_lib/` ou cópia por script?
- Comportamento: continua erro fatal com sugestão, ou erro recuperável "vou usar X?". Provavelmente erro fatal — não deduzir.

### Relacionado

- Wrappers candidatos: qualquer um que valide enums (build, sync, import-export, triage)

## Pré-push: reduzir dependência de interpretação em `.md` (opções B e C)

**Importância:** média
**Maturidade:** ideia — **reavaliar** após a frente pré-push estabilizada em produção (orquestrador + regra em camadas + satélites) e mais um ciclo de testes com prompt mínimo («executar rotina pré-push»).

**Origem:** conversa em 2026-05-22. Testes com Codex, Claude e Cursor no mesmo intervalo (22 commits): o orquestrador alinhou fatos (git, parse, `PUSH_READINESS`), mas gaps documentais divergiram (1 vs 5) conforme a profundidade da leitura semântica de `.md`. Conclusão: `Invoke-PrePushMechanicalChecks.ps1` resolveu risco **operacional**, não risco **editorial/semântico** completo.

### Modelo vigente (opção A — adotado, não é pendência)

- **Mecânico:** `scripts/Invoke-PrePushMechanicalChecks.ps1` + parse global (`Test-PsScriptsParse.ps1`).
- **Semântico:** agente lê `AGENTS.md` / `08`, busca cruzada, relatório (gaps / flags descartados / não coberto), sem auto-gravação.
- **Humano:** aprova correções e push; segundo agente ou segunda passagem em frentes grandes quando fizer sentido.

Não substituir A por B ou C sem evidência de que o custo de manutenção compensa.

### Opção B — lints mecânicos pontuais (scripts de coerência documental)

Heurísticas em `.ps1` (ex.: `Test-DocContractCoherence.ps1` ou extensão do orquestrador) para casos recorrentes já vistos na pré-push, sem NLP:

- satélite de checklist (`quality-checklist.md`) desalinhado de termos obrigatórios no `SKILL.md` da mesma skill;
- skills que citam `Build-GeneXusImportFileEnvelope.ps1` sem mencionar `-AcervoPath` / `-ModifiedObjectNames` / `-ModifiedObjectGuids` no mesmo arquivo (handoff MSBuild);
- scripts novos em `scripts/` no intervalo ausentes de `09-inventario-e-rastreabilidade-publica.md` (se a política do inventário for mantê-lo atualizado);
- opcional: `README.md` trilíngue citando helper sem parâmetros que `02`/`08` já tornaram obrigatórios (alto risco de falso positivo por ser resumo).

**Prós:** menos variância entre agentes nos mesmos gaps; falha/warning objetivo. **Contras:** cada regra vira dívida de manutenção; falsos positivos; não cobre nuances (ex.: cross-ref WWP em `02`).

### Opção C — contrato machine-readable paralelo ao `.md`

Schema (JSON/YAML) com parâmetros obrigatórios por script, satélites obrigatórios por skill, entradas de inventário — consumido por lint/CI e, no futuro, por agentes.

**Prós:** verificação determinística de contrato. **Contras:** duplicação com prosa em `SKILL.md`/`02`; custo alto de adoção e sincronização; só vale se várias ferramentas consumirem o mesmo schema.

### Gatilho sugerido para reavaliar B ou C

- Repetição do mesmo gap semântico em duas pré-push seguidas **depois** de endurecer `AGENTS.md` (handoff, README, `09`).
- Ou decisão explícita de fechar frente editorial (ex.: `quality-checklist` + `xpz-msbuild-import-export`) e medir se ainda há divergência entre agentes.

### Relacionado

- `scripts/Invoke-PrePushMechanicalChecks.ps1`, `AGENTS.md` (Revisão pré-push), `08-guia-para-agente-gpt.md`
- Gap **fechado** (2026-05-22): `xpz-builder/quality-checklist.md` vs `xpz-builder/SKILL.md` (`lastUpdate` / `-AcervoPath`) — alinhado nos commits `1e17d5d`, `7fa279a` e `46cfe30`; pré-push semântica do mesmo dia não reabriu o item. A heurística da opção B (checklist vs `SKILL.md`) permanece como candidata a lint, não como pendência aberta.

## Ciclo de friction-report datado como motor de evolução das skills XPZ

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora (mostram o ciclo):

- `0a5214b perf+fix(v2.3.5): preventive perf audit + friction-report 2026-05-14 sweep`
- `5296f75 fix(v2.3.5): second pass on friction-report 2026-05-14 (#2 #3 #4 #5 #11 #14 #15 #16 #17)`
- `0a673b3 fix(worker,gateway): close 8 items from mcp-friction-report-2026-05-13`
- `e10d382 fix(mcp): address 5 friction items from session report`

Anti-duplicata: buscado em 999/998 por `friction|fric[çc][ãa]o|relat[óo]rio de uso` em 2026-05-17, sem match.

### Problema concreto que motiva a ideia

O repo já tem `999-ideias-pendentes.md` (backlog de ideias estruturadas) e `998-ideias-descartadas-e-porque.md` (memória de não-fazer). O que falta é o **artefato datado de fricção observada em uso real** — separado do backlog conceitual. Esse artefato faz a ponte uso real → backlog → fix.

No FBgx18MCP, o padrão é: cada release significativa tem um `mcp-friction-report-YYYY-MM-DD.md` listando itens numerados. Commits posteriores referenciam explicitamente "closes #3 #4 #5 from friction-report-YYYY-MM-DD". Essa rastreabilidade dá ao mantenedor visão de "quanto da fricção observada virou fix".

### Design em aberto

- **Pasta sede**: `historico/friction-reports/`? Raiz com prefixo numérico (ex: `13-friction-reports/`)?
- **Esquema**: itens numerados, severidade (baixa/média/alta/bloqueante), origem (sessão, skill, contexto), estado (aberto/fechado), commit que fechou.
- **Quem captura**: o agente, ao final de sessão complexa, propõe entradas? O usuário, manualmente? Híbrido?
- **Relação com 999**: itens de friction-report viram entradas em 999 quando exigem design, ou ficam só no report quando são fix mecânico?

### Decisões em aberto

- Política de captura: oportunista (quando lembra) vs sistemática (toda sessão fecha com pergunta "houve fricção?").
- Histórico longo: quando arquivar reports antigos.

### Relacionado

- `998-ideias-descartadas-e-porque.md`
- `999-ideias-pendentes.md`
- `historico/` (sede candidata)

## Comandos `doctor` e `whoami` para `xpz-skills-setup`

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `c464165 feat(cli): onboarding UX — auto-discovery, whoami, uninstall, kb catalog + docs`
- `8218122 feat(gateway): genexus_whoami MCP tool, edit schema validation with did-you-mean, GeneXus version check`

Anti-duplicata: buscado em 999/998 por `doctor|whoami` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

A skill `xpz-skills-setup` já audita o registro de skills XPZ cross-tool (Claude/Codex/Cursor/OpenCode) e oferece resolução de gaps. Faltam dois comandos irmãos com utilidade alta:

- **`doctor`**: verifica saúde do ambiente — frescor do índice (`last_index_build_run_at` vs `last_xpz_materialization_run_at`), drift documental local, `GATE_OK` semântico, existência de skills em todas as ferramentas registradas. Devolve relatório taxonômico (`ok/warn/err`).
- **`whoami`**: lista quais skills XPZ estão ativas neste host, em qual ferramenta, apontando para a fonte (caminho do symlink/junction). Útil quando o usuário tem múltiplas instalações ou faz troubleshooting.

### Design em aberto

- **Forma**: scripts `.ps1` em `xpz-skills-setup/`, ou novos verbos da skill?
- **Saída**: JSON estruturado por padrão (consumível por agente) com formatação humana opcional.
- **`doctor` cobertura**: começa enxuto (registro de skills + frescor do índice) e cresce por demanda; tentar cobrir tudo de uma vez é armadilha.

### Decisões em aberto

- Onde ficam os checks individuais? Funções em `xpz-skills-setup/_lib/` agregadas pelo `doctor`?
- Integração com regra do `AGENTS.md` global sobre "auditoria pós-git-pull" — `doctor` é o canal natural.

### Relacionado

- `xpz-skills-setup/SKILL.md` (sede principal)
- Regra "Após git pull" no AGENTS.md global do usuário

## Modo `-Async` + long-poll de status em `xpz-msbuild-build` e `xpz-msbuild-import-export`

**Importância:** baixa
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `6501de2 feat(gateway): async lifecycle build with sync fast-path for short estimates`
- `518169f feat(gateway): long-poll on lifecycle status when wait_seconds is set`
- `51bc64c feat(gateway): BackgroundJobRegistry for async job tracking`
- `ff9c38e feat(gateway): piggyback background_jobs on every response when active`

Anti-duplicata: buscado em 999/998 por `long.?poll|ass[íi]ncron|background.?job` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

`xpz-msbuild-build` e `xpz-msbuild-import-export` rodam MSBuild que pode tomar minutos em KB grande. Hoje o wrapper é síncrono — o agente fica bloqueado, e timeouts de orquestração (ex: limite de execução de comando do harness) podem abortar prematuramente.

No FBgx18MCP, build longo vira job em background; o canal MCP devolve `job_id` rápido; agente faz `Get-Status -JobId -WaitSeconds N` quando quiser, com fast-path síncrono para builds curtos estimados.

### Design em aberto

- **Heurística de fast-path**: como decidir "build curto"? Por tamanho da KB? Histórico de builds passados? Always-async com poll imediato é mais simples.
- **Sede do registry**: arquivo JSON em `Temp/` com PID + status? Process job nativo do Windows?
- **Política de cleanup**: jobs concluídos ficam por quanto tempo?
- **Cancelamento**: agente pode pedir kill do job? Provavelmente sim, com gate.

### Decisões em aberto

- PowerShell tem `Start-Job` nativo, mas estado vive na sessão. Para sobreviver a fim de sessão, precisa de wrapper baseado em processo + arquivo de estado.
- Como integrar com a regra "operação concluída, pendente de confirmação funcional" do classificador atual.

### Relacionado

- `xpz-msbuild-build/SKILL.md` (sede principal)
- `xpz-msbuild-import-export/SKILL.md`
- `scripts/Invoke-GeneXusKbBuildAll.ps1` e equivalente de import

## Catálogo semântico de operações em `xpz-builder` (alternativa a edição XML livre)

**Importância:** média
**Maturidade:** ideia (primeira operação materializada)

**Atualização (2026-06-08, Frente C):** a primeira operação do catálogo foi **materializada** — `scripts/Add-GeneXusButton.ps1` adiciona botão a `WebPanel` (forma `<action>`/`<ucw>`, inserção em tabela Flex após controle folha nomeado, stub de `Event`, bump de `lastUpdate`, fail-closed `RESPONSIVE_UNSAFE`); regressão em `scripts/Test-GeneXusAddButtonContract.ps1`. O restante do catálogo (outras operações e tipos) permanece ideia.

**Atualização (2026-06-09):** o `Add-GeneXusButton.ps1` ganhou a âncora simétrica `-BeforeControlName` (insere a nova `<cell>` **antes** da célula do controle folha; mutuamente exclusiva com `-AfterControlName` via parameter sets). Reusa toda a validação fail-closed existente (folha, `RESPONSIVE_UNSAFE`, unicidade) sem alteração; o primitivo `Invoke-GeneXusXmlLiteralPatch` em `GeneXusXmlSurgicalEditSupport.ps1` ganhou o modo `InsertBefore`. Permanecem ideia, neste mesmo helper: âncora por tabela nomeada / inserção como última célula, célula não-folha e reescrita segura de `responsiveSizes` em Responsive preenchido.

### Desdobramentos derivados (registrados em 2026-06-09, sem código)

Ao avaliar "outros tipos poderiam ter inserção como o botão", separar duas camadas — a generalização barata (mesmo modelo estrutural) das operações de tipo diferente (cada uma é frente própria):

- **`Add-GeneXusControl` — generalizar o botão para outros controles do mesmo modelo de célula de WebPanel/Panel.** O `Add-GeneXusButton` já resolve a parte difícil: subir ao `<cell>` folha do controle-âncora, validar folha, aplicar a guarda `RESPONSIVE_UNSAFE`, delimitar a célula literal, checar unicidade e aplicar `InsertBefore`/`InsertAfter`. Para inserir um `textblock`, um controle de atributo/variável, uma imagem etc., **só muda o snippet da `<cell>`** — toda a navegação e o fail-closed se reusam. O botão é um caso particular. Desenho provável: extrair a máquina comum (resolução de âncora + validação + patch) e parametrizar o corpo da célula por tipo de controle, mantendo `Add-GeneXusButton` como atalho fino por cima. Custo baixo, alto valor; candidato natural ao próximo passo do catálogo no eixo WebPanel.
- **Expor `InsertBefore` no wrapper geral `Edit-GeneXusXmlSurgical.ps1`.** Hoje o wrapper geral (edição de `Source`/`Rules`/`CDATA` de **qualquer** tipo) só expõe `Replace`/`InsertAfter` por `ValidateSet`, embora o primitivo `Invoke-GeneXusXmlLiteralPatch` já aceite `InsertBefore` (subconjunto intencional documentado em comentário no `Invoke-GeneXusXmlSurgicalEditCore`). Expor `InsertBefore` ali é uma adição pequena e **agnóstica a tipo**, beneficiando todos os tipos de uma vez. Só fazer quando houver caso de uso concreto de "inserir antes de uma âncora literal" fora do botão (evitar superfície especulativa); ao fazer, propagar contrato/doc do wrapper (`.PARAMETER EditMode`, `08`, `xpz-builder/SKILL.md`, exemplo e teste de contrato).
- **Operações semânticas para tipos de modelo diferente (Transaction, Procedure, Grid, SDT).** Já previstas acima neste mesmo verbete (`Add-XpzAttributeToTransaction`, `Set-XpzTransactionProperty`, `Add-XpzVariableToProcedure`). A máquina do botão **não** transfere: níveis/atributos/`Rules` de Transaction, `Source`/`Variables` de Procedure, colunas de Grid têm navegação e invariantes próprios, e um insert ingênuo ali é **mais** arriscado (chaves estrangeiras, subtype groups, ordem de nós) — exigem design de invariantes e fail-closed dedicados, um helper por vez com seu próprio teste. Não derivar do botão por analogia.

### Âncora por tabela nomeada / inserir como última célula (`-TableName`) — para retomar em outra sessão

**Maturidade:** ideia (avaliada em 2026-06-09; sem código). **Onde entraria:** `scripts/Add-GeneXusButton.ps1`, como um terceiro parameter set (ex.: `LastCellOfTable`) ao lado de `After`/`Before`, recebendo `-TableName` em vez de um controle-âncora.

**O que é:** hoje `Add-GeneXusButton` só ancora em **controle folha nomeado** (`-AfterControlName`/`-BeforeControlName`) e insere a nova `<cell>` ao lado da célula desse controle. Falta a forma "insira como **última célula** de uma **tabela nomeada**", em que a âncora é a própria `<table controlName="X">`, não um controle dentro dela. (Citada no relato/avaliação original como "última célula de uma tabela nomeada".)

**Por que NÃO é simétrica ao `-Before`/`-After` (foi o que tornou aqueles baratos):** em `-Before`/`-After` a âncora é um controle **único e determinístico**; o script sobe dele até a `<cell>` folha (`ancestor-or-self::cell[1]`), valida e insere ao lado. Em `-TableName` a âncora é a tabela, e "última célula" é **ambíguo e estrutural**. Três armadilhas concretas:

1. **"Última célula" é ambíguo em tabela com linhas.** A estrutura é `table > row > cell`. Em tabela Flex sem `row` explícito, "última célula" é clara. Mas com várias `<row>`, "última célula" pode significar (a) última célula da última linha, (b) **nova** célula numa nova linha ao final, ou (c) última célula de uma linha específica. Precisa de decisão de contrato explícita antes de codar — `-Before`/`-After` nunca enfrenta isso porque a âncora já é uma célula concreta.
2. **Filhas diretas vs. aninhadas.** "Última `<cell>` filha **direta** da tabela X" exige distinguir `table[@controlName=X]/row/cell` das células de tabelas **aninhadas** dentro dela. Um `LastIndexOf('</cell>')` ingênuo no texto pegaria o fechamento de uma célula aninhada profunda, não o da última célula de topo. Tem que navegar estruturalmente (ex.: `//table[@controlName='X']/row[last()]/cell[last()]`, ou o equivalente quando não há `row`) e só então mapear de volta ao texto literal para o patch — mais frágil que o caminho atual, que ancora num `controlName` único e já validado.
3. **A guarda de Responsive fica mais nervosa.** Inserir "ao final de uma tabela" é exatamente onde mais se mexe no array `responsiveSizes` (a última posição costuma ser a descrita por último nos breakpoints). O fail-closed `RESPONSIVE_UNSAFE` continua valendo, mas o caso de uso "real mais comum" cairia nele quase sempre — ou seja, entregaria **pouco valor** sem a reescrita de breakpoints, que é justamente o que a skill recusa por design. Não acoplar este item à reescrita de `responsiveSizes`.

**Como atacar (esboço, quando houver demanda):** reusar a máquina já existente do helper — guarda `RESPONSIVE_UNSAFE`, validação de folha da célula-alvo, derivação da âncora literal e checagem de unicidade, patch via `Invoke-GeneXusXmlLiteralPatch` (com `InsertAfter` sobre a **última célula** encontrada). O trabalho novo é só: (i) resolver a tabela por `controlName` (incluindo o caso de tabela aninhada com mesmo nome → tratar como `ANCHOR_NOT_UNIQUE`), (ii) localizar estruturalmente a última `<cell>` filha **direta**, (iii) **decidir e documentar** qual semântica de "última" o contrato adota (recomendado começar pelo caso simples: tabela Flex de uma linha, sem `row` explícito, e recusar fail-closed os casos com múltiplas `<row>` até haver decisão — `MULTIROW_AMBIGUOUS` ou similar). Teste de regressão espelhando `Test-GeneXusAddButtonContract.ps1`. Manter o padrão fail-closed: na dúvida estrutural, abortar com código próprio em vez de adivinhar a posição.

**Relacionado:** `scripts/Add-GeneXusButton.ps1` (sede), `scripts/GeneXusXmlSurgicalEditSupport.ps1` (primitivo de patch), `scripts/Test-GeneXusAddButtonContract.ps1` (regressão), `xpz-builder/responsibilities-by-type/webpanel.md` (regra de botão). Ver também, neste mesmo verbete, o desdobramento `Add-GeneXusControl` — se ele for feito antes, esta âncora deve nascer já na máquina generalizada, não só no botão.

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `1efd0c1 feat: wire mode:ops end-to-end through gateway and worker`
- `5659cab feat(worker): SemanticOpsService catalog with attribute, rule, and generic set_property ops`
- `21a67ca feat: JSON-Patch (RFC 6902) edit mode over canonical JSON`

Anti-duplicata: buscado em 999/998 por `cat[áa]logo sem[âa]ntico|semantic.?ops|set_property` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

`xpz-builder` hoje apoia a materialização de artefatos XPZ a partir de moldes sanitizados (`01e` a `01h`). A geração inclui edição de XML cru, que tem superfície de risco grande: agente pode inserir tag malformada, atributo fora do contrato, ordem errada de elementos.

No FBgx18MCP, a evolução foi: além de edição livre, oferecer um **catálogo de operações estruturais nomeadas** (`set_property`, `add_attribute`, regras específicas por tipo de objeto). Cada operação é auditável, testável e tem schema próprio.

Para `xpz-builder`, isso significaria expor um vocabulário de operações de alto nível (ex: `Add-XpzAttributeToTransaction`, `Set-XpzTransactionProperty`, `Add-XpzVariableToProcedure`) por cima do XML, validadas contra os padrões empíricos já documentados em `01a-catalogo-e-padroes-empiricos.md`.

### Design em aberto

- **Cobertura inicial**: começar pelos tipos mais arriscados de edição cega (`Transaction` em `05-...`, `WebPanel` em `04-...`) e operações mais frequentes.
- **Forma**: cmdlets PowerShell `Verb-XpzNoun` com schema validado, ou um único `Invoke-XpzOp -Op <name> -Args @{}`.
- **Relação com moldes**: operação semântica é "molde paramétrico" — ponte natural entre `xpz-builder/responsibilities-by-type/` e este catálogo.
- **JSON-Patch RFC 6902**: o MCP também oferece edição via JSON-Patch sobre representação canônica. Para PowerShell, JSON-Patch sobre XML transformado tem custo de design alto e provavelmente fica fora do escopo inicial.

### Decisões em aberto

- Que tipos cobrir primeiro?
- Como conviver com edição livre (não eliminar — deixar como fallback para casos que o catálogo não cobre).

### Relacionado

- `xpz-builder/SKILL.md` e `xpz-builder/responsibilities-by-type/`
- `01a-catalogo-e-padroes-empiricos.md` (fonte de validação dos padrões)
- `01e-moldes-sanitizados-core.md` a `01h-moldes-sanitizados-metadados-e-artefatos.md` (insumo)

## Reclassificar `queryableByKbIntelligence` de `SmartDevicesApplication` após medição de grafo

**Importância:** média
**Maturidade:** pesquisa feita

**Origem:** fechamento da frente Evo1 / prompts externos de pasta paralela (KB com addon Smart Devices Plus, GeneXus 18 U13), 2026-05-30. Entrada no catálogo upstream em commit `1866c52`; self-test fixture Evo1 descartado em `998-ideias-descartadas-e-porque.md`.

### Problema concreto que motiva a ideia

`SmartDevicesApplication` entrou em `scripts/gx-object-type-catalog.json` com `queryableByKbIntelligence=true` por analogia a tipos com `Source` e eventos. `SmartDevicesPlus` (mesmo addon) ficou com `queryableByKbIntelligence=false` porque o motor atual só vê `Properties` — consultas semânticas vazias enganam.

Ainda **não** houve medição empírica de arestas de entrada/saída no índice para `SmartDevicesApplication` (Part dashboard embutido + `Source` com eventos). Se o grafo for zero ou irrelevante, a flag deveria ser `false` e a nota do JSON/`01a`/`scripts/README-kb-intelligence.md` alinhadas — mesmo padrão já aplicado a `SmartDevicesPlus`.

### Ideia de melhoria

Em **qualquer** pasta paralela com objetos `SmartDevicesApplication` materializados (não precisa ser Evo1):

1. rebuild do índice com motor atual;
2. contagem de arestas envolvendo objetos desse tipo (consulta ao SQLite ou script de amostra existente, ex. `scripts/Invoke-ParallelKbEnvelopeScan.ps1` + inspeção de grafo);
3. se grafo zero ou assimétrico sem relações úteis → `queryableByKbIntelligence=false` no catálogo + documentação;
4. se houver arestas reais → manter `true` e registrar evidência breve em `01a` ou `09`.

### Limiar para implementar

Implementar quando houver acesso a uma KB com addon SDP materializada **ou** quando um usuário da base reportar `who-uses`/`impact-basic` enganoso para `SmartDevicesApplication`. Não reabrir fixture Evo1 no código de teste.

## Estender `Compare-GeneXusPanelShape` a WebPanel (equivalência de shape em clone)

**Importância:** baixa-média
**Maturidade:** ideia

**Origem:** decorrência da Frente A (inspetor de shape de WebPanel, sessão 2026-06-08). O relato externo pediu o inspetor, não a comparação; por decisão explícita do usuário, `Compare-GeneXusPanelShape.ps1` permanece Panel-only. Hoje, ao receber WebPanel, o script orienta o usuário ao bloco `webpanel` de `Get-GeneXusObjectSummary.ps1` em vez de comparar.

### Problema concreto que motiva a ideia

`Compare-GeneXusPanelShape.ps1` confronta dois Panels por shape compacto (level/layout, controles, cobertura action/event) para validar equivalência antes de concluir clonagem. Para WebPanel, `xpz-builder/responsibilities-by-type/webpanel.md` já manda validar equivalência em clone (ex.: `fieldSpecifier`), mas não há confronto de shape automatizado análogo. Um `Compare` ciente de WebPanel diffaria `tables`/`tableType`, `controls`, `buttons` e `eventNames` — sinais que o bloco `webpanel` já produz.

### Design em aberto

- **Forma:** estender `Compare-GeneXusPanelShape` para despachar por tipo (Panel vs WebPanel) ou criar `Compare-GeneXusObjectShape` genérico type-aware. O nome atual sugere Panel; um genérico envelheceria melhor.
- **Sinais a confrontar no WebPanel:** `tables` (controlName+tableType+depth), `controls`, `buttons` (forma/event/caption), `eventNames`, `coverage` — reusando o bloco `webpanel` do summary, como o Compare de Panel já reusa o bloco `panel`.
- **`Read-Summary`:** hoje força `ObjectType='Panel'`; um Compare type-aware precisaria resolver o tipo real de cada lado.

### Limiar para implementar

Implementar quando surgir necessidade recorrente concreta de confrontar dois WebPanels por shape (ex.: usuário da base validando clone de WebPanel contra template e pedindo confronto automatizado). Sem essa demanda, manter Panel-only com a orientação atual — não construir superfície especulativa.

### Relacionado

- `scripts/Compare-GeneXusPanelShape.ps1` (sede; hoje Panel-only com orientação para WebPanel)
- `scripts/Get-GeneXusObjectSummary.ps1` (bloco `webpanel` — insumo pronto)
- `xpz-builder/responsibilities-by-type/webpanel.md` (validação de clone)

## Camada 3 — texto livre geral no índice KbIntelligence (captions, SQL/HTML em CDATA)

**Importância:** média
**Maturidade:** ideia (carece de desenho)

**Origem:** desmembrada da frente "Catálogo e rastreabilidade de classes CSS" (implementada e migrada para `historico/IdeiasImplementadas_202606.md` em 2026-06-10). Aquela frente afunilou de propósito uma proposta maior de "full-text geral" (SQLite FTS5) para o que tinha valor barato e imediato: classes CSS (camadas 1 e 2). A camada 3 — texto livre geral — ficou explicitamente **fora** e foi deslocada para esta entrada própria para não sair do radar junto com a entrada-mãe.

### Problema que motivaria a ideia

Há texto útil para triagem que hoje só sai por `rg` no acervo, não pelo índice: `caption`/títulos de controle, fragmentos de SQL e HTML embutidos em `CDATA` (ex.: `<Source>` de procedures, `UserControl` com `<style>`/template). Uma busca por termo literal ("onde aparece este caption?", "qual objeto tem este trecho de SQL?") não tem capacidade equivalente a `who-uses`.

### Por que não foi feita junto

- A classe CSS tinha um alvo nítido e barato (nome literal + onde é usado); texto livre geral é muito mais amplo e ambíguo (o que indexar? como evitar ruído? FTS5 muda o contrato do índice).
- Risco de inchar o índice e o contrato (`schema_version`, assinatura do extrator) sem régua de valor clara.

### O que precisa ser desenhado antes de implementar

- Escopo do que entra (captions? só SQL? HTML? todo CDATA?) e como evitar falso positivo.
- Mecanismo: FTS5 dedicado vs tabela simples de tokens vs reuso de `evidence`.
- Régua empírica de valor num corpus real (ex.: FabricaBrasil) antes de bumpar contrato.
- Não confundir com descoberta semântica por intenção (frente "LlamaIndex / LangChain + vector store") nem com fingerprint de call site.

### Relacionado

- `historico/IdeiasImplementadas_202606.md` (entrada-mãe das classes CSS, camadas 1 e 2)
- `scripts/Build-KbIntelligenceIndex.py`, `scripts/Query-KbIntelligenceIndex.py`

## Gate de coerência para `Transaction` `GenerateObject=False` — Fase 2 (nível de pacote)

**Importância:** baixa
**Maturidade:** pesquisa feita (Fase 1 implementada; Fase 2 carece de caso concreto)

**Origem:** a Fase 1 desta frente foi implementada em 2026-06-10 (gate intra-objeto em `Test-GeneXusTransactionCoherence.ps1`, finding `wwp-screen-code-on-non-generated-transaction`) e migrada para `historico/IdeiasImplementadas_202606.md`. Restou esta subfrente residual. Contexto e desenho completo (D1-D4, distinção WWP DVelop × Work With nativo, painel multi-modelo) estão no histórico.

### O que falta (Fase 2)

A Fase 1 detecta a contradição **dentro do XML da Transaction** (`GenerateObject=False` + código de tela WWP órfão em Events/Rules). A Fase 2 é a checagem de **nível de pacote**: um batch que carrega `PatternInstance WorkWithPlus*` e/ou derivados (`*WW`, `*WWDS`, `*General`, `*Prompt`, `*View`) cujo pai é uma Transaction `GenerateObject=False`. É outra natureza de análise (correlação cross-objeto no `ExportFile`, não intra-objeto), por isso seria um **script novo** (ex.: `Test-GeneXusPackageWWPCoherence.ps1`), não extensão do gate de coerência.

### Por que adiada

- A Fase 1 já dá `fail` e barra o pacote pelo sinal causal (código órfão), então a Fase 2 é diagnóstico complementar, não bloqueio adicional necessário.
- Sem um caso real onde só a correlação de pacote (sem código órfão na Transaction) quebre o import, a régua de severidade fica `padrao-gx-nao-verificado`.

### Relacionado

- `historico/IdeiasImplementadas_202606.md` (Fase 1 implementada)
- `scripts/Test-GeneXusTransactionCoherence.ps1`, `xpz-builder/wwp-packaging.md`

## Gate `procedural-in-conditions` — estender a outros tipos sem filtro de Conditions

**Importância:** baixa
**Maturidade:** pesquisa feita (Procedure implementado; outros tipos carecem de acervo com evidência)

**Origem:** a Frente A do lote CPJAPP foi **implementada em 2026-06-13** — gate type-aware `procedural-in-conditions` (`fail`) no `Test-GeneXusSourceSanity.ps1` para **Procedure** (`type 84a12160`) com a parte Conditions (`763f0d8b`) não-vazia; migrada para `historico/IdeiasImplementadas_202606.md`. Restou esta subfrente residual.

### O que falta

O gate usa um mapa extensível `objectType → partes-proibidas-não-vazias` (hoje só `Procedure→Conditions`, em `$script:ForbiddenNonEmptyParts`). Outros tipos **sem tela/filtro** poderiam ter a mesma invariante (parte Conditions sempre vazia) — candidato principal: `DataProvider`. **NÃO** estender a `Data Selector`: ele tem Conditions legítima (catch do glm no painel). Adicionar um tipo = uma entrada no mapa, trivial.

### Por que adiada

- Sem evidência empírica (nem de bug, nem de "sempre vazio") para esses tipos — o acervo FabricaBrasil consultado nem tem pasta `DataProvider`.
- Estender sem varrer um acervo que contenha esses tipos arrisca falso positivo. Régua (a mesma usada para Procedure): confirmar o GUID do tipo + 0 ocorrências legítimas de Conditions não-vazia no acervo, antes de habilitar.

### Relacionado

- `historico/IdeiasImplementadas_202606.md` (Procedure implementado, 2026-06-13)
- `scripts/Test-GeneXusSourceSanity.ps1` (mapa `$script:ForbiddenNonEmptyParts`), `scripts/Test-GeneXusSourceSanitySelfTest.ps1`

## Mensagem acionável uniforme de "frente não aberta" nos demais scripts que recebem `-FrontFolder`

**Importância:** baixa (gap de ergonomia/DX; o fluxo real — `Copy-GeneXusAcervoToFront.ps1` e o gate 9-FD `Test-GeneXusFrontAcervoDrift.ps1` — já foi tratado)
**Maturidade:** pesquisa feita (direção resolvida por painel de 4 modelos em 2026-06-13; falta decidir entre duplicação e helper compartilhado)

**Origem:** sessão 2026-06-13, relato externo (agente pulou `New-KbFront`, criou a pasta da frente manualmente e bateu no `throw` opaco do `Copy`). O caminho mínimo foi aplicado: mensagem acionável (prefixo `FRENTE_NAO_ABERTA:`, cita `-ReuseIfExists`, aponta o `New-`) em `Copy-GeneXusAcervoToFront.ps1` e em `Test-GeneXusFrontAcervoDrift.ps1` (único gate comprovadamente upstream do Copy), mais reforço documental (`xpz-builder/SKILL.md` gate 9-FD, `quality-checklist.md`). Esta entrada é o resíduo deliberadamente adiado.

### O gap

O mesmo `throw "FrontFolder nao encontrado ou nao e diretorio"` existe em **7 scripts** que recebem `-FrontFolder`. Dois já foram tornados acionáveis (Copy + drift gate). Restam **5 gates downstream**, de baixa probabilidade de serem o primeiro script chamado sem frente aberta (sempre rodam depois do populate/edição):

- `Test-GeneXusWorkWithWebApply.ps1` (9-WW)
- `Test-GeneXusBatchDependencyOrdering.ps1` (9-IDO)
- `Test-GeneXusProcedureSubPattern.ps1` (9-PSM)
- `Test-GeneXusBCDependency.ps1` (9-BC)
- `Test-GeneXusNewWritableTargets.ps1` (9-PNW)

### Decisão a fechar em sessão dedicada

(a) **Duplicar** a frase-sentinela acionável nos 5 gates restantes (≈5 linhas, zero acoplamento novo); ou (b) **extrair um helper compartilhado** (ex.: `Assert-GeneXusFrontFolderExists` em um `*Support.ps1`) consumido pelos 7 — uma única fonte de mensagem, ao custo de uma dependência nova entre scripts.

Painel dividido (2026-06-13): deepseek-v4-pro, glm-5.1 e minimax-m3 inclinaram a **não** padronizar agora (over-engineering para N pequeno; os gates são downstream — minimax sugeriu primeiro medir "quantos realmente podem ser o primeiro chamado" antes de padronizar); o subagente Opus inclinou ao **helper** por consistência e por ter confirmado que o drift gate (já tratado) roda antes do Copy. Régua sugerida: o helper só compensa se a política realmente abraçar os 7; caso contrário, aplicar a frase incrementalmente quando cada gate for tocado.

### Relacionado

- `scripts/Copy-GeneXusAcervoToFront.ps1`, `scripts/Test-GeneXusFrontAcervoDrift.ps1`, `scripts/New-GeneXusXpzFront.ps1`
- `xpz-builder/SKILL.md` (gate 9-FD), `xpz-builder/quality-checklist.md`

## Revisar a memória pessoal do agente por conhecimento que pertence às skills XPZ

**Importância:** média (conhecimento útil preso na memória de um harness/máquina não melhora as skills, que rodam em N harnesses e N máquinas)
**Maturidade:** ideia (varredura e triagem por fazer; alguns itens são claros, outros são mistos local/skill)

**Origem:** 2026-06-19. Este é um repositório de skills feitas para rodar em N harnesses (Claude Code, Codex, Cursor, OpenCode) e N máquinas; a memória pessoal de um agente **não viaja com a skill**. Conhecimento de skill registrado só na memória fica invisível aos demais consumidores e desencontra a fonte de verdade.

**A fazer (sessão dedicada):** varrer a memória pessoal do agente e migrar para a `SKILL.md`/doc/script da skill correspondente todo conhecimento **comportamental / de invocação / de limitação de adapter / de quirk operacional**, deixando na memória apenas o **genuinamente local** (hardware da máquina, preferências do usuário, estado/rastreabilidade de frentes em curso). Triar item a item — alguns são mistos (ex.: hardware local + limitação de adapter na mesma anotação). Regra de fronteira já registrada na memória do agente (`feedback_skill_knowledge_nao_vai_pra_memoria`).

**Nota:** o subconjunto da **`xpz-llm-delegate`** (adapters opencode, composição de painel) está sendo tratado na própria sessão de 2026-06-19 — não esperar esta frente para ele.
