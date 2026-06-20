# 08 - Guia para Agente GPT

## Papel do documento
operacional

## Nível de confianca predominante
medio

## Depende de
00-indice-da-base-genexus-xpz-xml.md, 01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 04-webpanel-familias-e-templates.md, 05-transaction-familias-e-templates.md, 05b-procedure-relatorio-familias-e-templates.md

## Usado por
qualquer GPT que precise consumir esta base consolidada

## Objetivo
Explicar como outro agente GPT deve consultar esta base, classificar evidencias e decidir entre gerar, exigir molde próximo ou abortar.

## Fontes consolidadas
- 26-guia-para-agente-gpt.md

## Origem incorporada - 26-guia-para-agente-gpt.md

## Papel do documento
operacional

## Nível de confiança predominante
médio

## Depende de
00-indice-da-base-genexus-xpz-xml.md, 01-base-empirica-geral.md, 02-regras-operacionais-e-runtime.md, 03-risco-e-decisao-por-tipo.md, 22-tipos-prontos-para-geracao-conservadora.md, 03-risco-e-decisao-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Usado por
qualquer agente GPT que precise responder perguntas ou tomar decisão operacional usando esta base

## Objetivo
Explicar como um agente GPT deve consultar esta base documental e como responder com prudência.
Padronizar quando avançar, quando exigir molde bruto comparável e quando abortar.

## Ordem de consulta recomendada

1. ler `00-indice-da-base-genexus-xpz-xml.md`
2. ler `02-regras-operacionais-e-runtime.md`
3. identificar o tipo alvo e checar `03-risco-e-decisao-por-tipo.md`
4. usar `01-base-empirica-geral.md` como índice mestre da serie `01` e abrir o filho empirico mais aderente (`01a` a `01h`)
5. para `WebPanel`, ler `04-webpanel-familias-e-templates.md`
6. para `Transaction`, ler `05-transaction-familias-e-templates.md`
7. para `Procedure` de relatório (nome com prefixo de relatório no acervo), ler `05b-procedure-relatorio-familias-e-templates.md`
8. ler `07-open-points-e-checklist.md` quando a resposta depender de limites conhecidos, pendencias metodologicas ou frentes ainda abertas
9. usar `09-inventario-e-rastreabilidade-publica.md` para sustentar rastreabilidade

`06-padroes-de-objeto-e-nomenclatura.md`: leitura suplementar — indicado quando a duvida envolver nomenclatura de objetos, prefixos de tipo ou comportamento de `Folder` vs `Module` no `fullyQualifiedName`.

### Fluxo curto para `Procedure` de relatório simples

1. classificar primeiro se o caso cabe em familia simples `F2` ou `F3`
2. se couber, partir de `05b-procedure-relatorio-familias-e-templates.md` como molde sanitizado canonico primario
3. separar explicitamente `Source`, `Rules` e layout antes de editar ou diagnosticar
4. tentar no máximo um corretivo estrutural curto se a primeira montagem falhar
5. escalar para XML real comparavel apenas se o caso fugir da cobertura simples, se a tentativa inicial mais esse único corretivo curto falharem, ou se aparecer sinal de dialeto/localismo da KB
6. registrar no handoff qual base está sustentando a resposta: `molde sanitizado`, `XML real da KB atual`, `XML real de outra KB` ou `hipotese`

## Escada de recursos para KBs pequenas ou novas

Quando a KB alvo for pequena ou nova e não houver XML local comparavel disponível, o agente deve seguir esta escada em ordem:

1. **`nexa` + moldes sanitizados desta base** — tentar direto, sem perguntar ao usuário; declarar qual molde foi usado.
2. **Tentativa sem compromisso** — o agente tenta com base em padrão inferido ou em evidencia de KB externa inspecionada; declarar explicitamente a fonte e o nível de confianca; se a probabilidade de acerto for avaliada como alta, apenas avisar; se for baixa, apresentar as opções ao usuário e aguardar decisão antes de gerar; em ambos os casos, exigir validação na IDE antes de importar.
3. **Pasta paralela de KB externa** — usuário indica uma pasta paralela de outra KB com `ObjetosDaKbEmXml/`; agente inspeciona o XML real dessa KB como fonte antes de gerar; registrar no handoff como `XML real de KB externa inspecionada`.
4. **Usuário cria exemplo na KB e exporta XPZ** — usuário cria o objeto na IDE, exporta o `.xpz` e o oferece ao agente; agente estuda o XPZ exportado como evidencia direta primaria antes de gerar qualquer clone ou variacao.

Regras da escada:
- Nunca pular do nível 1 para o 3 ou 4 sem tentar o nível 2 quando o caso for plausivel pelo padrão empírico desta base.
- Em qualquer nível, registrar no handoff qual base sustenta a resposta: `molde sanitizado`, `XML real da KB atual`, `XML real de KB externa inspecionada` ou `hipotese`.
- A opção 4 e a mais confiavel quando nenhuma das tres anteriores for suficiente — o próprio GeneXus e o gerador do molde canonico.

## Regra de precedencia sobre skills gerais

- quando a tarefa for de `XML`/`XPZ` nesta base, os `.md` locais da pasta do projeto tem precedencia sobre heuristicas gerais de skill
- isso não revoga a postura conservadora do skill `nexa`; apenas define que a evidencia local consolidada nesta base e a fonte mais específica desta trilha
- se houver tensao entre fluxo GeneXus geral do skill e achado empirico local desta base, o agente deve seguir a base local para decisão de `XPZ`/`XML` e manter do skill apenas a disciplina metodologica
- quando a base compartilhar uma capacidade operacional nova, isso não autoriza presumir que wrappers locais da pasta paralela da KB já a exponham; a exposicao local e decisão separada
- se o wrapper local ainda não expuser um parâmetro operacional relevante já disponível na base compartilhada, o agente deve tratar isso como oportunidade de atualizacao local, mencionar ao usuário e aguardar aprovacao explicita; não deve executar a mudanca local automaticamente
- a superficie do wrapper local também pode ficar temporariamente a frente, atras ou levemente desalinhada em relacao ao motor compartilhado efetivo daquela pasta paralela; quando a falha atingir apenas capability opcional de conferencia/comparacao, o agente deve reconhecer a divergencia wrapper/engine, rerodar sem o opcional, registrar o incidente e não promover isso automaticamente a bloqueio do sync principal
- essa tolerancia vale apenas para capability opcional isolada; se a falha atingir materialização, contrato principal do wrapper, refresh obrigatório do índice ou outra etapa central do fluxo oficial, continua sendo bloqueio operacional real
- exemplos sanitizados `.example.ps1` publicados pelas skills podem servir como referencia metodologica para reconstruir wrappers locais finais, mas não substituem o wrapper local real nem autorizam fallback automático de execução no fluxo normal
- quando wrappers locais precisarem nascer do zero no setup inicial da pasta paralela da KB, preferir adaptar os exemplos sanitizados completos da base como bootstrap técnico, em vez de improvisar wrappers curtos ou parciais
- scripts do motor com parâmetros totalmente dinâmicos por execução (ex: `Test-GeneXusImportFileEnvelope.ps1`) não requerem wrapper local — devem ser chamados diretamente pelo caminho absoluto do motor; wrapper local só se justifica quando há parâmetros estáticos da KB a encapsular
- scripts publicos desta raiz devem ser executados em `pwsh` com PowerShell 7.4 LTS ou superior; preferir a versão LTS mais recente disponível; não usar Windows PowerShell 5.1 (`powershell.exe`) como runtime desses scripts
- `scripts-maintenance/` contem ferramentas de manutencao desta base, não runtime publico das skills em pastas paralelas de KB; ainda assim, esses `.ps1` entram no parse PowerShell da base
- validar parse de scripts PowerShell com `scripts/Test-PsScriptsParse.ps1` quando a frente editar `.ps1` ou `.example.ps1`; para Python em `scripts/*.py`, usar `scripts/Test-PyScriptsParse.ps1`, que valida via AST sem gerar bytecode (`__pycache__/*.pyc`); o workflow `.github/workflows/parse-ps-scripts.yml` executa a verificacao PowerShell em CI sob `pwsh` 7.4+
- na rotina pre-push, se a intencao for comparar contra o remoto real atual, atualizar `origin/main` com `git fetch origin` antes do passo mecanico; ref inexistente (script falha) e ref existente mas desatualizada são casos distintos — a segunda pode superestimar commits pendentes
- na rotina pre-push, executar primeiro `scripts/Invoke-PrePushMechanicalChecks.ps1` em `pwsh` 7.4+ (`-AsJson` recomendado para agentes); intervalo único `origin/main..HEAD` para contagem, lista de commits, arquivos do diff e `git diff --check`
- o parse delegado (`Test-PsScriptsParse.ps1` e `Test-PyScriptsParse.ps1`) varre todo `scripts/` aplicavel e, para PowerShell, também `scripts-maintenance/`, não apenas o diff; com `commitsAhead=0` não ha diff no intervalo — alteracoes só na working tree ficam fora da análise (o script avisa contagens)
- o gate consultivo `Test-PrePushTraceabilityCoverage.ps1`, chamado pelo orquestrador mecanico, aponta riscos objetivos de rastreabilidade editorial, incluindo referencia documental a versão antiga do extrator quando `Build-KbIntelligenceIndex.py` muda `EXTRACTOR_SIGNATURE_VERSION`; aviso desse gate não substitui a busca semantica obrigatória nem autoriza concluir a pre-push sozinho
- o gate consultivo `Test-GeneXusUnexpectedCharacter.ps1`, chamado pelo orquestrador mecanico, procura caracteres Unicode inesperados em linhas adicionadas de `.md` e `.ps1`; findings são aviso para revisao humana e não substituem a fase semantica
- o gate consultivo `Test-PrePushNewTokenPropagation.ps1`, chamado pelo orquestrador mecanico, apoia a regra simetrica do passo 2 do `13`: detecta no diff termo de contrato introduzido por transicao co-localizada (ex.: novo `-ObjectList` ao lado de `-ObjectNames`/`-ObjectGuids`) e lista mencoes que ficaram só com o conjunto antigo; findings são candidatas consultivas em `agentWarnings`, não substituem a busca semantica e não disparam sem transicao co-localizada no diff
- disciplina de confronto por classe (do `13`): cada candidata do gate de propagacao recebe `mentionClass` (`prose`/`param-list-item`/`param-table-cell`/`command-example`); candidatas de `prose` admitem justificativa coletiva, mas as nao-prosa NÃO — o orquestrador as segrega no campo `nonProseVerdictRequired` e exige no `agentSemanticChecklist` um livro-razao item a item (cada uma com arquivo:linha, a lista/tabela/exemplo gemeo no outro documento e veredito gap|justificado). O gate não trunca candidatas nao-prosa (só a `prose` respeita `-MaxFindings`). Acima do limiar de nao-prosa (hoje > 5), o checklist recomenda uma segunda passada da fase semantica por modelo distinto: forcar exaustividade num único modelo confronta mas não garante veredito correto (ele pode racionalizar cada item como justificado), e a diversidade de modelo e o backstop
- o gate consultivo `Test-PrePushSharedScriptSkillCoverage.ps1`, chamado pelo orquestrador mecanico, apoia a comparacao documental do passo 3 do `13`: quando o diff altera script compartilhado (`scripts/*.ps1`/`*.py`), lista os `SKILL.md`/`quality-checklist.md` que citam esse script e não foram tocados (skill transversal), como candidatas consultivas em `agentWarnings`; não substitui a comparacao nem dispara sem script compartilhado no diff
- o gate consultivo `Test-PrePushHistoryCommitPlaceholder.ps1`, chamado pelo orquestrador mecanico, apoia o checklist de gaps do `13`: quando o diff toca `historico/*.md`, sinaliza campo `Commit:`/`PR:` com placeholder genérico (`este commit`, `este PR`, `TODO`, `TBD`, vazio ou `<...>`) em vez do hash real, como candidata consultiva em `agentWarnings`; a exceção "commit ainda não existe, sera preenchido no commit seguinte" e confirmada pelo agente, não reprovada pelo gate
- o gate `Test-PrePushMsBuildProbeDocParity.ps1` (frente MSBuild probe no diff) bloqueia o passo mecanico quando `10-base-operacional-msbuild-headless.md` ou `xpz-msbuild-import-export/SKILL.md` ficam desalinhados do motor (`GeneXusMsBuildPathContract.ps1`, `Test-GeneXusMsBuildSetup.ps1`); avisos de frase legada no diff não bloqueiam sozinhos
- o gate consultivo `Test-PrePushGateEnumerationParity.ps1`, chamado pelo orquestrador mecanico, deriva do próprio orquestrador o conjunto de gates executados e sinaliza enumeracoes na doc da rotina que ficaram como subconjunto próprio (afirmacao fechada do tipo «os gates consultivos são X e Y» que não recebeu gate novo); findings são candidatas consultivas em `agentWarnings`
- regra do conjunto enumerado: ao adicionar membro a um conjunto que o repo descreve em mais de um lugar (gates, scripts, estados, exit codes), atualizar **todas** as enumeracoes, inclusive afirmacoes fechadas; cuidado com o **furo de direcao** — buscar só o termo novo e cego a enumeracoes que citam só os membros antigos, entao buscar também a co-ocorrencia dos termos antigos
- ler `PUSH_READINESS` no relatório, não só `exit 0` do passo mecanico; com `blocked`, diff e lista de arquivos do intervalo são apenas diagnosticos
- o script mecanico não encerra a pre-push (nem `exit 0` mecanico); em seguida aplicar a busca semantica integral de `13-revisao-pre-push.md` (fonte autoritativa; `AGENTS.md` só resume), incluindo paridade motor↔documentação e regra em camadas: `SKILL.md` **e satelites** que ele referencia (ex. `xpz-builder/quality-checklist.md`), não só o `SKILL.md`
- quando a frente alterar script compartilhado, contrato metodologico, skill, checklist, nomenclatura operacional, estado, parâmetro, wrapper ou evidencia publica rastreavel, incluir `09-inventario-e-rastreabilidade-publica.md` na comparacao semantica; o `09` e um **indice de ponteiros** (1 linha por script: papel + dono normativo + validacao), entao conferir que o ponteiro aponta o dono certo e que o papel resumido confere — o detalhe de contrato vive no dono, não no `09`
- quando a frente tiver impacto publico (comportamento, contrato operacional, script publico, skill, governanca, seguranca, fluxo de contribuicao, remocao, rename ou incompatibilidade), avaliar `CHANGELOG.md`: atualizar `Unreleased` ou justificar explicitamente a omissao no relatório
- quando a frente alterar motor com versão, assinatura, regra de extracao ou estado, buscar também termos antigos que possam ter ficado nos docs (ex.: referencias a `extrator N` depois de `EXTRACTOR_SIGNATURE_VERSION=N+1`)
- simetricamente, quando a frente **adicionar** parâmetro, alias, flag, estado ou opção a um contrato, buscar o **termo novo** em todas as mencoes da mesma operacao e confirmar propagacao completa (ex.: novo `-ObjectList` ao lado de `-ObjectNames`/`-ObjectGuids` deve aparecer em todas as descricoes equivalentes — `README.md`, `02`, `09`, skills, checklists, exemplos); mencao pre-existente que ficou só com o conjunto antigo e gap, salvo justificativa
- ao encontrar motor/self-test/evidencia tocado ou criado pela frente mas ausente do `09`, reportar como **lacuna candidata** separando atribuicao (ausencia pre-existente não bloqueia push) de merito (cobertura que pode valer registrar); «não é desta frente» não é motivo automático de descarte
- quando a mudanca afetar regra operacional compartilhada, `02-regras-operacionais-e-runtime.md` precisa ter cobertura explicita ou ausencia descartada com justificativa; cobertura apenas em `08`, `09`, skill ou README técnico não basta
- antes de declarar ausencia de termo, self-test, script, regra ou evidencia, confrontar a alegacao com todos os resultados de busca e leituras já coletados na fase semantica; se uma busca anterior contradisser a ausencia, reler o ponto citado antes de reportar gap
- encontrar o termo no `09` não basta; comparar se a descrição ainda reflete a abrangencia atual do contrato, script ou regra
- evitar rastreabilidade agregada demais no `09`: quando motor, orquestrador, wrapper e bateria de teste tiverem papeis distintos, cada papel relevante precisa de evidencia própria ou justificativa explicita para não registrar separadamente
- com `SKILL.md` no diff, o orquestrador avisa para conferir satelites linkados no próprio SKILL
- na fase semantica (passo 4 do `AGENTS.md`), confirmar explicitamente se checklist em satelite (ex. `quality-checklist.md`) contradiz o `SKILL.md` da mesma frente
- na pre-push, gaps exigem aprovacao explicita depois do relatório; uma única aprovacao pode cobrir o conjunto sugerido (ex.: «aplica os gaps do relatório»), salvo pedido item a item; intencao inicial não autoriza gravar automaticamente
- gate semantico incondicional: a fase semantica produz relatório e para; nenhuma edicao de arquivo, commit ou push acontece entre o relatório e a aprovacao explicita do usuário — sem exceção, independentemente do tamanho ou obviedade do gap
- encerrar o relatório pre-push com linha fixa `VEREDICTO: nenhum gap confirmado` ou `VEREDICTO: N gap(s) confirmado(s)` (`N` = contagem de gaps confirmados); avisos descartados e areas não cobertas não contam como gap; ausencia da linha significa pre-push não concluida, mesmo com passo mecanico ok
- rotina pre-push completa e paridade motor↔documentação: `13-revisao-pre-push.md` (prevalece sobre este resumo quando houver divergencia)
- a rotina pre-push acima (documento `13`) é a do **repositório de skills**; a validação pré-push do estado de uma **pasta paralela de KB** (antes do push dessa KB) é outra rotina — a skill `xpz-kb-parallel-pre-push` (orquestrador `Invoke-XpzKbParallelPrePushPhase1.ps1`, gates mecânicos próprios) — com autoridade documental distinta; não confundir os dois contextos
- termo reservado: quando o usuário pedir `revisão por pares`, `peer review`, `painel multi-modelo` ou `validar plano multi-modelo`, o agente deve primeiro ler `xpz-llm-delegate/SKILL.md` e `15-revisao-por-pares.md` (e, no caso pré-push reforçado, também `14` + `13`); se não houver `preferred-reviewers.json`, perguntar quais ferramentas/modelos o usuário tem disponíveis ou prefere (`Claude Code`, `opencode/Ollama Cloud`, `Codex`, `Copilot`, `Gemini`, subagente nativo) antes de oferecer painel, sem presumir assinatura externa; depois que o usuário escolher revisores para a rodada, oferecer salvar essa seleção como curadoria em `%LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json`, separadamente da autorização por KB em `llm-delegation-policy.json`; se houver `preferred-reviewers.json`, tratar a lista como candidatos preferidos do painel (não pool opcional), rodar gate por preferido e diversidade sobre a lista completa de candidatos preferidos + vereditos, sem parar no mínimo de 2 famílias por decisão própria; antes do recibo final, rodar `Resolve-LlmDelegatePeerReviewCloseout.ps1` (ao autorar a versão consolidada vN+1, passar `-VNextState pendingResubmission`, que bloqueia até `resubmitted` ou declínio auditado por `-ResubmissionDeclinedBy`/`-ResubmissionDeclineReason`/`-RoundId`) e, se `closeoutReady=false`, apresentar o `requiredUserPrompt` em vez de encerrar a rodada; é proibido chamar parecer solo de revisão por pares — sem painel válido com >=2 famílias efetivamente consultadas, rotular como `parecer solo` ou `segunda opinião (N)`; antes de usar o rótulo, apresentar recibo mínimo (arquivos lidos, manuscrito/prompt, revisores, famílias, piso de diversidade, vereditos, estado da vN+1 (`vNextState`), estado de cada revisor preferido quando houver lista e adendo de closeout quando aplicável); resposta em menos de 30s desde o pedido é incompatível com revisão por pares real, salvo relatório de painel anterior identificável
- tier reforcado (opcional): revisao por painel multi-modelo diverso, em `14-revisao-pre-push-reforcada.md` (aplicacao pre-push da metodologia generica de revisao por pares do `15-revisao-por-pares.md`, fonte normativa da regua e dos papeis); o agente pode **montar o painel** sob acionamento humano (disparar os revisores diversos, colher vereditos, parar no primeiro gap; piso: >=2 familias distintas — um painel de uma voz nao e revisao por pares; subagente nativo conta como a familia do orquestrador (valide o piso sobre a lista COMPLETA de revisores, nativos inclusos); `ask` apresentados em lote, nunca descartados), mas a **decisão** de triagem de gaps, convergencia e push-ready e no humano — o agente **recomenda** sua triagem, mas não decide; a rotina por revisor continua sendo a do `13`
- com `commitsBehind > 0`, `PUSH_READINESS=blocked`: diff/arquivos do intervalo são só diagnosticos; fetch origin se necessário; se persistir, integrar antes do push (sem push automático)
- na comparacao da pre-push, exemplos canonicos ficam em `*.example.ps1` dentro das skills afetadas (hoje principalmente `xpz-kb-parallel-setup/examples/`); não ha pasta `examples/` na raiz
- em `xpz-kb-parallel-setup`, validar `Test-*KbPowerShellRuntime.ps1` antes de qualquer outro wrapper local; se `pwsh` 7.4 LTS ou superior estiver ausente, tratar como bloqueio operacional da pasta paralela, não como aviso informativo
- quando a sessao já publicar o caminho de uma skill ou de seus exemplos, usar esse caminho publicado como referencia autoritativa; não inferir caminho alternativo por heuristica

## Tipo desconhecido no catálogo XPZ (agente)

Quando sync ou pre-varredura bloquearem por GUID de `Object/@type` ausente do catálogo efetivo:

1. Parar materialização; não tratar como defeito do XPZ da KB.
2. Coletar evidencia (relatório JSON: `-DiscoveryReportPath` no sync ou inventario com `unknownTypesDiscovery`).
3. Perguntar ao usuário, em tom educado, se **recomenda** autorizar consulta a `nexa` e wiki/docs oficiais GeneXus — não consultar sem consentimento.
4. Se houver identificacao segura do tipo exportavel, oferecer em passos separados:
   - registro local paliativo (`Register-GeneXusObjectTypeCatalogOverride.ps1` com `-UserApproved`);
   - prompt copiavel para o mantenedor (`New-GeneXusUnknownTypeMaintainerPrompt.ps1`).
5. Em **cada nova sessao** na pasta paralela com override ativo, executar `Test-XpzCatalogOverrideSessionReminder.ps1` e lembrar que falta alinhar GeneXus-XPZ-Skills.
6. NUNCA registrar no catálogo compartilhado a partir da pasta paralela sem troca de contexto; NUNCA materializar parcialmente.

Pre-varredura obrigatória antes de sync full ou primeira materialização longa:

`Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <xpz> -ParallelKbRoot <raiz> -FailOnUnknownTypes`

## Regra de leitura para runtime

- quando a pergunta envolver `Base Table`, `Extended Table`, navegacao, `For each`, `Load`, `Refresh`, `Refresh Grid` ou risco de performance, consultar primeiro `02-regras-operacionais-e-runtime.md`
- quando a pergunta envolver apenas estrutura XML observada, priorizar `01-base-empirica-geral.md` como índice e descer ao arquivo empirico mais aderente da serie `01`
- quando a pergunta misturar estrutura e comportamento provavel, responder separando explicitamente `Evidência direta`, `Regra documentada`, `Inferência forte` e `Hipótese`
- quando a pergunta envolver `sync` ou wrappers locais da pasta paralela da KB, distinguir explicitamente:
  - capacidade já disponível na base compartilhada
  - exposicao dessa capacidade no wrapper local
  - compatibilidade real dessa exposicao com o motor compartilhado efetivo
  - decisão local do usuario/equipe sobre atualizar ou não o wrapper

## Regra de leitura para baseline oficial conhecido

- quando a pergunta envolver review, sanity, regressao, defeito herdado ou qualidade de delta em objeto legado, separar explicitamente `sanity absoluto do artefato atual` de `comparacao contra baseline oficial`
- responder primeiro o `sanity absoluto` e só depois, se houver baseline oficial confiavel, responder a comparacao
- usar como baseline apenas fonte oficial e rastreavel da trilha, como snapshot oficial em `ObjetosDaKbEmXml` ou export oficial comparavel da IDE; não usar copia provisoria, delta local ou XML contaminado como baseline
- rotular a comparacao com exatamente um destes estados: `same as official baseline`, `worse than official baseline`, `better than official baseline` ou `no official baseline compared`
- nunca tratar `same as official baseline` como sinonimo de `bom`; isso prova apenas ausencia de piora relevante naquela dimensao comparada
- se o artefato atual falhar em `sanity absoluto`, manter a reprovacao mesmo quando a comparacao indicar `same as official baseline` ou `better than official baseline`
- quando o problema já existia no baseline oficial e o delta não piorou, descrever como risco ou defeito herdado, não como regressao introduzida agora
- antes de concluir `worse than official baseline`, filtrar primeiro ruido conhecido e não funcional já documentado pela trilha
- se não houver baseline oficial confiavel ou se ele não tiver sido realmente aberto, usar `no official baseline compared` em vez de inferir comparacao por memoria, plausibilidade ou recencia
- em revisao por blocos, comparar primeiro o `bloco primario` tocado pelo delta e só expandir para bloco adjacente quando a dependencia funcional exigir

## Regra de leitura para campos derivados

- nome de atributo calculado ou derivado não prova semantica funcional
- quando filtro, regra de negocio ou interpretacao depender de campo derivado, a formula e a cadeia imediata de chamadas prevalecem sobre nome, caption ou intuicao
- filtro de negocio sobre campo derivado exige validar a formula antes da proposta
- se a formula chamar `Procedure`, a leitura deve seguir pelo menos a cadeia imediata necessária para justificar o significado funcional do campo

## Regra de uso do KB Intelligence

- quando o objetivo principal for triagem por índice derivado para decidir por onde comecar na KB, preferir a skill `xpz-index-triage`
- quando uma pasta paralela de KB expuser `KbIntelligence\kb-intelligence.sqlite`, o agente deve usar o índice para triagem técnica antes de alterar objetos GeneXus cobertos pelo índice
- antes de confiar no índice, comparar `last_index_build_run_at` na tabela `metadata` do SQLite com `last_xpz_materialization_run_at` lido nominalmente em `kb-source-metadata.md`, exigir `inventory_validation_status=OK` e validar `extractor_signature_version`/`extractor_signature_hash` contra o motor em `scripts/Build-KbIntelligenceIndex.py` do repositório ativo (via `scripts/GeneXusKbIntelligenceExtractorContract.ps1` ou gate `Test-*KbIndexGate.ps1`)
- quando o wrapper local expuser `index-metadata`, usar essa consulta para obter `last_index_build_run_at` e `inventory_validation_status`; se ela falhar, retornar vazio, não trouxer timestamp ou não trouxer o status semantico, tratar o índice como sem metadado valido e oferecer regeneracao/validacao antes de seguir
- se `kb-source-metadata.md` estiver ausente ou não expuser literalmente `last_xpz_materialization_run_at`, tratar a pasta paralela como defasada/incompatível e oferecer atualizacao via `xpz-kb-parallel-setup`; não inferir esse horario por data do arquivo, `updated`, `generated_at`, `source_xpz` ou outro campo aproximado
- se `last_index_build_run_at` for igual ou posterior a `last_xpz_materialization_run_at`, `inventory_validation_status` estiver `OK` e a assinatura do extrator coincidir com o motor ativo, o índice está apto para triagem inicial
- se `AGENTS.md` ou `README.md` locais gravarem timestamps literais de materialização ou índice, tratar isso como drift documental da pasta paralela: não atualizar o valor duplicado; substituir por ponteiros para `kb-source-metadata.md`, para `index-metadata` e para o gate efetivo, conforme `xpz-kb-parallel-setup`
- quando a validação de frescor/compatibilidade tiver sido relevante para liberar ou bloquear a resposta, declarar brevemente no handoff se o gate foi liberado (`last_index_build_run_at >= last_xpz_materialization_run_at`, `inventory_validation_status=OK` e assinatura do extrator alinhada) ou qual campo/capacidade bloqueou
- todo processamento bem-sucedido de `XPZ` exportado pela IDE que materialize XMLs oficiais em `ObjetosDaKbEmXml` deve chamar a regeneracao/validacao do índice derivado logo depois
- rebuild do índice via `scripts/Build-KbIntelligenceIndex.ps1` exige Python 3.x utilizavel no `PATH` (`scripts/GeneXusPythonPrerequisite.ps1`; stub `WindowsApps` da Microsoft Store não conta); ausencia bloqueia o refresh com exit `8` e mensagem `PREREQUISITO AUSENTE` — a materialização XPZ/XML em `ObjetosDaKbEmXml` pode já ter concluido; não tratar como falha do pacote exportado; **rigor**: sync normal **não** terminou — não declarar sync OK nem autorizar triagem ampla sem índice; declarar **fluxo incompleto** (XMLs possivelmente atualizados, índice pendente). Ver `xpz-sync` e molde `Update-KbFromXpz.example.ps1`
- antes de sugerir ou executar `sync` normal em pasta que adota `KbIntelligence`, o agente deve ter evidencia clara, na documentação local ou no próprio wrapper local, de que o wrapper de materialização encadeia esse refresh compulsorio do índice
- na ausencia dessa evidencia clara, tratar a pasta paralela como compatibilidade pendente e oferecer atualizacao via `xpz-kb-parallel-setup` antes do `sync`
- se o wrapper local de materialização ainda não encadear esse refresh, não usar esse wrapper antigo para reparar metadado e regenerar índice manualmente; bloquear e oferecer atualizacao via `xpz-kb-parallel-setup`
- não descrever `sync` seguido de rebuild manual separado do índice como fluxo normal quando a pasta paralela adotar `KbIntelligence`
- se o índice estiver ausente, sem metadado, mais antigo que a última materialização XPZ/XML, com `inventory_validation_status` ausente ou diferente de `OK`, com assinatura de extrator ausente ou divergente do motor ativo, ou se `kb-source-metadata.md` estiver ausente, o agente não deve consultar o acervo oficial de objetos para responder negocio, nem por varredura ampla nem por caminho pontual deduzido, nem gerar objetos para importação na KB pela IDE; deve tratar isso como exceção operacional e oferecer ao usuário a regeneracao/validacao do índice antes de seguir
- com gate de índice bloqueado, leitura pontual só e aceitavel para diagnostico mínimo da incompatibilidade em documentação local, estrutura, wrappers e metadados operacionais; não montar, testar existência, listar ou abrir caminho de XML oficial de objeto como fallback para responder a pergunta
- o gate do índice deve ser sequencial e atômico; não testar caminho filho antes da camada pai, por exemplo `KbIntelligence\kb-intelligence.sqlite` antes de `KbIntelligence`
- se o wrapper local documentado de consulta do índice estiver ausente, não listar `scripts` nem procurar wrappers alternativos, backups ou nomes parecidos; tratar como defasagem da pasta paralela e oferecer atualizacao via setup
- a triagem operacional deve consultar `object-info`, `who-uses`, `what-uses` e `show-evidence`, ou `impact-basic` quando esse comando estiver disponível
- para análise de impacto, callers, callees e referencias entre objetos, `rg`/`grep` bruto não é evidencia final quando o índice está apto; usar primeiro `impact-basic`, `who-uses` ou `what-uses`, e confirmar relacao específica com `show-evidence` ou XML oficial no bloco correto
- antes de `who-uses`, `what-uses`, `impact-basic` ou `functional-trace-basic`, conferir no catalogo efetivo (`scripts/gx-object-type-catalog.json` + `scripts/gx-object-type-catalog.override.json` na pasta paralela quando existir) se o tipo tem `queryableByKbIntelligence=true`; quando for `false`, o `Query-KbIntelligenceIndex` devolve `blocked=true` e exit `11` — **não** tratar como “zero dependencias”; usar `object-info`, `search-objects`, `list-by-type` ou XML pontual (lista canônica no JSON; inclui desde 2026-05-30 tipos visuais/infra com Part e grafo zero, ex.: `Image`, `Theme`, `SubTypeGroup`, `Module`)
- para tipos que permanecem `queryableByKbIntelligence=true` com grafo assimétrico (`API`, `DataSelector`, `WorkWithForWeb`, `ExternalObject`), ver `scripts/README-kb-intelligence.md` — `impact-basic` pode mostrar só saidas ou entradas esparsas; isso é esperado, não falha do índice
- em `ExternalObject`, o índice diferencia declaracao por `ATTCUSTOMTYPE` e uso efetivo por chamada de método em variável `exo:<ExternalObject>`; para perguntas como "quem toca este objeto externo", olhar o `extractor_rule` e, se necessário, `show-evidence`
- `impact-basic` e a triagem equivalente representam impacto técnico direto baseado no índice; não provam impacto runtime completo
- `who-uses` em `Procedure` passa a incluir `Attribute` cujo `Property Formula` chama a procedure com os mesmos padrões de `Source` efetivo; ainda não cobre funções de dominio, literais ambiguos nem expressoes fora desses padrões — nesses casos abrir o XML do atributo
- para triagem de gravabilidade e risco de `New` em atributos de `Transaction`, preferir `transaction-writable-attributes` no índice após rebuild (`schema_version=3`); tratar como gate de triagem quando a paridade da pasta paralela estiver validada. Os gates de empacote `Test-GeneXusTransactionWritability.ps1` e `Test-GeneXusNewWritableTargets.ps1` delegam ao nucleo canonico `GeneXusTransactionWritabilityCore.py` (mesma lógica do build). Não usar consulta do índice como única prova para blocos `New` dentro de `Source` — manter `Test-GeneXusNewWritableTargets.ps1` no empacote
- `functional-trace-basic`, quando disponível, pode empacotar a coleta inicial de triagem funcional, mas não abre XML automaticamente, não interpreta regra de negocio e não substitui a resposta classificada do agente
- para "quais classes CSS existem" e "onde a classe X e usada", usar `css-classes` e `css-class-usage` (a partir de `schema_version=3`); `css-classes` cobre o inventario incompleto (classes de `DesignSystem` que não viram objeto), `css-class-usage` cobre o uso invisivel por código (`Controle.Class = ...`, além de `class="..."`/`cellClass=` no layout); a saida declara cobertura honesta (`dynamic_uses_total` para atribuicoes dinamicas, `found_in_catalog=false` = usada mas não catalogada, não inexistente); operacao destrutiva (renomear/remover classe) exige conferencia por busca literal no XML
- o índice não substitui `ObjetosDaKbEmXml`, que continua sendo a fonte normativa e somente leitura
- se a mudanca exigir semantica GeneXus, o agente deve abrir o XML oficial e revisar o trecho relevante antes de concluir
- quando a pergunta for funcional, o agente deve usar o índice apenas para orientar a ordem de leitura, separando explicitamente `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
- ao validar artefatos do KB Intelligence, escolher o executor pelo formato do caso, não pelo nome da fase:
  - casos com `source`, `target` e `expected_rule` pertencem a validação de extracao/geracao e devem rodar com `Build-KbIntelligenceIndex.ps1 -ValidationCasesPath`
  - casos com `query` pertencem a validação de consulta e devem rodar com `Test-KbIntelligenceQueries.ps1 -ValidationCasesPath`
- se um caso de relacao com `expected_rule` for enviado ao validador de consultas, tratar o erro como uso de executor incompatível antes de concluir regressao real

## Regra de delegacao a LLM secundario

- delegar tarefa menor ou pedir segunda opiniao a um modelo secundario (skill `xpz-llm-delegate`, backends opencode — modelos no formato `provider/modelo`, incluindo provedores cloud conhecidos como `ollama-cloud/*` e `opencode-go/*` —, Codex — `codex exec` —, Claude Code — `claude -p`, Opus 4.8 —, GitHub Copilot CLI — `copilot -p` — e Gemini CLI — `gemini -p`) só **a pedido do usuário ou com concordancia explicita dele**; nunca por iniciativa própria
- manter no agente forte todo juizo estrutural GeneXus; o subagente serve para tarefa mecanica ou segunda opiniao, e sua saida deve ser validada pelo agente forte antes de usar
- antes de enviar conteúdo a um modelo, classificar `kb-sensitive` (pasta paralela de KB) vs `public` (repo publico/molde sanitizado) e rodar `scripts/Resolve-LlmDelegateAuthorization.ps1` com `-Backend opencode|codex|claude-code|copilot|gemini`: `deny` não envia, `ask` exige autorizacao explicita do usuário, `allow` segue anunciando o destino ao usuário (campo `targetModelKey`)
- preferir modelo local (loopback) para conteúdo de KB; conteúdo de pasta paralela só vai a modelo externo com autorizacao; no opencode, provedores cloud conhecidos como `ollama-cloud/*` e `opencode-go/*` são externos mesmo quando a configuração local não estiver legível; o Codex casa a politica pela chave de destino (`openai/*` para modelo OpenAI explícito ou default da config, nunca `codex/`), Claude Code casa `anthropic/*` para Opus 4.8 (nunca `claude-code/`), Copilot casa `github-copilot/*` (nunca `copilot/`) e Gemini casa `google/*` (nunca `gemini/`); adapters agenticos com permissao/sandbox/modo restritos **não** contornam o gate; ver `02-regras-operacionais-e-runtime.md` e `xpz-llm-delegate/SKILL.md`
- a politica de delegacao por-KB vive no arquivo `llm-delegation-policy.json` na raiz da pasta paralela (nome legado `opencode-delegation-policy.json` ainda aceito); com `-PolicyPath` omitido, o gate descobre o caminho via `-ParallelKbRoot`

## Regra de triagem exploratoria

- quando a frente exigir decidir se existe massa suficiente para abrir novo incremento, priorizar triagem exploratoria curta e auditavel antes de propor alteracao metodologica ou de código
- em Windows, preferir consultas pequenas e separadas no PowerShell, em vez de one-liner longo com muitas interpolacoes, regexes e transformacoes na mesma linha
- a ordem recomendada é: contagem bruta, agrupamento por sinal relevante, amostra curta de casos reais positivos e negativos
- não propor novo incremento apenas por ocorrência textual bruta; confirmar antes se o padrão observado tem resolucao estrutural segura no acervo
- quando a consulta falhar por sintaxe ou ficar ruidosa demais para leitura direta, simplificar a abordagem e refazer em etapas menores
- quando a hipotese depender de fechar regra nova, contrato novo ou ampliacao metodologica, extrair antes casos reais positivos e negativos do acervo; contagem sozinha não basta para sustentar decisão
- quando busca, agrupamento ou regex retornarem zero de forma inesperada, validar primeiro uma ocorrência real do XML no acervo antes de concluir ausencia de sinal ou trocar a hipotese

## Regra de leitura para compatibilidade de `Source`

- `Source` que parece GeneXus valido não prova compatibilidade operacional
- operador, função, conversao ou padrão string/numerico novo só pode ser aceito como pronto quando a própria trilha XPZ o sustentar por regra explicita, exemplo sanitizado ou molde documentado
- corpus local da KB ajuda a confirmar e desempatar, mas não substitui a base metodologica
- se um trecho essencial do `Source` continuar sustentado apenas por plausibilidade, o agente deve reescrever para padrão documentado ou abortar a consolidacao
- antes de empacotar, separar explicitamente duas decisoes: `XML bem-formado` e `objeto provavelmente importavel`
- `XML bem-formado` não dispensa gate de sanidade do `Source` quando o objeto depende de `Source` para importar com seguranca conservadora
- o gate mínimo de sanidade do `Source` deve revisar os pares estruturais realmente tocados pela mudanca, como `Sub/EndSub`, `For each/EndFor`, `Do Case/EndCase` e `If/EndIf`
- se a mudanca inserir novo `Case` em um `Do Case` de `Source` que dependa materialmente de `parm(...)`, revisar os `Case` irmaos do mesmo bloco antes de concluir a compatibilidade
- nessa revisao de `Do Case`, conferir se os parâmetros de entrada relevantes, esperados pelo padrão local do bloco, aparecem de forma coerente no novo ramo; ausencia de parâmetro comparavelmente esperado exige justificativa explicita
- se o novo `Case` divergir do padrão local dos ramos irmaos sem justificativa explicita, bloquear a consolidacao em vez de aceitar branch hardcoded ou sustentado apenas por analogia fraca
- se o trecho novo introduzir `elseif`, `iif(...)`, condição excessivamente densa ou chamada em condição destoando do estilo local, tratar isso como alerta consultivo e preferir reescrita para forma conservadora documentada
- quando houver cheque automatizado leve de `Source`, interpretar o resultado de forma conservadora:
- `xmlWellFormed=false` bloqueia qualquer conversa de empacotamento ate correcao do XML
- `sourceSanityStatus=fail` bloqueia empacotamento ate corrigir balanceamento estrutural e fechamentos
- o `fail` tambem inclui o finding type-aware `procedural-in-conditions`: um `Procedure` com a parte `Conditions` não-vazia e barrado porque `Procedure` não tem filtro de `Conditions` (predicados vivem em `For Each ... Where`) e codigo ali causa `src0055` no import; `WebPanel`/`Prompt`/`Selection List`, onde `Conditions` e filtro legitimo, e `Data Selector`, que tem `Conditions` propria, ficam fora
- `sourceSanityStatus=warn` com `probablyImportable=true` ainda exige revisao dos warnings; não tratar como liberacao automática
- `sourceSanityStatus=pass` com `xmlWellFormed=true` libera apenas o próximo gate metodologico; não prova importação, especificacao nem build
- ao revisar `Source` grande, a leitura deve considerar o contorno visual do bloco afetado, e comentarios estruturais humanos já existentes podem ser preservados quando ajudam a navegacao do trecho
- em `Procedure Source`, pares como `count/then-copy`, `exists/then-load`, `validate/then-apply` e `select-candidate/then-materialize` devem ser revisados como unidade lógica quando compartilham a mesma tabela/base e identidade candidata
- se a mudanca altera filtros de identidade, unicidade ou ambiguidade em um `for each`, buscar queries irmas no mesmo `Source` e reconciliar os critérios ou justificar explicitamente a divergencia
- ao citar uma linha de XML GeneXus, classificar o trecho como `Source efetivo`, `Rules/parm`, `metadado XML`, `chamada no chamador` ou `assinatura no chamado`
- para afirmar que uma `Procedure` A chama uma `Procedure` B, a evidencia deve estar no `Source` efetivo de A, na linha da chamada a B; o `parm(...)` de B prova assinatura do chamado, não ponto de chamada
- em cadeia de chamadas, separar sempre arquivo/linha do chamador e arquivo/linha da assinatura do chamado

### Regra adicional para `Procedure` de relatório

- em relatório simples, `Source` deve ser validado junto com a camada onde cada sintoma nasceu: `Source`, `Rules` ou layout
- `Output_file`, `Header`, `Footer`, `For each` e `print printBlock...` pertencem ao `Source`
- `parm(...)` pertence a `Rules`
- `Bands`, `PrintBlock`, `ReportLabel` e `ReportAttribute` pertencem ao layout `Part c414ed00-8cc4-4f44-8820-4baf93547173`
- se o erro mencionar `;` em regra, revisar `Rules` antes de reabrir layout
- se o erro mencionar controle invalido, `printBlock` ou shape de relatório, revisar layout antes de inferir defeito de envelope
- se a solucao continuar sustentada só por plausibilidade depois de uma rodada corretiva, parar e escalar para XML real comparavel

### Protocolo geral de revisao por blocos

- em tipos heterogeneos cobertos por esta base, declarar o `bloco primario` antes da análise fina
- `bloco adjacente` e apenas o bloco adicional aberto por dependencia funcional explicita com o `bloco primario`
- nomear toda `transicao justificada` no raciocinio e no handoff
- usar como `criterio de parada` o ponto em que a hipotese já estiver sustentada; não reabrir o objeto inteiro por reflexo
- declarar o `escopo da conclusao` no menor nível funcional que a evidencia sustenta; quando houver mais de um contexto de execução relevante, explicitar também esse contexto

### Regra adicional para revisao de `Procedure`

- em `Procedure`, revisar por blocos funcionais; não presumir `Source` como bloco inicial universal
- os blocos canonicos são `Source`, `Rules/parm`, `Variables`, `Calls and dependencies`, `Identity and container` e, quando aplicavel, `Report layout`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Rules/parm -> Variables` para validar contrato de parâmetros
- parar a expansao quando a hipotese já estiver sustentada; não reabrir a `Procedure` inteira por reflexo
- usar `Source` como bloco inicial para filtros, fluxo procedural, navegacao, atribuicoes, condições e chamadas feitas no corpo
- se `Source` contiver `New`, executar `Test-GeneXusNewWritableTargets.ps1` antes de empacotar; bloquear atribuicao a `Formula`, atributo descritivo/extendido, subtipo derivado ou alvo cuja tabela base não possa ser resolvida
- usar `Rules/parm` como bloco inicial para assinatura, parâmetros, direcao do contrato e erro claramente ligado a regra
- usar `Variables` como bloco inicial para existência, tipo, helper novo, coerência de nome e colecao vs simples
- usar `Calls and dependencies` como bloco inicial para cadeia de chamadas, objeto chamado, dependencia externa e prova de call site
- usar `Identity and container` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, origem estrutural e risco de clonagem
- usar `Report layout` como bloco inicial apenas em `Procedure` de relatório quando o sintoma falar de `PrintBlock`, `ReportLabel`, `ReportAttribute`, `Bands` ou shape de layout

### Regra adicional para revisao de `DataProvider`

- em `DataProvider`, revisar por blocos funcionais; não presumir `Source` como bloco inicial universal
- os blocos canonicos são `Output structure`, `Source`, `Navigation context`, `Calls and dependencies` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Output structure -> Source` para reconciliar shape prometido com montagem real
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `DataProvider` inteiro por reflexo
- usar `Output structure` como bloco inicial para colecao vs simples, grupo aninhado, nome de no, cardinalidade, coerência do retorno e shape prometido
- usar `Source` como bloco inicial para condição, atribuicao, montagem, cálculo, preenchimento e fluxo interno
- usar `Navigation context` como bloco inicial para base implicita, `For each`, filtro, tabela base e ambiguidade de navegacao
- usar `Calls and dependencies` como bloco inicial para `SDT`, `Procedure`, `BC`, `Transaction` e dependencia externa imediata
- usar `Identity and container` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, origem estrutural e risco de clonagem

### Regra adicional para revisao de `DataSelector`

- em `DataSelector`, revisar por blocos funcionais; não tratar XML pequeno como leitura simples quando a pergunta for de filtro, parâmetro, selecao, função ou diagnostico fino
- os blocos canonicos são `Selection contract`, `Selection logic and conditions`, `Attribute and function dependencies`, `Navigation context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Selection logic and conditions -> Attribute and function dependencies` para confirmar se a referencia usada no filtro existe de verdade na KB
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `DataSelector` inteiro por reflexo
- usar `Selection contract` como bloco inicial para parâmetros, assinatura de entrada, variável de controle e contrato esperado pelo seletor
- usar `Selection logic and conditions` como bloco inicial para `Condition`, filtro, expressao, critério de selecao e comportamento lógico do seletor
- usar `Attribute and function dependencies` como bloco inicial para atributo citado, função usada no filtro, referencia quebrada, nome não resolvido e dependencia semantica concreta
- usar `Navigation context` como bloco inicial para base implicita, contexto transacional/fisico, encaixe no modelo e coerência da selecao com a moldura de navegacao
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de estar olhando o seletor errado
- manter separado o que e contrato de parâmetro, o que e filtro aplicado e o que depende da existência real de atributo ou função no destino; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `API`

- em `API`, revisar por blocos funcionais; não presumir leitura centrada em código ou dependencias
- os blocos canonicos são `Service contract`, `Events and orchestration`, `Calls and dependencies`, `Data contract` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Service contract -> Data contract` para reconciliar endpoint publicado com shape efetivo
- parar a expansao quando a hipotese já estiver sustentada; não reabrir a `API` inteira por reflexo
- usar `Service contract` como bloco inicial para método exposto, endpoint, assinatura externa, operacao publicada e contrato visivel ao consumidor
- usar `Events and orchestration` como bloco inicial para `.Before/.After`, ordem de execução, validação interna, transformacao e fluxo procedural da camada de `API`
- usar `Calls and dependencies` como bloco inicial para `Procedure`, `SDT`, `Domain`, `Transaction`, `EXO`, `DataProvider` e cadeia funcional externa
- usar `Data contract` como bloco inicial para shape de entrada/saida, coerência de tipos, estrutura de resposta e mapeamento entre contrato e dados
- usar `Identity and container` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, origem estrutural e risco de clonagem

### Regra adicional para revisao de `SDT`

- em `SDT`, revisar por blocos funcionais; não tratar objeto pequeno ou declarativo como leitura monolitica quando a pergunta for de shape, tipo, serializacao ou diagnostico fino
- os blocos canonicos são `Structure definition`, `Item typing and dependencies`, `External serialization contract`, `Top-level type properties` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Structure definition -> Item typing and dependencies` para confirmar se o item estruturalmente correto também aponta para o tipo certo
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `SDT` inteiro por reflexo
- usar `Structure definition` como bloco inicial para `Level`, `LevelInfo`, sequência de `Item`, hierarquia, composicao interna, item no nível errado e colecao vs simples
- usar `Item typing and dependencies` como bloco inicial para `idBasedOn`, `ATTCUSTOMTYPE`, dominio base, referencia a outro `SDT` e coerência semantica do item
- usar `External serialization contract` como bloco inicial para `ExternalName`, `ExternalNamespace`, `idXmlName`, `idXmlNamespace`, `soaptype`, `idCollectionItemName` e metadata de serializacao/integracao
- usar `Top-level type properties` como bloco inicial para propriedade declarada no próprio `SDT`, especialmente tipagem ou comportamento estrutural top-level
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e shape interno do `SDT`, o que e dependencia tipada de item e o que e metadata de serializacao externa; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Theme`

- em `Theme`, revisar por blocos funcionais; não tratar o objeto como XML visual pequeno autossuficiente quando a pergunta for de grafo visual, binding, simplificacao ou diagnostico fino
- os blocos canonicos são `Theme core definition`, `Class graph and references`, `Predefined types and style bindings`, `Visual simplification and override surface` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Class graph and references -> Predefined types and style bindings` para confirmar se a classe existente está realmente vinculada ao tipo visual normativo certo
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Theme` inteiro por reflexo
- usar `Theme core definition` como bloco inicial para definicao-base do tema, propriedades centrais, shape do objeto e configuração global
- usar `Class graph and references` como bloco inicial para grafo de `ThemeClass`, referencias internas entre classes e heranca visual
- usar `Predefined types and style bindings` como bloco inicial para `PredefinedTypes`, `Styles` e bindings normativos entre tipo visual conhecido e a pilha concreta `ThemeClass`/`ThemeColor`/`ColorPalette`/`DesignSystem`
- usar `Visual simplification and override surface` como bloco inicial para simplificacao, override, enxugamento visual e remocao controlada de superficie somente depois que o acoplamento visual básico já estiver sustentado
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, contêiner, origem estrutural e risco de clonagem
- manter separado o que e definicao-base do tema, o que e grafo de classes, o que e binding visual normativo e o que e simplificacao/override; não usar simplificacao como atalho para substituir leitura do binding nem do grafo de classes

### Regra adicional para revisao de `ThemeClass`

- em `ThemeClass`, revisar por blocos funcionais; não tratar o objeto como XML visual pequeno, direto e trivial quando a pergunta for de heranca, marcadores de aplicabilidade, dependencia visual ou diagnostico fino
- os blocos canonicos são `Direct class surface`, `Inheritance and parent linkage`, `Theme applicability and internal classification`, `Visual references and external dependencies` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Inheritance and parent linkage -> Direct class surface` para verificar se o problema atribuido a heranca na verdade está na superficie declarada da classe derivada
- parar a expansao quando a hipotese já estiver sustentada; não reabrir a `ThemeClass` inteira por reflexo
- usar `Direct class surface` como bloco inicial para `Properties` top-level, propriedades visuais concretas, shape direto da classe e override local
- usar `Inheritance and parent linkage` como bloco inicial para `parent`, `parentGuid`, `parentType`, classe base, cadeia de heranca visual, variantes derivadas e estados como `hover`
- usar `Theme applicability and internal classification` como bloco inicial para `ThemeElementThemeTypes`, `ThemeElementInternalType`, aplicabilidade web/mobile e classificação interna da classe tematica
- usar `Visual references and external dependencies` como bloco inicial para referencias a cor, imagem, classe auxiliar ou outro recurso visual externo de que a classe dependa
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e superficie direta da classe, o que e heranca, o que e aplicabilidade/classificacao interna e o que e dependencia visual externa; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `ThemeColor`

- em `ThemeColor`, revisar por blocos funcionais; não tratar o objeto como cor trivial isolada quando a pergunta for de identidade nominal, valor, encaixe tematico, dependencia visual ou diagnostico fino
- os blocos canonicos são `Color identity and naming`, `Direct color value surface`, `Theme applicability and palette coupling`, `Visual references and usage dependencies` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Visual references and usage dependencies -> Direct color value surface` para verificar se o consumo quebrado da cor vem da referencia ou do valor concretamente serializado
- parar a expansao quando a hipotese já estiver sustentada; não reabrir `ThemeColor` inteiro por reflexo
- usar `Color identity and naming` como bloco inicial para nome lógico, identidade nominal da cor e papel tematico esperado
- usar `Direct color value surface` como bloco inicial para `Properties` top-level, valor serializado, shape direto e definicao concreta da cor
- usar `Theme applicability and palette coupling` como bloco inicial para relacao com `Theme`, `ColorPalette`, `DesignSystem`, escopo da cor e encaixe semantico na familia visual
- usar `Visual references and usage dependencies` como bloco inicial para consumo por `ThemeClass`, `Theme`, estilos ou outros elementos visuais dependentes
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e identidade nominal da cor, o que e valor direto, o que e encaixe tematico e o que e dependencia de uso visual; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `ColorPalette`

- em `ColorPalette`, revisar por blocos funcionais; não tratar o objeto como agrupador visual trivial quando a pergunta for de identidade da paleta, composicao, acoplamento arquitetural, superficie de uso ou diagnostico fino
- os blocos canonicos são `Palette identity and naming`, `Palette composition and declared members`, `Theme and design-system coupling`, `Color references and usage surface` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Color references and usage surface -> Palette composition and declared members` para verificar se o problema de uso visual vem do consumo da paleta ou da composicao declarada dela
- parar a expansao quando a hipotese já estiver sustentada; não reabrir `ColorPalette` inteiro por reflexo
- usar `Palette identity and naming` como bloco inicial para nome lógico da paleta, identidade nominal e papel tematico esperado
- usar `Palette composition and declared members` como bloco inicial para itens da paleta, composicao interna, shape direto e membros declarados
- usar `Theme and design-system coupling` como bloco inicial para relacao com `Theme`, `DesignSystem`, coerência arquitetural e encaixe na familia visual
- usar `Color references and usage surface` como bloco inicial para relacao com `ThemeColor` e demais consumos visuais dependentes da paleta
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e identidade da paleta, o que e composicao declarada, o que e acoplamento arquitetural e o que e superficie de uso; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `DesignSystem`

- em `DesignSystem`, revisar por blocos funcionais; não tratar o objeto como camada visual genérica quando a pergunta for de identidade do sistema, tokens, acoplamento com tema/paleta, superficie de consumo ou diagnostico fino
- os blocos canonicos são `System identity and naming`, `Design tokens and declared resources`, `Theme and palette coupling`, `Visual rules and consumption surface` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Visual rules and consumption surface -> Design tokens and declared resources` para verificar se o efeito visual quebrado vem da regra consumida ou do token/recurso declarado na origem
- parar a expansao quando a hipotese já estiver sustentada; não reabrir `DesignSystem` inteiro por reflexo
- usar `System identity and naming` como bloco inicial para nome lógico do sistema, identidade nominal e papel arquitetural esperado
- usar `Design tokens and declared resources` como bloco inicial para tokens, recursos declarados, composicao interna e shape funcional do sistema
- usar `Theme and palette coupling` como bloco inicial para relacao com `Theme`, `ColorPalette`, coerência arquitetural e encaixe entre camadas visuais
- usar `Visual rules and consumption surface` como bloco inicial para regras visuais consumidas por outras camadas e impacto funcional de uso
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e identidade do sistema, o que e token/recurso declarado, o que e acoplamento com tema/paleta e o que e superficie de consumo; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `PackagedModule`

- em `PackagedModule`, revisar por blocos funcionais; não tratar o objeto como contêiner trivial de instalacao quando a pergunta for de identidade do módulo, fronteira do pacote, contexto de instalacao, superficie de dependencia/consumo ou diagnostico fino
- os blocos canonicos são `Module identity and naming`, `Packaging boundary and declared members`, `Parent and installation context`, `Dependency and consumption surface` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Dependency and consumption surface -> Packaging boundary and declared members` para verificar se a quebra percebida no consumo do módulo vem da dependencia externa ou da fronteira funcional que o pacote realmente declara
- parar a expansao quando a hipotese já estiver sustentada; não reabrir `PackagedModule` inteiro por reflexo
- usar `Module identity and naming` como bloco inicial para nome lógico do módulo, identidade nominal e papel semantico esperado
- usar `Packaging boundary and declared members` como bloco inicial para membros declarados, composicao interna, fronteira do pacote e delimitacao funcional
- usar `Parent and installation context` como bloco inicial para relacao com instalacao, `parent`, contexto hierarquico e encaixe estrutural do módulo
- usar `Dependency and consumption surface` como bloco inicial para dependencias do módulo e forma de consumo por outras camadas
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e identidade do módulo, o que e fronteira de empacotamento, o que e contexto de instalacao e o que e superficie de dependencia/consumo; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Image`

- em `Image`, revisar por blocos funcionais; não tratar o objeto como binario isolado ou lista trivial de itens quando a pergunta for de variantes, payload, referencia externa ou diagnostico fino
- os blocos canonicos são `Image identity and naming`, `Image item set and declared variants`, `Binary payload and extraction fidelity`, `Theme and language references` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Image item set and declared variants -> Binary payload and extraction fidelity` para verificar se a falha está no desenho das variantes ou no conteúdo binario de uma delas
- parar a expansao quando a hipotese já estiver sustentada; não reabrir `Image` inteiro por reflexo
- usar `Image identity and naming` como bloco inicial para nome lógico da imagem, identidade nominal e papel semantico esperado
- usar `Image item set and declared variants` como bloco inicial para `ImageItem`, variantes, composicao interna e shape funcional do recurso
- usar `Binary payload and extraction fidelity` como bloco inicial para `base64Binary`, integridade do payload, preservacao do conteúdo e fidelidade de extracao
- usar `Theme and language references` como bloco inicial para `ThemeReference`, `LanguageReference` e dependencias externas de apresentacao
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e identidade da imagem, o que e conjunto de variantes, o que e payload binario e o que e referencia externa de tema/idioma; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Attribute`

- em `Attribute`, revisar por blocos funcionais; não tratar o objeto como definicao escalar trivial quando a pergunta for de tipagem, referencia nominal, semantica de controle ou diagnostico fino
- os blocos canonicos são `Attribute core definition`, `Typing and base linkage`, `Semantic property references`, `Presentation and control semantics` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Typing and base linkage -> Semantic property references` para confirmar se o atributo tipado corretamente ainda depende de outro atributo real no destino
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Attribute` inteiro por reflexo
- usar `Attribute core definition` como bloco inicial para shape top-level, definicao-base e estrutura central do atributo
- usar `Typing and base linkage` como bloco inicial para `idBasedOn`, dominio base, tipo declarado e coerência do contrato tipado
- usar `Semantic property references` como bloco inicial para `ControlItemDescription`, referencia nominal quebrada e dependencia concreta de outro atributo real
- usar `Presentation and control semantics` como bloco inicial para propriedades funcionais de exibicao, controle e comportamento serializado do atributo
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, contêiner, origem estrutural e risco de clonagem
- manter separado o que e definicao-base do atributo, o que e tipagem, o que e referencia semantica nominal e o que e semantica funcional de controle/apresentacao; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `PatternSettings`

- em `PatternSettings`, revisar por blocos funcionais; não tratar o objeto como XML pequeno autossuficiente quando a pergunta for de registro do pattern, configuração interna, contexto ou diagnostico fino
- os blocos canonicos são `Pattern registration and environment fit`, `Internal pattern configuration`, `Context and callable dependencies`, `Security and auxiliary references` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Pattern registration and environment fit -> Context and callable dependencies` para confirmar se o problema do pattern no ambiente na verdade vem de dependencia funcional faltante
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `PatternSettings` inteiro por reflexo
- usar `Pattern registration and environment fit` como bloco inicial para pattern não registrado, incompatibilidade do ambiente, `was not changed` e encaixe operacional do pattern
- usar `Internal pattern configuration` como bloco inicial para `CDATA`, flags, shape declarativo e configuração persistida do pattern
- usar `Context and callable dependencies` como bloco inicial para `ContextVariable`, `LoadProcedure`, procedures faltantes e contexto funcional exigido pelo pattern
- usar `Security and auxiliary references` como bloco inicial para `Security`, referencias auxiliares e dependencias complementares do pattern
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, contêiner, origem estrutural e risco de clonagem
- manter separado o que e registro do pattern no ambiente, o que e configuração interna, o que e dependencia de contexto/chamada e o que e referencia auxiliar/seguranca; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Folder`

- em `Folder`, revisar por blocos funcionais; não tratar o objeto como caso trivial apenas por ter shape mínimo quando a pergunta for de parent, leitura da IDE, semantica nominal ou diagnostico fino
- os blocos canonicos são `Minimal structural shape`, `Parent and module context`, `IDE semantic reading`, `Identity and naming semantics` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Minimal structural shape -> IDE semantic reading` para separar o tipo XML valido do rotulo exibido pela IDE
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Folder` inteiro por reflexo
- usar `Minimal structural shape` como bloco inicial para envelope, `Object/@type`, shape mínimo e serializacao básica
- usar `Parent and module context` como bloco inicial para `parent`, `parentGuid`, `parentType`, `moduleGuid` e encaixe estrutural do agrupador
- usar `IDE semantic reading` como bloco inicial para `Category`, leitura da IDE/importador e diferenca entre tipo XML e rotulo exibido
- usar `Identity and naming semantics` como bloco inicial para ambiguidade nominal, expectativa sobre nome exibido e semantica do agrupador
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, contêiner, origem estrutural e risco de clonagem
- manter separado o que e shape mínimo XML, o que e contexto estrutural, o que e leitura semantica da IDE e o que e semantica nominal; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Domain`

- em `Domain`, revisar por blocos funcionais; não tratar o objeto como definicao tipada trivial quando a pergunta for de limites, enumeracao, papel semantico ou diagnostico fino
- os blocos canonicos são `Base type definition`, `Limits and scalar constraints`, `Enumerated values contract`, `Usage-facing semantic contract` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Base type definition -> Enumerated values contract` para confirmar se o dominio tipado corretamente também fecha como enumeracao valida
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Domain` inteiro por reflexo
- usar `Base type definition` como bloco inicial para tipo base, `ATTCUSTOMTYPE`, definicao nuclear e contrato tipado principal
- usar `Limits and scalar constraints` como bloco inicial para tamanho, precisao, escala, flags e parâmetros escalares do dominio
- usar `Enumerated values contract` como bloco inicial para `IDEnumDefinedValues`, lista de valores, descricoes e coerência do contrato enumerado
- usar `Usage-facing semantic contract` como bloco inicial para papel funcional do dominio no consumo por outros objetos, UI ou contrato de dados
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, contêiner, origem estrutural e risco de clonagem
- manter separado o que e tipo base, o que e limite/constraint, o que e enumeracao e o que e contrato semantico de uso; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Table`

- em `Table`, revisar por blocos funcionais; não tratar o objeto como bloco físico único quando a pergunta for de chave, índice, reassociacao com `Transaction` ou diagnostico fino
- os blocos canonicos são `Primary key structure`, `Secondary indexes and embedded index members`, `Transaction coupling and physical context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Secondary indexes and embedded index members -> Transaction coupling and physical context` para separar problema de índice embutido de problema de reassociacao física
- parar a expansao quando a hipotese já estiver sustentada; não reabrir a `Table` inteira por reflexo
- usar `Primary key structure` como bloco inicial para chave primaria, membros da chave, ordem estrutural e coerência do nucleo físico principal
- usar `Secondary indexes and embedded index members` como bloco inicial para índice, membro de índice, ordenacao, cobertura de busca e leitura de `Index` embutido
- usar `Transaction coupling and physical context` como bloco inicial para relacao com a `Transaction` de mesmo nome, reassociacao física, contexto estrutural no destino e dependencia contextual da `Table`
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parentGuid`, `moduleGuid`, origem estrutural e risco de clonagem
- tratar `Index` como estrutura embutida da `Table` nesta trilha; não abrir um bloco top-level separado de `Index` por padrão
- manter separado o que e chave primaria, o que e índice embutido e o que e acoplamento fisico/contextual com `Transaction`; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `ExternalObject`

- em `ExternalObject`, revisar por blocos funcionais; não tratar o objeto como contrato externo monolitico quando a pergunta for de método, tipo, binding nativo ou diagnostico fino
- os blocos canonicos são `External contract surface`, `Method signatures and parameter typing`, `Platform and native binding metadata` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Method signatures and parameter typing -> Platform and native binding metadata` para separar erro de assinatura de erro de binding nativo
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `ExternalObject` inteiro por reflexo
- usar `External contract surface` como bloco inicial para surface exposta, nome externo, papel funcional e metodos/propriedades publicados
- usar `Method signatures and parameter typing` como bloco inicial para método, parâmetro, retorno, coerência de assinatura e dependencia tipada
- usar `Platform and native binding metadata` como bloco inicial para plataforma, assembly, biblioteca alvo, binding nativo e metadata técnica específica
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e surface funcional externa, o que e assinatura tipada e o que e binding nativo/plataforma; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `UserControl`

- em `UserControl`, revisar por blocos funcionais; não tratar o objeto como controle visual monolitico quando a pergunta for de propriedade, evento, recurso runtime ou diagnostico fino
- os blocos canonicos são `Control contract surface`, `Properties and event bindings`, `Runtime resources and external dependencies` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Properties and event bindings -> Runtime resources and external dependencies` para separar problema de binding de problema de recurso runtime
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `UserControl` inteiro por reflexo
- usar `Control contract surface` como bloco inicial para interface declarada, surface exposta, papel funcional e shape geral do controle
- usar `Properties and event bindings` como bloco inicial para propriedade, evento, parâmetro e contrato de binding entre host e controle
- usar `Runtime resources and external dependencies` como bloco inicial para script, asset, recurso externo, dependencia técnica e acoplamento de execução
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e contrato do controle, o que e binding de propriedades/eventos e o que e dependencia runtime; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `SubTypeGroup`

- em `SubTypeGroup`, revisar por blocos funcionais; não tratar o objeto como agrupamento nominal monolitico quando a pergunta for de composicao, subtype, uso contextual ou diagnostico fino
- os blocos canonicos são `Group definition and member structure`, `Subtype mappings and role assignments`, `Contextual usage contract` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Subtype mappings and role assignments -> Contextual usage contract` para separar erro de mapeamento interno de erro de uso contextual
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `SubTypeGroup` inteiro por reflexo
- usar `Group definition and member structure` como bloco inicial para composicao do grupo, membros declarados, shape estrutural e integridade do agrupamento
- usar `Subtype mappings and role assignments` como bloco inicial para supertipo, subtipo, papel de cada membro e mapeamentos internos
- usar `Contextual usage contract` como bloco inicial para papel do grupo no consumo por `Attribute`, `Transaction` e outros objetos do modelo
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e definicao do grupo, o que e mapeamento de subtype e o que e uso contextual; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `File`

- em `File`, revisar por blocos funcionais; não tratar o objeto como recurso monolitico quando a pergunta for de payload, consumo, identidade do recurso ou diagnostico fino
- os blocos canonicos são `File identity and declared surface`, `Binary or textual payload fidelity`, `References and consumption context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Binary or textual payload fidelity -> References and consumption context` para separar problema de conteúdo de problema de consumo
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `File` inteiro por reflexo
- usar `File identity and declared surface` como bloco inicial para nome do recurso, extensao lógica, role funcional e surface declarada
- usar `Binary or textual payload fidelity` como bloco inicial para conteúdo materializado, payload, extracao, preservacao binaria/textual e fidelidade do recurso
- usar `References and consumption context` como bloco inicial para referencias externas, quem consome o arquivo, dependencia de runtime e contexto de uso
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e identidade/surface do recurso, o que e payload e o que e contexto de consumo; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Dashboard`

- em `Dashboard`, revisar por blocos funcionais; não tratar o objeto como composicao visual monolitica quando a pergunta for de widget, binding, navegacao ou diagnostico fino
- os blocos canonicos são `Dashboard composition and layout`, `Widgets and data bindings`, `Navigation and interaction context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Widgets and data bindings -> Navigation and interaction context` para separar problema de dado/widget de problema de acao/interacao
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Dashboard` inteiro por reflexo
- usar `Dashboard composition and layout` como bloco inicial para composicao, seções, shape estrutural e organizacao visual do dashboard
- usar `Widgets and data bindings` como bloco inicial para widget, componente, binding, fonte de dados, parâmetro e vinculo entre visual e dado
- usar `Navigation and interaction context` como bloco inicial para ação, link, drill-down, interacao do usuário e encaixe funcional no fluxo
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e composicao do dashboard, o que e binding de widget e o que e navegacao/interacao; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Stencil`

- em `Stencil`, revisar por blocos funcionais; não tratar o objeto como molde estrutural monolitico quando a pergunta for de parâmetro, placeholder, consumo por pattern ou diagnostico fino
- os blocos canonicos são `Stencil definition and structural surface`, `Parameters and configurable slots`, `Pattern or generation consumption context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Parameters and configurable slots -> Pattern or generation consumption context` para separar problema de configuração de problema de consumo do stencil
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Stencil` inteiro por reflexo
- usar `Stencil definition and structural surface` como bloco inicial para shape do artefato, composicao declarada, estrutura-base e surface do stencil
- usar `Parameters and configurable slots` como bloco inicial para parâmetro, placeholder, ponto variável e contrato configuravel
- usar `Pattern or generation consumption context` como bloco inicial para consumo por pattern, geração ou fluxo dependente
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e definicao do stencil, o que e parametrizacao/configuracao e o que e contexto de consumo; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `DataStore`

- em `DataStore`, revisar por blocos funcionais; não tratar o objeto como definicao de armazenamento monolitica quando a pergunta for de parâmetro, configuração, conexão ou diagnostico fino
- os blocos canonicos são `Store definition and declared connection surface`, `Configuration parameters and runtime options`, `Model and consumption context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Configuration parameters and runtime options -> Model and consumption context` para separar problema de configuração de problema de consumo contextual do store
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `DataStore` inteiro por reflexo
- usar `Store definition and declared connection surface` como bloco inicial para identidade declarada do store, surface de conexão e shape principal da definicao
- usar `Configuration parameters and runtime options` como bloco inicial para parâmetro, flag, opção e configuração operacional
- usar `Model and consumption context` como bloco inicial para encaixe no modelo, consumo por objetos dependentes e papel no runtime
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e definicao do store, o que e configuração runtime e o que e contexto de consumo; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Generator`

- em `Generator`, revisar por blocos funcionais; não tratar o objeto como definicao única quando a pergunta for de parâmetro, alvo de geração, plataforma ou diagnostico fino
- os blocos canonicos são `Generator definition and declared surface`, `Generation options and technical parameters`, `Model and target-platform usage context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Generator definition and declared surface -> Generation options and technical parameters`
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Generator` inteiro por reflexo
- usar `Generator definition and declared surface` como bloco inicial para o que o gerador declara ser, seu papel principal e sua surface estrutural
- usar `Generation options and technical parameters` como bloco inicial para parâmetro, flag, opção e comportamento técnico de geração
- usar `Model and target-platform usage context` como bloco inicial para encaixe no modelo, alvo de geração, consumo efetivo e papel no fluxo
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e surface declarada do gerador, o que e parâmetro técnico e o que e contexto de uso; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Language`

- em `Language`, revisar por blocos funcionais; não tratar o objeto como definicao única quando a pergunta for de parâmetro, localização, runtime ou diagnostico fino
- os blocos canonicos são `Language definition and declared surface`, `Localization parameters and technical options`, `Model and runtime usage context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Language definition and declared surface -> Localization parameters and technical options`
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Language` inteiro por reflexo
- usar `Language definition and declared surface` como bloco inicial para o que o objeto declara ser, seu papel principal e sua surface estrutural
- usar `Localization parameters and technical options` como bloco inicial para parâmetro, opção, código, flag e configuração técnica de localização
- usar `Model and runtime usage context` como bloco inicial para encaixe no modelo, consumo efetivo, vinculo com runtime e papel funcional do idioma
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e surface declarada do idioma, o que e parâmetro técnico e o que e contexto de uso; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Document`

- em `Document`, revisar por blocos funcionais; não tratar o objeto como artefato único quando a pergunta for de payload, referencia, consumo ou diagnostico fino
- os blocos canonicos são `Document identity and declared surface`, `Materialized content and payload fidelity`, `References and functional consumption context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Document identity and declared surface -> Materialized content and payload fidelity`
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Document` inteiro por reflexo
- usar `Document identity and declared surface` como bloco inicial para o que o documento declara ser, nome, papel principal e surface estrutural
- usar `Materialized content and payload fidelity` como bloco inicial para conteúdo materializado, integridade do payload, preservacao de texto/bytes e fidelidade de extracao
- usar `References and functional consumption context` como bloco inicial para quem consome o documento, vinculos externos, dependencia funcional e papel no fluxo
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e surface declarada do documento, o que e payload e o que e contexto de consumo; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `DeploymentUnit`

- em `DeploymentUnit`, revisar por blocos funcionais; não tratar o objeto como unidade única quando a pergunta for de parâmetro, entrega, empacotamento ou diagnostico fino
- os blocos canonicos são `Deployment unit definition and declared surface`, `Packaging parameters and technical options`, `Runtime or delivery context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Deployment unit definition and declared surface -> Packaging parameters and technical options`
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `DeploymentUnit` inteiro por reflexo
- usar `Deployment unit definition and declared surface` como bloco inicial para o que a unidade declara ser, seu papel principal e sua surface estrutural
- usar `Packaging parameters and technical options` como bloco inicial para parâmetro, opção, flag e configuração técnica de empacotamento/entrega
- usar `Runtime or delivery context` como bloco inicial para encaixe no fluxo, destino de entrega, consumo efetivo e papel operacional
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `parent`, `moduleGuid`, origem estrutural e risco de clonagem
- manter separado o que e surface declarada da unidade, o que e parâmetro técnico e o que e contexto de entrega/uso; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Panel`

- em `Panel`, revisar por blocos funcionais; não tratar XML curto como sinal automático de revisao simples quando a pergunta for de estrutura, comportamento, pattern, parent ou diagnostico fino
- os blocos canonicos são `Panel structure and layout`, `Serialized behavior and configuration`, `Pattern and parent coupling`, `External dependencies` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Panel structure and layout -> Pattern and parent coupling` para separar a tela aparente do contexto estrutural que a sustenta
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `Panel` inteiro por reflexo
- usar `Panel structure and layout` como bloco inicial para composicao visual, controles, shape da tela e estrutura funcional aparente
- quando o sintoma for warning `Layout com identificador incorreto`, tratar `level id` e `layout id` como par acoplado; não testar nem recomendar GUID avulso de layout como correcao suficiente
- para Panel SD gerado ou clonado, preferir par `level id` + `layout id` vindo de Panel SD exportado pela IDE da mesma KB; se a regra exata de derivacao não estiver provada, declarar risco e não inventar GUIDs independentes
- para Panel SD com actions, ler `detail/@events` antes de concluir quais eventos existem; `onClickEvent="'Nome'"` deve ser confrontado com `Event 'Nome'` no comportamento serializado
- não sintetizar `Event Controle.Tap` em Panel SD sem evidencia equivalente em molde real comparavel da mesma KB; quando o molde vincular action a evento nomeado, preservar a forma nomeada
- ao executar `scripts\Test-GeneXusImportFileEnvelope.ps1`, passar `-PanelReferencePath <objeto-ou-pacote-comparavel>` quando houver referencia real disponível; tratar `panel-level-layout-confirmed` somente no campo JSON `information`, quando o mesmo par for encontrado, e manter em `warnings` `panel-level-layout-unverified` sem referencia ou `panel-level-layout-suspicious` quando a referencia não confirmar o par
- usar `Serialized behavior and configuration` como bloco inicial para comportamento serializado, configuração persistida e metadado funcional não redutivel a decoracao visual
- usar `Pattern and parent coupling` como bloco inicial para `parent`, `parentGuid`, `parentType`, `moduleGuid`, pattern de origem e acoplamento estrutural do painel
- usar `External dependencies` como bloco inicial para objeto externo chamado, vinculo necessário e dependencia funcional fora do próprio painel
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, contêiner, origem estrutural e risco de ter aberto o painel errado
- manter separado o que e superficie funcional do painel e o que e dependencia estrutural do contexto de origem; não colapsar essas camadas cedo demais

### Regra adicional para revisao de `Transaction`

- em `Transaction`, revisar por blocos funcionais; não tratar a transacao inteira como bloco único de leitura
- os blocos canonicos são `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Rules -> Execution context` para separar efeito via edicao web de efeito via BC
- parar a expansao quando a hipotese já estiver sustentada; não reabrir a `Transaction` inteira por reflexo
- usar `Transaction structure` como bloco inicial para `Level`, chave, `DescriptionAttribute`, shape estrutural e composicao transacional
- usar `Attributes and attribute properties` como bloco inicial para atributos, `AttributeProperties`, subtipo e contrato de dados
- usar `Rules` como bloco inicial para regra declarativa, obrigatoriedade e efeito normativo da transacao
- usar `Events` como bloco inicial para comportamento via interface, ação do usuário e fluxo via edicao web
- antes de gerar ou editar `Rules` ou `Events` em `Transaction` no XPZ, consultar o catálogo em `xpz-builder/responsibilities-by-type/transaction.md` (seção **Catalog: `on <event>` clauses…**); com `src0056` em `Rules`, `src0239` em `Rules`, `spc0150` em `Events`, ou `Find-CsAttributeAssignments.ps1` indicando sombra por cascata, ver anti-padroes `transaction-rule-on-event-with-attribute-parameter`, `transaction-default-rule-with-conditional`, `transaction-event-attribute-assignment-rejected` e `transaction-attribute-rule-shadowed-by-default-in-cascade` em `02-regras-operacionais-e-runtime.md` — escopo motor XPZ; uso correto de linguagem GeneXus: **nexa**
- usar `Execution context` como bloco inicial quando a duvida central for a diferenca entre via edicao web e via BC
- usar `Identity and container` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, origem estrutural e risco de clonagem
- ao materializar ou estender catalogo de `Rules`/`Events` em `Transaction`, aplicar os rotulos de evidencia e permissao de geração em `02-regras-operacionais-e-runtime.md` (**Politica de evidencia para catalogos `Transaction` (geração XPZ)**) e em `xpz-builder/responsibilities-by-type/transaction.md` (**Evidence labels for Transaction catalogs**); só gerar sintaxe com `confirmado-import`, `confirmado-build` ou `confirmado-acervo`
- exemplos por nome de arquivo no acervo real (`ObjetosDaKbEmXml/...` na pasta paralela) ou molde sanitizado em `01*` — não presumir que o XML está versionado nesta raiz `GeneXus-XPZ-Skills`

### Regra adicional para revisao de `WebPanel`

- em `WebPanel`, revisar por blocos funcionais; não abrir o XML inteiro como massa única quando a pergunta for de comportamento, filtro, evento ou diagnostico fino
- os blocos canonicos são `layout`, `events`, `variables`, `metadado funcional serializado`, `identidade e contêiner` e `dependencias`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `events -> variables` para validar contrato local
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o objeto inteiro por reflexo
- tratar `metadado funcional serializado` como camada própria; ele pode viver perto do layout, mas não deve ser lido como decoracao visual
- usar `events` como bloco inicial para ações do usuário, refresh, start, load, chamadas e validação procedural
- usar `layout` como bloco inicial para composicao visual, estrutura de grid/tab/controle e bindings visiveis
- usar `variables` como bloco inicial para tipo, declaracao, coerência de uso e colecao vs simples
- usar `metadado funcional serializado` como bloco inicial para `Conditions`, `ControlWhere`, `ControlBaseTable`, `ControlOrder`, `ControlUnique`, `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, `WebUserControlProperties` e marcas de pattern
- se a leitura do layout serializado em `CDATA` vier truncada, não remontar o layout manualmente; extrair o bloco completo por método estruturado ou operar por substituicao cirurgica no raw integral
- ao buscar texto em XML de `WebPanel`, não usar match bruto em `<Source><![CDATA[<GxMultiForm...` como evidencia de comportamento em `events`; `GxMultiForm` prova camada de `layout` ou metadado serializado, não code-behind
- para busca textual pontual em `Source` de `WebPanel`, preferir `scripts\Search-GeneXusXmlSourceBlock.ps1 -Block events` quando a pergunta for sobre evento, chamada, validação ou fluxo; usar `-Block layout` apenas quando o sintoma for visual ou de binding visivel
- se uma busca direta com `rg`/`grep` for inevitavel, filtrar ou classificar separadamente matches em `GxMultiForm`, `labelCaption`, `PATTERN_ELEMENT_CUSTOM_PROPERTIES` e linhas de `events`, sem despejar o `CDATA` gigante na resposta
- usar `identidade e contêiner` como bloco inicial para `parent`, `module`, `fullyQualifiedName`, risco de clonagem e classificação estrutural
- usar `dependencias` como bloco inicial quando o sintoma nascer de `MasterPage`, pattern, user control, objeto chamado ou vinculo externo ausente

### Regra adicional para revisao de `WorkWithForWeb`

- em `WorkWithForWeb`, revisar por blocos funcionais; não ler o objeto como XML pequeno autossuficiente quando a pergunta for de comportamento, filtro, navegacao, action ou diagnostico fino
- os blocos canonicos são `Transaction binding`, `Pattern structure and navigation`, `Actions, links and prompts`, `Attribute references and data contract` e `Identity and container`
- antes da análise fina, declarar qual é o bloco primario do sintoma atual
- abrir bloco adjacente apenas quando houver dependencia funcional explicita com o bloco primario
- nomear a transicao de bloco no raciocinio e no handoff, por exemplo: `Actions, links and prompts -> Pattern structure and navigation` para validar em qual `Selection` a action realmente mora
- parar a expansao quando a hipotese já estiver sustentada; não reabrir o `WorkWithForWeb` inteiro por reflexo
- usar `Transaction binding` como bloco inicial para `parent`, `parentGuid`, `parentType`, `Transaction` associada, acoplamento estrutural e suspeita de WW ligado ao pai errado
- usar `Pattern structure and navigation` como bloco inicial para `selection`, abas, `view`, filtros, navegacao e shape funcional interno do pattern
- usar `Actions, links and prompts` como bloco inicial para action, botao, item de menu, `gxobject`, link, prompt e abertura explicita de outro objeto
- usar `Attribute references and data contract` como bloco inicial para atributo exibido, filtro por atributo, coluna, aba dependente de atributo, referencia quebrada e convenio estrutural `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`
- usar `Identity and container` como bloco inicial para `name`, `fullyQualifiedName`, `guid`, `moduleGuid`, contêiner, origem estrutural e risco de confundir a instancia alvo
- tratar `WebPanel` gerado ao redor e `WorkWithPlus` apenas como dependencias externas explicitas; eles não são bloco funcional interno canonico de `WorkWithForWeb`

## Regra de leitura para XPZ

- antes de usar `xpz-sync`, `xpz-builder` ou `xpz-doc-builder` em fluxo dependente de repositório, confirmar que a pasta paralela da KB está montada e validada; se não estiver, usar `xpz-kb-parallel-setup` primeiro
- quando a tarefa envolver montar ou serializar `XPZ`, consultar primeiro a seção `Envelope XPZ observado em export real` de `02-regras-operacionais-e-runtime.md`
- distinguir sempre a pasta nativa da KB da pasta paralela da KB; nesta trilha, os `XPZ`, os XMLs materializados e os artefatos de importação vivem na pasta paralela da KB, não dentro da pasta nativa da KB
- tratar a pasta nativa da KB como area proibida para gravacao por agentes; leitura e permitida apenas quando o fluxo operacional explicito realmente exigir
- em setup inicial padrão de pasta paralela da KB, com pasta nativa já informada, sem nomes alternativos e sem conflito estrutural visivel, evitar exploracao ampla do motor compartilhado e dos exemplos antes de criar a estrutura base; aprofundar exploracao só se surgir bloqueio concreto
- quando a inspecao local da pasta contradisser contexto indireto do ambiente, da sessao ou de hooks, confiar primeiro na inspecao local e seguir com verificacao curta e objetiva; não gastar o handoff especulando longamente sobre o conflito
- quando a tarefa envolver gerar, ajustar, preservar ou empacotar XMLs, distinguir explicitamente as tres areas operacionais do repositório: `ObjetosDaKbEmXml`, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus`
- em auditoria de pasta paralela de KB, declarar separadamente `sync/materializacao`, `indice/gate` e `empacotamento local`; não concluir "tudo certo" só porque gate e estrutura passaram quando o fluxo de empacotamento local ainda não foi auditado
- na carga inicial, considerar também `XpzExportadosPelaIDE` como pasta de entrada padrão, `scripts` como pasta de wrappers, `Temp` como destino preferencial de artefatos efemeros de execução, `KbIntelligence` como pasta do índice derivado, e as demais pastas como estrutura funcional padrão quando o usuário não informar nomes alternativos
- se alguma dessas pastas ainda não existir, criar nesta ordem: `scripts`, `Temp`, `XpzExportadosPelaIDE`, `ObjetosDaKbEmXml`, `KbIntelligence`, `ObjetosGeradosParaImportacaoNaKbNoGenexus`, `PacotesGeradosParaImportacaoNaKbNoGenexus`
- quando a pasta paralela já estiver versionada em Git e o setup inicial estiver criando a estrutura do zero, tratar `.gitignore` na raiz e `.gitkeep` nas subpastas estruturais vazias como parte esperada do bootstrap
- quando a pasta paralela ainda não estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local como passo opcional; não deve executar `git init` sem aprovacao explicita do usuário
- se o usuário aceitar versionamento Git local e o Git não estiver funcional no ambiente, o agente pode oferecer instalar ou orientar a instalacao antes do bootstrap Git
- mudar `.gitignore`, politica de versionamento ou escopo de arquivos rastreados para viabilizar `git add`/`commit` e decisão de politica do repositório; o agente pode diagnosticar e propor opções, mas não deve alterar essa politica automaticamente só para concluir o fechamento
- se o setup inicial da pasta paralela da KB estiver sendo preparado e o caminho da pasta nativa da KB não vier no prompt, pedir esse caminho ao usuário antes de concluir o setup
- no setup inicial, gerar `kb-source-metadata.md` inicial em formato compativel com o motor compartilhado, preservando o campo nominal `last_xpz_materialization_run_at`
- no setup inicial, não salvar memoria operacional fora da própria pasta paralela da KB sem autorizacao explicita do usuário; `AGENTS.md`, `README.md` e arquivos operacionais locais são a camada preferencial de memoria
- no setup inicial da pasta paralela da KB, não declarar `setup concluido`, `estrutura pronta` ou equivalente final antes de a camada mínima de wrappers locais esperados em `scripts` existir para o fluxo oficial adotado
- se a estrutura de pastas e documentos estiver pronta, mas a camada mínima de wrappers locais ainda não existir, o status correto e `estrutura parcial` ou `bootstrap incompleto`, não `setup concluido`
- `Test-*KbSourceSanity.ps1` e wrapper recomendado quando a pasta também adotar fluxo local de geração e empacotamento; sua ausencia isolada não impede, por si só, reconhecer a camada mínima do fluxo oficial de materialização ou de `KbIntelligence`
- se o setup inicial registrar memoria local provisoria como `ObjetosDaKbEmXml ainda nao materializada`, `aguardando primeiro XPZ` ou equivalente, esse estado precisa ser atualizado ou neutralizado depois da primeira materialização oficial bem-sucedida
- se `XpzExportadosPelaIDE` ainda não existir, perguntar onde o usuário quer salvar os `.xpz`
- se `ObjetosDaKbEmXml` ainda não existir, tratar a KB como ainda não materializada e parar antes de assumir snapshot
- se `KbIntelligence` ainda não existir, tratar isso como ausencia da camada derivada de triagem, não como ausencia do snapshot oficial; preparar a pasta e os wrappers locais antes de depender de `xpz-index-triage`
- nesta trilha, `ObjetosDaKbEmXml` e snapshot oficial e somente leitura para agentes
- nesta trilha, `KbIntelligence\kb-intelligence.sqlite` e índice derivado e regeneravel a partir de `ObjetosDaKbEmXml`
- nesta trilha, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e a area de trabalho para XMLs a importar manualmente na IDE
- nesta trilha, cada frente ativa deve usar sua própria subpasta `NomeCurto_GUID_YYYYMMDD` dentro de `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- se a conversa continua a mesma frente ativa, microajustes sucessivos devem reutilizar essa subpasta; não criar nova subpasta por tentativa, ajuste visual ou reimportacao da mesma frente
- nesta trilha, os arquivos ativos do lote devem ficar dentro da subpasta ativa da frente, e não soltos na raiz da area de trabalho
- XML de referencia, exemplo ou template não deve permanecer dentro da frente ativa; se aparecer ali, bloquear o empacotamento ate remover ou tratar por caminho explicito fora da area gerenciada
- nesta trilha, `PacotesGeradosParaImportacaoNaKbNoGenexus` e a area de saida para pacotes gerados localmente
- por padrão, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` não precisam ser versionadas em Git; se houver duvida sobre rastrear ou ignorar seu conteúdo, tratar isso como decisão de politica do repositório e pedir aprovacao explicita
- nesta trilha, a promocao para snapshot oficial ocorre apenas pelo script `.ps1` alimentado por `XPZ` exportado pela IDE
- ao concluir o setup inicial da pasta paralela da KB, deixar explicito que a estrutura está pronta, mas `ObjetosDaKbEmXml` ainda não foi materializada
- se `Test-*KbSourceSanity.ps1` for criado ou atualizado durante a frente, valida-lo diretamente antes do fechamento; `STRUCTURE_OK` e `GATE_OK` não bastam como prova desse wrapper, porque o checklist estrutural canonico não o trata como mínimo universal e porque um parâmetro que o motor compartilhado não declara (ex: `-AsJson` em wrapper que delega a `Test-GeneXusSourceSanity.ps1`, que emite JSON por padrão) e erro de binding em runtime invisivel ao parse; comparar a linha de chamada do motor contra o exemplo canonico e, havendo XML local seguro, exigir a execução consultiva do wrapper, não apenas prefer-la
- ao concluir o setup inicial, oferecer dois próximos passos: `A)` o usuário exporta o `.xpz` full pela IDE para `XpzExportadosPelaIDE`; `B)` o agente tenta gerar o `.xpz` full a partir da pasta nativa da KB, grava o arquivo em `XpzExportadosPelaIDE` e depois materializa os XMLs
- ao oferecer `A)` e `B)`, declarar que `A)` e o caminho preferencial e normalmente mais rápido, enquanto `B)` tende a demorar mais por depender da trilha via `MSBuild`
- ao orientar o caminho `A)`, preferir descrição funcional estavel como `export full da KB pela IDE` em vez de depender de rotulos exatos de menu, tela ou botao do GeneXus como se fossem universais; se citar caminho de menu, apresentá-lo depois da instrucao principal e marcado explicitamente como exemplo opcional de navegacao, nunca como passo normativo principal
- se o usuário escolher `B)`, usar a skill `xpz-msbuild-import-export` e não improvisar exportação fora dessa trilha
- quando a skill de `MSBuild` for publicada por symlink, junction ou outro reparse point, resolver referencias `../` pela pasta real da skill, não pelo caminho launcher publicado
- ao concluir a exportação headless do caminho `B)`, declarar explicitamente o marco `XPZ gerado` antes de prosseguir para materialização em `ObjetosDaKbEmXml`
- se o pedido do usuário for apenas gerar o `.xpz`, parar no artefato gerado; só prosseguir para materialização quando o pedido for seguir com o setup ou com a materialização
- em handoff de pasta paralela da KB, declarar marcos operacionais separados, sem colapsar um no outro:
  - `setup de estrutura`: pastas e memoria local básica foram criadas ou validadas
  - `bootstrap de wrappers`: wrappers locais minimos existem e são compativeis com o fluxo oficial adotado
  - `XPZ gerado`: artefato `.xpz` existe em `XpzExportadosPelaIDE` ou no destino aprovado, mas ainda não implica materialização
  - `materializacao em ObjetosDaKbEmXml`: XMLs oficiais foram criados/atualizados pelo fluxo oficial a partir do `XPZ`
  - `refresh/validacao do indice`: `KbIntelligence` foi regenerado/validado e tem `last_index_build_run_at >= last_xpz_materialization_run_at`, `inventory_validation_status=OK` e assinatura do extrator alinhada com `scripts/Build-KbIntelligenceIndex.py` no repositório ativo
  - `conferencia full`: verificacao posterior do acervo, que não substitui nem deve sobrescrever o relatório da materialização principal
- em auditoria de setup de pasta paralela que adota `KbIntelligence`, validar o contrato de `Get-*KbMetadata.ps1` pelo gate local `Test-*KbMetadataWrapper.ps1` quando ele existir; se o gate bloquear, não classificar o wrapper de metadata como equivalente por inspecao textual
- `XPZ` full define o insumo exportado; `FullSnapshot` define modo adicional de verificacao do acervo
- sob `-FullSnapshot`, o motor reconcilia o acervo por `guid` (identidade estável do nó raiz), não só por nome: rename (mesmo `guid`, nome diferente) é tratado como rename — renomeia o arquivo no acervo (`Move-Item` antigo → novo), cobre `Attribute` e `Object`, e reporta `RenamedByGuid`; em `-VerifyOnly` apenas classifica o resíduo (`RenameResidualsDetected`) sem tocar o disco. Um nome antigo que deixou de existir por rename reconhecido por `guid` não é deleção cega de acervo
- na materialização normal do `XPZ` em `ObjetosDaKbEmXml`, inclusive na primeira carga por `XPZ` full vindo da IDE ou por export headless via `MSBuild`, não presumir `-FullSnapshot` como padrão implicito nem como atalho ergonomico
- usar `-FullSnapshot` apenas quando houver pedido explicito do usuário por conferencia full, quando o wrapper específico de conferencia full for o caminho escolhido ou quando a documentação local exigir isso nominalmente
- quando o resumo do sync expuser `MaterializationInterpretation`, preferir esse campo para explicar o resultado da materialização; não reinventar a leitura a partir de `Created`, `Updated` e `Unchanged`
- o resultado do sync é uma **linha JSON de máquina no stdout** (`Kind=xpz-sync-result`, `-Compress`); todo texto humano sai no stderr. Consumir via `ConvertFrom-Json`, não parsear o texto. Em processo filho (`pwsh -File`), `Write-Host`/`Write-Warning`/`Write-Information` vazam para o stdout capturado — por isso o contrato exige stderr para diagnóstico
- para nomear os objetos sem `git diff`, usar as listas nominais do resultado: `CreatedNames`/`UpdatedNames`/`UnchangedNames`/`SkippedOlderLastUpdateNames` (`"Tipo:Nome"`), `RenamedByGuidItems` e, com `-ExpectedItems`, `ExpectedReturnedNames`/`ExpectedMissingNames`/`AdditionalOfficialNames` (fonte das três partes do handoff). Ao apresentar, regra por categoria: ≤10 listar; >10 contador + amostra + oferecer lista completa no chat
- não afirmar `primeira carga`, `primeira materializacao` ou equivalente quando `Created = 0` e `Unchanged > 0`; sem evidencia previa adicional, isso indica apenas confirmacao de snapshot já existente contra o insumo atual
- se houver relatório da primeira materialização e outro de reprocessamento confirmatorio ou conferencia full, não misturar os papeis no handoff; identificar explicitamente qual arquivo representa a materialização que criou/atualizou o acervo e qual arquivo representa apenas verificacao posterior
- se a execução tiver primeira materialização seguida de reprocessamento confirmatorio ou conferencia full, preferir caminhos ou nomes de relatório separados; não sobrescrever silenciosamente o relatório principal da primeira materialização com o da segunda passagem
- só afirmar metadado específico de `kb-source-metadata.md`, como versão do GeneXus, build, GUID da KB, usuário ou caminho `Source`, quando esse metadado tiver aparecido explicitamente na saida real do wrapper ou quando o próprio `kb-source-metadata.md` tiver sido aberto e lido nominalmente na rodada atual
- tratar `kb-source-metadata.md` por autoridade de campo: identidade estavel da KB vem do setup/resolvedor da KB nativa local ou de XPZ completo e coerente com ela; `KMW` vem de XPZ real ou template comparavel; timestamps de materialização pertencem ao `xpz-sync`; `last_setup_audit_run_at` e `setup_contract_signature_*` pertencem ao setup/auditoria
- quando o sync XPZ/XML atualizar `kb-source-metadata.md` com `-KbMetadataPath`, usar `Sync-GeneXusXpzToXml.ps1` via `XpzKbSourceMetadataEditSupport.ps1` para atualizacao **cirurgica** dos campos de materialização, preservando `last_setup_audit_run_at`, `setup_contract_signature_*`, frontmatter fora do escopo e EOL dominante (`XpzTextFileEolSupport.ps1`); não regerar o arquivo inteiro nesse caminho
- no gatilho global de `xpz-kb-parallel-setup`, tratar `GATE_ONLY` + `GATE_OK` como caminho leve de seguranca para liberar a tarefa normal; `AUDIT_REQUIRED` por assinatura de contrato de setup ausente, invalida ou defasada e deliberado após `git pull` que altere a superficie de `xpz-kb-parallel-setup`; deve cair em auditoria completa, não em heuristica local de "mudanca pequena". Commits fora dessa superficie não devem, por si só, disparar auditoria completa.
- após auditoria de setup bem-sucedida com `GATE_OK`, gravar `last_setup_audit_run_at` e `setup_contract_signature_*` na mesma sessao via `Set-XpzSetupAuditTimestamp.ps1` (wrapper `Set-*KbSetupAuditTimestamp.ps1`) quando o freshness tiver exigido auditoria por campo ausente, assinatura ausente ou assinatura defasada; não recomendar rodada separada por padrão
- após auditoria mínima de pasta paralela (`xpz-kb-parallel-setup`), apresentar plano consolidado de correcoes com todos os itens corrigiveis detectados e oferecer executar na mesma sessao; não encerrar só com diagnostico quando o plano tiver ao menos uma linha; `GATE_OK` libera a tarefa do usuário mas não dispensa o plano
- para reconciliar identidade estavel aprovada em `kb-source-metadata.md`, usar `Resolve-GeneXusKbIdentity.ps1` para leitura da KB nativa local e `Update-XpzKbSourceMetadataIdentity.ps1` para escrita localizada; preencher ausentes e bloquear divergencias não vazias salvo aprovacao explicita de sobrescrita
- tratar `metadata wrapper` diferente de `OK` como pendencia metodologica real: se houver `PENDENTE_DE_DADOS`, `PENDENTE` ou `BLOCK`, não declarar `materializado_e_indice_validado` ate reconciliar o metadado ausente ou corrigir o wrapper; `GATE_OK` não neutraliza essa pendencia
- tratar `metadata/deploy` diferente de `OK` como pendencia metodologica real: `metadata wrapper: OK` não prova lista correta de environments nem mapeamento de output/web; perguntar nomes e diretórios de output ao usuário, gravar com `-KbEnvironmentNames` e `-KbEnvironmentOutputDirs`, e validar via MSBuild; corrigir wrapper local se `INVENTORY_CUSTOMIZED` apontar `uses_removed_inventory_discovery`, ausencia de `-KbEnvironmentNames` ou ausencia de `-KbEnvironmentOutputDirs`
- se `Source/@kb` de pacote, template ou XPZ vier preenchido com GUID diferente da KB nativa local esperada, não substituir esse GUID por conta própria nem prosseguir com import headless; bloquear a automacao e orientar o usuário a avaliar/importar manualmente pela IDE
- não presumir `Objects.xml` isolado nem manifesto externo separado se isso não estiver documentado no `02`
- usar o envelope sanitizado documentado na base como referencia estrutural antes de pedir XML externo adicional
- depois da bateria de importação e da consulta ao acervo real, separar explicitamente `problema de envelope`, `problema de shape minimo` e `problema de dependencia da KB`
- se existir export real comparavel da IDE para a mesma composicao de objetos, esse export deve prevalecer sobre envelope leve hipotetico
- em pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure`, preferir pacote embutido comparavel antes de tentar envelope por `FilePath`
- se houver mais de um lote plausivel no workspace, o agente deve parar antes de empacotar e sinalizar contaminacao de workspace
- o agente não deve fechar pacote por inferencia, por recencia presumida ou por mistura implícita de frentes
- o agente deve distinguir explicitamente `mesmo objeto` de `mesma frente`
- reusar precedente estrutural de pacote não autoriza herdar automaticamente a identidade nominal da frente anterior
- quando a continuidade da frente não estiver fechada por evidencia direta ou confirmacao explicita do usuário, o agente deve explicitar a ambiguidade antes de nomear pasta ou pacote
- se um `XPZ` oficial vindo da KB trouxer objetos adicionais além do foco imediato da frente, o agente deve informar o inesperado sem presumir erro; isso pode ser mudanca paralela legitima feita diretamente na IDE do GeneXus
- o agente deve distinguir explicitamente `artefato da frente atual`, `mudanca paralela legitima vinda da KB/IDE` e `mudanca lateral indevida do proprio agente fora do escopo`
- quando houver contexto esperado da frente, o agente pode comparar opcionalmente `foco esperado` versus `retorno oficial`, classificando `esperados que voltaram`, `esperados que nao voltaram` e `retorno oficial adicional da KB`, sem transformar a ausencia desse contexto em erro
- frente validada tecnicamente não implica publicacao Git; a conclusao técnica e apenas `validado_tecnicamente` ate o usuário autorizar o fechamento
- enquanto não houver autorizacao explicita, o agente pode sugerir os próximos passos de Git e publicacao, mas não pode executar `git add`, `commit` ou `push`
- a ordem obrigatória é: isolar lote, classificar raizes, validar fidelidade textual do delta, validar `lastUpdate`, validar BOM, validar manifesto, validar `XML bem-formado`, validar sanidade mínima do `Source` quando aplicavel, e só entao empacotar
- ao gerar copia alterada de XML GeneXus em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, preservar o XML de origem fora do delta funcional aprovado: comentarios, `CDATA`, indentacao, linhas em branco, ordem de nos, quebras de linha e whitespace herdado não devem mudar por reserializacao ou reconstrucao ampla
- não introduzir espacos ou tabs finais em linhas novas ou modificadas; a verificacao posterior serve para confirmar que o agente não criou ruido, não para limpar retrospectivamente o snapshot oficial
- antes de empacotar, comparar a copia alterada com o XML de origem e bloquear se o diff trouxer apenas whitespace, indentacao, quebra de linha, comentario removido ou outra mudanca textual não funcional fora do delta aprovado
- para editar o delta aprovado em XML GeneXus grande (`Rules`, `Source`, `CDATA` longo), preferir `scripts\Edit-GeneXusXmlSurgical.ps1` (`-DryRun` antes do apply, `-LastUpdateBaselinePath` apontando para `ObjetosDaKbEmXml`, `-EditMode Replace` ou `InsertAfter`); evitar substituicao por trecho no harness e scripts ad-hoc por frente; ver `xpz-builder/SKILL.md`
- para apenas re-carimbar o `lastUpdate` de um XML da frente já editado (rodada 2+), sem copiar do acervo nem aplicar delta, usar `scripts\Set-GeneXusXmlLastUpdate.ps1` (`-InputPath`, `-BaselineXmlPath` opcional, `-DryRun`, `-AsJson`); recalcula `max(UtcNow + margem, baseline + margem)` e grava in-place com backup e validação, em vez de busca-e-troca manual; sem `-BaselineXmlPath`, o baseline e o próprio arquivo; ver `xpz-builder/SKILL.md`
- quando a mudanca tocar `Source` e exigir variáveis novas ou alteradas, declarar a transicao `Source -> Variables` (ou equivalente por tipo) como bloco adjacente justificado; medir EOL/encoding/indentacao do XML alvo antes do patch
- em `Source`, inserir texto com a indentacao observada no próprio `Source`; em `<Variables>`, preservar a indentacao estrutural observada na seção, que pode ser diferente da do código
- para variável nova, clonar forma comparavel primeiro do próprio objeto, depois de objeto do mesmo tipo na KB, e só por último de molde sanitizado; não usar lista fixa universal de propriedades para todos os tipos
- antes de empacotar, rodar `scripts\Test-GeneXusObjectVariableDelta.ps1 -InputPath <xml> -VariableName <nomes> -AsJson` para variáveis novas/tocadas; `status=fail` bloqueia, `status=warn` exige revisao explicita
- manifesto não implica automaticamente arquivo físico; por padrão, ele deve ser apresentado na própria conversa
- para `WorkWithWeb` com ruído comprovado de `Load Code` em `Selection` e/ou tabs de `View`, registrar isso como não funcional no manifesto e não generalizar para todo caso de `WorkWithWeb`
- ao gerar pacote local para importação na IDE, preferir nome no formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- nesse formato, `NomeCurto` identifica a frente, `GUID` e `YYYYMMDD` identificam a abertura da frente, e `nn` representa apenas a rodada curta daquela frente
- antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar se já existe pacote com o mesmo prefixo `NomeCurto_GUID_YYYYMMDD` e o mesmo `nn` em `PacotesGeradosParaImportacaoNaKbNoGenexus`
- quando a regra for deterministica e houver gate `.ps1` correspondente, executar o gate em vez de decidir por heuristica textual; para colisao de pacote, preferir `Test-*KbPackageCollision.ps1` ou o engine compartilhado `scripts\Test-XpzPackageCollision.ps1`
- se o mesmo prefixo e o mesmo `nn` já existirem, o gate deve abortar a gravacao; não sobrescrever silenciosamente a rodada
- quando houver colisao de `nn`, retornar o erro explicito e a sugestao do próximo `nn` livre emitidos pelo próprio gate, sem autoincrementar nem gravar automaticamente com o valor sugerido
- `OBSOLETO_` não é convencao principal de nome; usar só como contencao de risco quando dois pacotes da mesma frente puderem ser confundidos

## Regra de leitura para XPZ via MSBuild

- quando a frente envolver `MSBuild` headless, consultar primeiro o plano e a skill experimental correspondente antes de presumir suporte de parâmetros da task `Import`
- tratar `UpdateFile` e `ImportKBInformation` como capacidades dependentes da assinatura real da task carregada, não apenas da documentação offline
- se a instalacao expuser `PreviewMode`, `IncludeItems` e `ExcludeItems`, priorizar esses caminhos para inspecao controlada antes de importação real **quando import real ainda não foi autorizado na sessao ou a rodada for exploratoria**
- quando o usuário já autorizou importação real headless na mesma sessao e `xpz-msbuild-import-export` registrou envelope `apto para prosseguir` e inventario do pacote sem bloqueio de extras, seguir **Decisão pos-gates** dessa skill (`Invoke-GeneXusXpzImport.ps1` na mesma rodada, com `-StartWatcher` e `-MonitorLogPath`, sem `Test-GeneXusXpzImportPreview.ps1` obrigatório antes); não encerrar após o gate de envelope nem exigir novo preview só por rotina geral
- na **Decisão pos-gates**, `-StartWatcher` e `-MonitorLogPath` são obrigatórios na mesma invocacao de `Invoke-GeneXusXpzImport.ps1`; as exceções por justificativa para ausencia de watcher nos bullets abaixo **não** se aplicam a esse caminho (contrato em `xpz-msbuild-import-export/SKILL.md`)
- quando `IncludeItems` ou `ExcludeItems` vierem com múltiplos recortes, normalizar a entrada como lista e serializar em formato de lista aceito pela task carregada; não presumir que uma string única separada por virgulas sera aceita como um único item
- se o wrapper devolver diagnostico estruturado, manter `importedItems` sempre como lista, inclusive com item único
- ao conferir item esperado versus importado, comparar também os campos canonicos do diagnostico (`expectedItemsCanonical` e `importedItemsCanonical`); `Panel:Nome` e `SDPanel:Nome` contam como o mesmo item quando aparecem em `itemAliasMatches`, mas a resposta deve citar a forma crua quando ela for relevante
- após preview ou importação MSBuild, preferir `compactSignals` no diagnostico JSON para leitura compacta de itens, warnings, erros, `gxImportLogReadStatus`/`gxImportLogReadError` e campos canonicos; se `compactSignals` estiver ausente, nulo ou insuficiente, usar o arquivo lateral `msbuild.import.signals.json` (gerado por `Read-MsBuildImportSignals.ps1` via `Test-GeneXusXpzImportPreview.ps1` ou `Invoke-GeneXusXpzImport.ps1`); só reparsear `msbuild.stdout.log`/`msbuild.stderr.log` inteiros quando ambos estiverem ausentes ou insuficientes
- em resposta ao usuário, separar explicitamente `sucesso operacional da chamada MSBuild`, `preview sem alteracao real da KB`, `sucesso operacional com falha no pos-processamento` (MSBuild concluiu com `executionEvidence.msBuildExitCode=0` e a evidencia primaria do log bruto está presente — import/export: `__IMPORTED_ITEM__` ou `__EXPORTED_FILE__` mais arquivo XPZ existente; build-all: `__BUILDALL_DONE__=true` e/ou `observedContext.BuildAllDone=true`; specify-generate: `__SPECIFY_DONE__=true` e/ou `__GENERATE_DONE__=true` e/ou marcas equivalentes em `observedContext` —, mas o pos-processamento local do wrapper falhou e o JSON saiu com `postProcessingFailed=true`; não reclassificar como `falha operacional` nem exit 90 quando a task MSBuild estiver limpa), `preview apenas com falha no pos-processamento` (analogo na fase de preview: `executionEvidence.msBuildExitCode=0` sem alterar a KB, evidencia primaria preservada no log bruto, mas pos-processamento local falhou) e `confirmacao funcional pendente na IDE oficial`
- em `Invoke-GeneXusKbBuildAll.ps1`, quando o JSON sair parcial (`postProcessingFailed=true` ou objeto enxuto de recovery), consultar `buildSignals` **antes** de reabrir o `msbuild.stdout.log`: `buildSignals.Complete=true` ⇒ `ReorgDetected`/`ErrorCount`/`PostBuildEvents` são integrais e confiáveis, **não** reabrir o log para confirmar 0 erros, reorg ou disparo de deploy; `Complete=false` ⇒ bucket parcial, e campo `null` **não** é `0`/`[]` (significa não computado) — reabrir o log só para os campos `null`. `PostBuildEvents` traz a linha bruta do evento pos-build, então o `.bat` de deploy aparece pelo nome real (sem detector dedicado por nome)
- no diagnostico JSON dos wrappers, `exitCode` e o valor classificado pelo wrapper (0/32/41/42/48/50/...) e também o exit code do processo; `executionEvidence.msBuildExitCode` e o local canonico do valor bruto da task MSBuild; `msBuildExitCode` top-level, quando existir, e compatibilidade transitoria e deve duplicar o valor canonico; `executionEvidence` concentra evidencia bruta de execução e logs; `blockingReasons` deve ser lido como lista de causas acionaveis, não como espelho do exit bruto
- em `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1`, quando `stdoutSignals.postBuildEvents` vier com itens (eventos pos-build configurados na KB que dispararam ou tentaram disparar processo externo), eles são capturados pela janela `Executando eventos pos-construcao ...` ate o próximo separador `==========` (fallback `start c:` / `start cmd` em logs sem marcador) e **classificados** contra `kb_environment_post_build_event_hashes` do environment ativo em `kb-source-metadata.md`, com o veredito agregado em `stdoutSignals.postBuildEventClassification`: evento **registrado** = esperado (informativo, **não** rebaixa); **não registrado/nao reconhecido** = rebaixa por cautela; linha `REM` comentada e inerte e nunca conta; sem registro para o environment, player de som (`SoundPlayer`/`PlaySync`/`.wav`) e reconhecido como benigno e o resto rebaixa. Só rebaixar para `operacao concluida, pendente de confirmacao funcional` quando houver evento que rebaixa (`postBuildEventClassification.shouldDowngrade=true`) — nesse caso citar o evento e orientar inspecao de `stdoutSignals.postBuildEventClassification`. Evento legitimo ainda não registrado deve ser registrado via `xpz-kb-parallel-setup` (`Register-GeneXusKbPostBuildEvents.ps1`), após confirmacao do usuário, para deixar de rebaixar
- se o diagnostico JSON vier com `diagnosticDegraded=true`, declarar que a leitura estruturada ficou parcial; isso pode ocorrer mesmo com `postProcessingFailed=false` e não reclassifica automaticamente a chamada MSBuild como falha operacional
- se `gxImportLogReadStatus=locked` ou `error`, tratar como degradacao de diagnostico de `GxImport.log`; quando `executionEvidence.msBuildExitCode=0` e stdout/stderr trouxerem evidencia primaria suficiente, não reclassificar a operacao como falha principal apenas por esse lock
- ao montar `-ObjectList` a partir de KbIntelligence ou de `gx-object-type-catalog.json`, usar `exportTaskLabel` quando existir (ver `10a-gx-export-task-labels.md`) — o tipo do indice/catálogo pode ser rejeitado pela task Export (`invalidTypesRejected`, `error : ... is not a valid type`)
- em export seletivo (`-ObjectList`): passar `-ParallelKbRoot` ou `-IndexPath` ao `Invoke-GeneXusXpzExport.ps1`; quando a intencao for pacote cirurgico contendo somente a lista nominal, passar também `-DependencyType "None" -ReferenceType "None"`; em import/preview seletivo (`-IncludeItems`): mesmos parâmetros de índice em `Invoke-GeneXusXpzImport.ps1` / `Test-GeneXusXpzImportPreview.ps1`; homonimia ou índice ausente/invalido → **exit 35** (`objectListPreflight`); `not_in_index` → aviso, MSBuild pode seguir; inventario pos-export/pos-pacote continua obrigatório
- em export/import seletivo: com `exitCode=0` e sem Categoria B, não declarar conclusao limpa se a identidade pedida em `-ObjectList` (ou delta) não estiver demonstrada no inventario — tratar como **fallback silencioso por nome** e **ABORT** (distinguir de divergencia de rotulo Export em `10a` e de Categoria B / exit 48); ver anti-padrao e CONSTRAINT em `xpz-msbuild-import-export/SKILL.md`
- após export/import/preview/build MSBuild (`Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1`): distinguir **Categoria A** (extras de inventario, modulos/ExternalObjects de plataforma, `attributesTopLevelUnreconciled` — `exitCode=0` possível, ABORT do agente via Decisão pos-gates) de **Categoria B** (linhas `error :`, `invalidTypesRejected`, `exportErrors`/`importErrors`/`previewErrors`/`buildErrors`/`specifyErrors` no top-level do JSON — wrapper rebaixa para **`exitCode=48`**, `msBuildCategoryBBlocked=true`); ver seção «Categorias A e B» em `xpz-msbuild-import-export/SKILL.md` e índice completo em `scripts/msbuild-exit-codes.catalog.json` — para **exit 46** não inferir causa só pelo terminal; abrir o JSON do wrapper ou o anexo `causes[]` do catalogo
- quando **exit 46** vier de bloqueio preventivo de `MSBuild` concorrente na mesma KB, não aguardar em loop, não tentar enfileirar e não relancar automaticamente; reportar o processo conflitante e parar a rodada
- quando **exit 50** vier de wrapper MSBuild, tratar como erro de parametrização de log: `-LogPath` resolveu para diretório existente; corrigir a chamada para apontar a um arquivo/log explícito, sem interpretar como falha da KB
- após export headless com XPZ gerado: ler `packageInventory`, `operationalSubState`, `exportErrors`, `invalidTypesRejected`, `knownStdOutNoise`, `exitCode` e `msBuildCategoryBBlocked` no **top-level** do `export.json` antes de declarar conclusao limpa; com `operationalSubState=exportação parcial com errors do MSBuild — artefato não confiável` ou `exitCode=48`, **PARAR** — reproduzir linhas `error :` ao usuário; o XPZ pode existir apenas para inspecao; declarar `knownStdOutNoise` (ex. `cssproperties-access-denied`) quando não vazio; **nunca** reportar ao usuário a contagem de `-ObjectList` como contagem do pacote — reproduzir totais reais e, quando `extrasCount > 0`, listar extras por nome; quando `attributesTopLevelUnreconciled=true`, listar atributos top-level por nome; em perguntas sobre conteúdo nominal do XPZ, usar sidecar (caminho A) ou `Get-GeneXusImportPackageObjectInventory.ps1` (caminho B) antes de responder
- na **Decisão pos-gates**, `exitCode=48` (Categoria B) bloqueia import real na mesma rodada — autorizacao de import na sessao não cobre rejeicao MSBuild no log
- antes de importação real: além do gate de envelope (`Test-GeneXusImportFileEnvelope.ps1`), **inventariar todos os objetos** do pacote e conciliar com o delta declarado; preferir `Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <import_file.xml ou .xpz>` e, se houver lista esperada, `-DeclaredDeltaPath` ou `-DeclaredDeltaItems`; em export seletiva sem `Transaction` na lista, atributos top-level em massa (`attributesTopLevelUnreconciled`) indicam arrasto de base — declarar antes de import/sync; pacotes vindos de **export MSBuild** podem trazer objetos extra não pedidos — não assumir que tudo no zip era intencional
- quando o pacote de importação for amplo ou contiver muitos `WorkWithForWeb`, usar watcher no import real (`-StartWatcher` com `-MonitorLogPath`) para acompanhar importação e possível regeneracao dos objetos derivados do pattern; **fora** da **Decisão pos-gates**, se o wrapper suportar watcher e a execução for longa sem watcher, declarar a justificativa
- quando o XML autoritativo já está na pasta paralela, **não** exportar da KB só para obter casca de `.xpz`; preferir `import_file.xml` montado via `xpz-builder` (`Build-GeneXusImportFileEnvelope.ps1` com `-AcervoPath <ObjetosDaKbEmXml>` obrigatório e objetos modificados declarados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids`) ou pelo fluxo de frente `New-XpzImportPackage.ps1`/`.py`; para pacote misto/complexo, preferir `-TemplatePackagePath` com pacote real comparavel, salvo pedido explicito do usuário ou confirmacao de que o envelope não pode ser montado por outro meio documentado
- em wrappers MSBuild que suportam watcher (`Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzImport.ps1`, `Invoke-GeneXusXpzExport.ps1`), usar `-StartWatcher` com `-MonitorLogPath` como fluxo padrão em `BuildAll` e `SpecifyGenerate`, e como padrão para preview/export/import longos; para `BuildAll`/`SpecifyGenerate` longos ou em segundo plano há alternativa **opt-in** via `scripts\Start-GeneXusKbBuildDetached.ps1` (Tarefa Agendada one-shot fora da sessão + arquivo-sentinela, sem watcher — decisão consciente do usuário sob conselho do agente; a janela visível permanece o default); ao aguardar a conclusão **não pollar só a sentinela** (um kill duro da tarefa a deixaria sem escrever, travando a espera) — combinar sentinela + heartbeat da Tarefa Agendada, ou usar o helper `scripts\Wait-GeneXusKbBuildDetached.ps1`; o modo sobrevive a fechar janela/app mas **não** a logoff/reboot (`LogonType Interactive`; S4U/Password não oferecido) — orientar o usuário sobre esse limite ao propor o modo desacoplado; ver `xpz-msbuild-build`; **fora** da **Decisão pos-gates**, em importação real de pacote amplo ou com muitos `WorkWithForWeb`, a ausencia de watcher exige justificativa operacional explicita; o contrato comum fica centralizado em `scripts/GeneXusMsBuildWatcherSupport.ps1`; se `watcherContext.watcherLaunched=false`, declarar a ausencia ao usuário
- em fluxo cotidiano pos-import ou pos-edicao, `Invoke-GeneXusKbBuildAll.ps1` sem `-ForceRebuild` e o passo correto (equivale a `Build All` da IDE, build incremental dos objetos alterados desde o último build); `-ForceRebuild=true` equivale a `Rebuild All` da IDE (regenera TODOS os objetos da KB) e e bloqueado por padrão (exit 46), exigindo `-AllowWideRebuild` com confirmacao explicita do usuário pela frase exata `entendo que isto pode regerar a KB inteira e aceito o custo` — nunca passar implicitamente como `validacao completa automatica`; o mesmo gate de `-ForceRebuild` vale para `Invoke-GeneXusKbSpecifyGenerate.ps1`
- ainda em fluxo cotidiano pos-import ou pos-edicao, nunca passar `CompileMains=true` ou `DetailedNavigation=true` implicitamente: essas opções podem ampliar muito o custo do build em KB grande e são bloqueadas por padrão (exit 46), exigindo `-AllowCostlyBuildOptions` com confirmacao explicita do usuário pela frase exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`; esse gate e independente de `-AllowWideRebuild` e `-AllowReorg`
- em MSBuild headless, wrappers oficiais podem enriquecer preventivamente o `PATH` do processo com subdirs do GeneXus 18 e registrar `observedContext.pathEnrichment`; detalhes e evidência ficam centralizados em `10-base-operacional-msbuild-headless.md`
- quando o sintoma for código de evento GeneXus que parece não executar ou não surtir efeito após import/build headless, distinguir **(a) rejeicao na importação** (`Unknown function`/`src0294`, `exitCode != 0` ou `errors` no `import.json`) de **(b) strip silencioso por DCE** (import OK, handler ausente/vazio no `.cs` após build); não tratar (b) como falha de import nem (a) como bug de build; atalho operacional em `10-base-operacional-msbuild-headless.md` (seção de mecanismos a e b), procedimento canonico em `02-regras-operacionais-e-runtime.md` (`Mecanismos de descarte de codigo de evento pelo gerador GeneXus`), trilhas `xpz-msbuild-import-export` e `xpz-msbuild-build`
- quando o sintoma for **Transaction** (rule que não dispara ou valor que não chega no browser) após import OK com `.cs` web disponível, complementar a investigacao com `scripts\Find-CsAttributeAssignments.ps1` (`-CsPath` absoluto, `-Attribute` com ou sem prefixo `A<n>`, `-AsJson`): copias da atribuicao por método, presenca de `AssignAttri` no mesmo método e `tripletDetected`/`cascadeOrder` em `if/else if` mutuamente exclusivos; `cascadeOrder` fica em quarentena XPZ como diagnostico do `.cs` gerado (`override-then-default-then-fallback` / `override-then-fallback-then-default`), e correcao por inversao textual de `Rules` no XML deve usar `scripts\Edit-GeneXusXmlSurgical.ps1` com ancora literal e nova validação por import/build; ver anti-padrao `transaction-attribute-rule-shadowed-by-default-in-cascade` em `02-regras-operacionais-e-runtime.md` e o detalhe operacional em `xpz-msbuild-build/SKILL.md`
- quando o build pos-geracao falhar com erros C# `CS1010`/`CS1513` repetidos no mesmo `.cs`, tratar primeiro hipotese de **truncamento do arquivo gerado** antes de editar o XML; atalho em `10-base-operacional-msbuild-headless.md` (seção de truncamento) e procedimento em `02-regras-operacionais-e-runtime.md` (`Diagnostico de codigo gerado truncado por falha de generation`); checklist em `xpz-msbuild-build`
- em KB com `kb_environment_count` > 1 em `kb-source-metadata.md`, build de validação pós-import exige `-ParallelKbRoot` (ou `-KbMetadataPath`), `-EnvironmentName` ou `deployment_environment_name` gravado pelo `xpz-kb-parallel-setup`; lista de environments e mapeamento de output/web no setup vêm do usuário (`-KbEnvironmentNames`, `-KbEnvironmentOutputDirs`, `kb_environment_web_dirs`) com validação MSBuild obrigatória — não scan de pastas; não confundir `compilou limpo` no environment ativo da IDE com deploy no IIS; usar `-PostImportDeployValidation` para gate de publicacao em `web\bin` (exit **49** sem evidencia de DLL de objeto ou config fresca); `GxNetCoreStartup.dll` velho em incremental e warning, não gate
- para diagnosticar `.cs` gerado, usar `scripts\Resolve-GeneXusGeneratedCsPath.ps1` a partir de `kb-source-metadata.md` (`kb_environment_web_dirs`) antes de chamar `Find-CsAttributeAssignments.ps1` ou buscar handler de `WebPanel`; se o mapeamento estiver ausente, bloquear e atualizar setup via `xpz-kb-parallel-setup`, sem glob recursivo em `C:\GxModels`
- objetivo B (fix multi-environment) e opt-in por frente: não é gate headless automático; após A bem-sucedido no deploy, prática usual e Build na IDE nos environments secundarios que a frente ainda cobre (consultar `kb_environment_names`); headless repetido com `-EnvironmentName` e exceção documentada, não padrão — ver `02` seção «Saida do gerador GeneXus por environment» e `xpz-msbuild-build`
- para `WebPanel` com Tab aninhada e SDT em data attributes (sub-aba interna vazia na primeira ativacao), consultar `04-webpanel-familias-e-templates.md` (padrão observado) e `02-regras-operacionais-e-runtime.md` (`WebPanel, Tab aninhada e re-bind de SDT em data attributes`) antes de editar eventos no XML

## Regra de leitura para logs de importação

- log de importação deve ser lido por etapa e por categoria de falha
- erro lateral da IDE não prova falha de pacote
- pacote aceito com falha posterior de `Source` ou `Specification` não deve ser descrito como falha de envelope
- se houver sucesso parcial, o agente deve dizer explicitamente que o resultado foi parcial
- quando houver pacote corretivo após falha parcial, relatar pacote original, objetos importados, objetos falhos e pacote corretivo mínimo contendo apenas o delta necessário
- a conclusao final deve seguir a etapa terminal relevante do log, não a linha mais alarmante
- quando recortes sucessivos reduzirem o ruido e o log passar a destacar referencia não resolvida em objeto importado, tratar o caso como frente de conteúdo da KB/`XPZ`, não como defeito residual do wrapper, salvo evidencia contraria

## Regra de identificação de objetos por tipo

- ao mencionar, localizar ou operar sobre qualquer objeto GeneXus, sempre informar tipo e nome em conjunto — nunca só o nome
- o tipo determina a pasta física no repositório; referenciar apenas o nome implica risco de busca na pasta errada
- o mesmo nome pode existir em tipos distintos ao mesmo tempo na mesma KB; coincidência de nome não prova unicidade nem identidade do objeto
- antes de qualquer operação sobre um objeto (leitura, edição, empacotamento, referência em manifesto, sincronização XPZ), confirmar explicitamente a pasta onde o arquivo existe no repositório
- não inferir tipo, pasta ou identidade do objeto apenas pelo contexto da conversa, por hábito ou por analogia
- se o tipo não for conhecido com certeza, inspecionar o repositório antes de assumir qualquer pasta

## Precedencia das heuristicas

- se uma heuristica do `02-regras-operacionais-e-runtime.md` apontar cautela runtime, o agente não pode responder com linguagem otimista
- se uma heuristica do `02-regras-operacionais-e-runtime.md` apontar `exigir molde`, isso prevalece sobre entusiasmo estrutural, frequência amostral ou similaridade superficial
- se uma heuristica do `02-regras-operacionais-e-runtime.md` apontar `abortar`, o agente deve abortar de forma clara, explicando o sinal estrutural e o limite metodologico
- quando houver choque entre “parece estruturalmente simples” e “runtime sensivel”, prevalece a leitura mais conservadora

## Quando responder com mais confiança

- quando a pergunta for descritiva e estiver diretamente sustentada pelos XMLs ou tabelas empíricas
- quando a resposta puder ser classificada como `Evidência direta`
- quando o tipo alvo já estiver bem mapeado por frequência e exemplos comparáveis

## Quando responder com cautela

- quando a conclusão depender de frequência recorrente, mas sem teste externo
- quando a amostra do tipo for pequena
- quando a resposta tocar em edição segura, obrigatoriedade real, importação ou build
- quando o tipo depender de `ATTCUSTOMTYPE`, `pattern` registrado, classe visual pai, package importado, atributo real ou objeto pai existente
- quando a conclusao depender da semantica de atributo calculado, formula, status derivado ou procedure compartilhada ainda não revisada

## Quando recusar geração de XPZ

- quando faltar molde XML completo suficientemente próximo
- quando o tipo estiver em risco `alto` ou `muito alto` sem contexto equivalente, exceto nos fluxos já destravados de `Transaction` e `WebPanel`
- quando houver `pattern`, `parent` ou bloco raro ainda não compreendido
- quando a pergunta exigir afirmar sucesso de importação/build sem evidência externa
- quando a montagem depender de gerar bloco especial de KB (`KnowledgeBase`, `Settings` ou elemento top-level com nome da KB)

## Regra de decisão entre gerar, exigir molde ou abortar

### Gerar por clonagem conservadora

- apenas em cenário muito controlado
- apenas com molde do mesmo tipo e contexto estrutural comparável
- apenas preservando `Object/@type`, `parent*`, `moduleGuid` e `Part type` recorrentes
- para `Transaction`, usar familia estrutural inferida da própria base
- para `WebPanel`, usar familia estrutural inferida e molde interno muito próximo
- para `Theme`, preservar também o conjunto mínimo de classes visuais efetivamente referenciadas entre si
- para `API`, copiar apenas `ATTCUSTOMTYPE` comprovado e somente quando o tipo correspondente existir no alvo
- para `WorkWithForWeb`, usar o convenio estrutural real de atributo do pattern `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`

### Exigir molde bruto comparável

- quando o tipo estiver em cautela alta
- quando a amostra for pequena
- quando o objeto depender de contexto estrutural explícito
- `Transaction` não deve mais exigir molde externo
- `WebPanel` deve operar por familia estrutural e molde interno próximo
- `Attribute` já tem shape top-level provado, mas ainda deve exigir filtro cuidadoso para não confundir definicao real com referencia inline de `Transaction`
- `PatternSettings` deve exigir pattern registrado e contexto equivalente; o XML sozinho não fecha o comportamento
- `API` deve exigir, como regra preferencial, um recorte funcional comparavel contendo também `Procedure`, `SDT`, `Domain` e, quando o caso pedir, `Transaction`, `Table` e `DataProvider`

### Abortar

- quando o molde não for comparável
- quando a mudança exigir mexer em blocos opacos ou raros
- quando a solicitação pressuponha algo que a base não prova

## Frases que um agente deve evitar

- “isso certamente importa”
- “isso é obrigatório” sem base comparativa explícita
- “pode gerar tranquilo”
- “vai buildar”
- “é seguro editar” sem qualificação de risco e nível de evidência
- “o nome do campo deixa claro” quando o campo for calculado ou derivado
- “o XML está valido, entao a regra está certa”
- “parece GeneXus valido, entao deve importar”
- “o corpus local tem algo parecido, entao basta”
- “o Source está plausivel”

## Tipos em maior cautela

- `Transaction`
- `WebPanel`
- `WorkWithForWeb`
- `Procedure`
- `Panel`
- `DataProvider`

## Tipos que ainda pedem molde bruto muito próximo

- todos os tipos em risco `alto` ou `muito alto`, exceto os fluxos operacionais já destravados para `Transaction` e `WebPanel`
- `DesignSystem`, por amostra pequena
- `SDT`, quando a estrutura pai for relevante
- `Theme` e `PackagedModule`, mesmo sendo candidatos relativamente menos agressivos
- `Attribute`, quando houver duvida entre definicao top-level e referencia inline dentro de `Transaction`
- `API`, quando o caso concreto depender de `EXO`, `SDT` ou `Procedure` que não existam comprovadamente no alvo
- `PatternSettings`, quando o pattern correspondente não estiver registrado no ambiente

## Decisão operacional atual para Transaction e WebPanel

- Evidência direta: a base contem 183 `Transaction` e 1196 `WebPanel`.
- Inferência forte: esse volume e suficiente para que um agente GPT tente execução controlada em vez de apenas bloquear por falta de evidencia.
- Inferência forte: `Transaction` pode seguir por padrão estrutural inferido e molde interno da própria base.
- Inferência forte: `WebPanel` pode seguir por familia estrutural, desde que o molde interno seja cuidadosamente escolhido.
- Inferência forte: não pedir mais exemplos para esses tipos deixa de ser regra geral; só faz sentido pedir novos exemplos quando o caso concreto continuar estruturalmente ambiguo.
- Hipótese: se a importação falhar, o caso deve voltar como insumo para evoluir a própria base documental.

## Fórmula de resposta recomendada

1. classificar a afirmação como `Evidência direta`, `Inferência forte` ou `Hipótese`
2. citar o arquivo-base usado
3. declarar a limitação
4. recomendar próximo passo conservador

## Regras de materialização

- Evidência direta: ao gerar `Transaction` ou `WebPanel`, o agente deve partir de um molde XML completo
- Evidência direta: o agente não deve materializar objeto final a partir de resumo textual sem XML completo
- Regra operacional: antes de empacotar, classificar cada XML ativo como `alterado na rodada` ou `reenviado sem mudanca por dependencia obrigatoria`
- Regra operacional: se o objeto foi realmente alterado na rodada, o `lastUpdate` deve ser calculado por procedimento mecanico: `max(UtcNow + 60s, lastUpdate do acervo oficial + 60s)` quando houver baseline oficial, ou `UtcNow + 60s` quando for objeto novo sem baseline
- Regra operacional: se o objeto entrou apenas por dependencia obrigatória ou composicao mínima do pacote, o `lastUpdate` oficial anterior deve ser preservado
- Regra operacional: o agente deve abortar o empacotamento quando houver divergencia entre a classificação do item e o `lastUpdate` materializado
- Regra operacional: antes de serializar o pacote, classificar as raizes top-level em `Object`, `Attribute` ou `outro tipo`
- Regra operacional: `Object` top-level entra em `<Objects>` e `Attribute` top-level entra em `<Attributes>`
- Regra operacional: em pacote de `Transaction` nova, os atributos referenciados no `Level` devem entrar em `<Attributes>` quando o pacote precisar cria-los ou fornece-los ao destino; não serializar esses atributos como `Domain` ou outro objeto em `<Objects>`
- Regra operacional: raiz top-level não suportada deve bloquear o empacotamento ate tratamento explicito
- Regra operacional: XML gerado localmente deve ser salvo em UTF-8 sem BOM; se houver BOM, remover e registrar a correcao
- Regra operacional: antes de gerar `import_file.xml` ou `.xpz`, produzir ou validar manifesto do lote, por padrão na própria conversa, com frente ou descrição curta do lote, origem do lote, quantidade total de XMLs, quantidade de `Objects`, quantidade de `Attributes`, lista ou resumo dos arquivos incluidos, `lastUpdate` aplicado ou preservado, pacote gerado, pacote anterior substituido quando houver e observacoes de risco ou pendencia
- Regra operacional: salvar manifesto em arquivo e comportamento excepcional e contextual; só fazer isso em incidente de processo envolvendo `ObjetosDaKbEmXml`, substituicao de pacote com rastreabilidade local útil, pedido explicito do usuário ou necessidade real de retomada futura fora da conversa imediata
- Regra operacional: ao nomear o pacote local, preferir `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, evitando nome só com assunto, nome só com data/hora, descrição longa de conversa ou sobrescrita recorrente do mesmo nome
- Regra operacional: durante a mesma frente ativa, manter o mesmo prefixo `NomeCurto_GUID_YYYYMMDD` em todos os pacotes e alterar somente `nn`; novo nome base para a mesma frente e ruido operacional, não rastreabilidade
- Regra operacional: antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar colisao do mesmo prefixo de frente `NomeCurto_GUID_YYYYMMDD` com o mesmo `nn` em `PacotesGeradosParaImportacaoNaKbNoGenexus`
- Regra operacional: se houver colisao do mesmo prefixo de frente com o mesmo `nn`, abortar a gravacao; não sobrescrever silenciosamente a rodada
- Regra operacional: em caso de colisao, retornar erro explicito com sugestao do próximo `nn` livre para aquela frente, sem autoincrementar nem gravar automaticamente com o valor sugerido
- Evidência direta: identidade estrutural de objeto sob `Folder` ou `Module` deve ser decidida por exemplar comparavel da mesma KB, conferindo em conjunto `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType` e `moduleGuid`
- Regra operacional: nome de `Folder` não deve ser promovido para `fullyQualifiedName` por analogia; primeiro classificar o conteiner por `parentType`, depois seguir o padrão do exemplar comparavel
- Evidência direta: compatibilidade de `Source` deve ser decidida primeiro pela própria trilha XPZ, usando regra explicita, exemplo sanitizado ou molde documentado, mesmo quando a KB ainda tiver corpus pequeno
- Regra operacional: corpus local da KB pode confirmar ou desempatar um trecho de `Source`, mas não substitui a base metodologica nem autoriza consolidar sintaxe apenas plausivel
- Inferência forte: para `WebPanel`, os anexos completos de `04-webpanel-familias-e-templates.md` já podem servir como molde sanitizado documentado
- Inferência forte: para `Transaction`, `05-transaction-familias-e-templates.md` já contem moldes sanitizados completos para as familias `F1`, `F2`, `F5` e `F6`
- Inferência forte: para `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Table`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File`, a serie `01` agora distribui moldes sanitizados completos representativos em `01e` ate `01h`
- Inferência forte: para `Procedure` de relatório simples, `05b-procedure-relatorio-familias-e-templates.md` passa a ser a referencia primaria de molde sanitizado canonico para familias `F2` e `F3`, mas somente nos blocos marcados como `molde pronto`
- Regra operacional: em `Procedure` de relatório simples, não exigir XML real da KB como primeiro passo quando o molde sanitizado canonico desta trilha já cobrir o shape necessário
- Regra operacional: depois de uma tentativa inicial e no máximo um corretivo estrutural curto, bloquear nova iteracao por analogia e escalar para XML real comparavel
- Hipótese: para `Transaction` das familias `F3` e `F4`, continua prudente buscar molde bruto comparavel adicional se a densidade estrutural real do alvo ultrapassar o que os anexos atuais sustentam
- Evidência direta: a consulta ao acervo real mostrou que `Transaction` materializa atributos dentro do próprio `<Level>` e usa variáveis de contexto como `sdt:Context`, `sdt:TransactionContext` e `sdt:TransactionContext.Attribute`
- Evidência direta: a consulta ao acervo real mostrou que `Theme` simples valido preserva classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption`, além de suas referencias internas
- Evidência direta: a consulta ao acervo real mostrou que `PatternSettings` embute configuração em `CDATA` com `Pattern="..."` e referencias a procedures e contextos do pattern
- Evidência direta: a consulta ao export full trouxe exemplo real de `Attribute` top-level com raiz `<Attribute ... name="...">`, e também revelou referencias inline `<Attribute key="...">Nome</Attribute>` dentro de `Transaction`

### Transaction

- localizar um molde XML completo do mesmo `Object/@type` e da familia estrutural mais próxima
- preservar `Object/@type`, `guid`, `parent*`, `moduleGuid`, `Part type` e ordem das `Part`
- editar somente nomes, descricoes e trechos internos sustentados pelo molde usado
- preservar também os `<Attribute ...>` dentro de `<Level>` com nome interno preenchido, `guid`, `key` e `isNullable` quando existirem
- antes de empacotar `Transaction` nova, validar coerência cruzada obrigatória entre `Level` e `<Attributes>`
- cada `Level/Attribute@guid` deve existir em `<Attributes>/Attribute@guid`
- cada `Level/Attribute` por nome deve existir em `<Attributes>/Attribute@name`
- `DescriptionAttribute`, quando presente, deve apontar para atributo existente no mesmo `Level` e também presente em `<Attributes>`
- se qualquer item acima falhar, abortar antes do pacote final com mensagem objetiva
- pacote mínimo canonico para `Transaction` nova:
  - `<Objects>` = `Transaction`
  - `<Attributes>` = atributos da `Transaction`, no mínimo PK e atributo de descricao/exibicao quando usados pelo shape escolhido
  - `<Dependencies>` = apenas o que o shape realmente exigir
- `TransactionOrObject`, quando aparecer em export comparavel, pode coexistir como auxiliar em `<Objects>`, mas não substitui a obrigatoriedade de `<Attributes>`
- erros como `Cannot convert Domain to Attribute`, `Attribute 'X' in 'Transaction Y' does not exist` e `DescriptionAttribute ... could not be found in level attributes` devem ser tratados como falha de construcao do pacote, não como detalhe a validar depois
- verificar explicitamente se existe `WorkWithForWeb` associado e se a mudanca impacta atributos exibidos, filtros, abas ou navegacao do pattern web
- abortar se a mudanca exigir inventar atributo inexistente na KB ou tipo de contexto não existente

### API

- copiar somente um molde XML completo do mesmo tipo e com contexto comparavel
- tratar `API` nesta base como caso único real observado na KB, e não como familia ampla já generalizavel
- validar antes se cada `ATTCUSTOMTYPE` apontado no molde existe no alvo como `EXO`, `SDT` ou tipo base suportado
- preferir ler e gerar `API` dentro de uma familia funcional combinada, e não como objeto solto, quando o caso real já vier acoplado a `Procedure`, `SDT`, `Domain`, `Transaction`, `Table` ou `DataProvider`
- abortar se a API depender de procedures, `EXO` ou `SDT` inexistentes no destino

### Theme

- preservar `PredefinedTypes`, `Styles`, classes visuais base e referencias internas entre classes
- não podar classes só porque parecem "sobrando"; classes como `TableDetail`, `TableSection` e `TextBlockGroupCaption` podem ser exigidas por outras referencias do próprio tema
- tratar `Theme` preferencialmente em conjunto com `ThemeClass`; para análise mais completa da camada visual, considerar junto também `DesignSystem`, `ColorPalette` e `ThemeColor`
- abortar se a edicao quebrar o grafo mínimo de classes referenciadas

### PatternSettings

- tratar o objeto como configuração de pattern, não como objeto autocontido
- validar se o pattern citado por GUID está registrado no ambiente de destino
- abortar se o caso exigir inferir ou inventar contexto de pattern, procedures de suporte ou variáveis de contexto

### Attribute

- distinguir sempre dois formatos diferentes: `Attribute` top-level real e referencia inline de `Transaction`
- ao extrair ou usar corpus de `Attribute`, aceitar apenas raiz `<Attribute ... name="...">` com `Part` e `Properties`
- não reutilizar nos curtos `<Attribute key="True|False" guid="...">Nome</Attribute>` como se fossem objeto `Attribute` completo
- ao gerar `Attribute` isolado, partir apenas de molde real top-level comparavel
- validar propriedades nominais que apontem para atributos reais da KB, como `ControlItemDescription`
- se `ControlItemDescription`, `idBasedOn` ou referencia equivalente apontarem para atributo inexistente no destino, abortar em vez de tratar isso como problema de envelope
- se houver opção, preferir `Attribute` real semanticamente fechado, sem `ControlItemDescription`, porque esse perfil já demonstrou importação bem-sucedida

### WorkWithForWeb

- tratar o objeto como instancia de pattern por `Transaction`, não como XML independente simples
- usar referencias de atributo no formato estrutural real `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`
- não substituir esse prefixo por GUID de `Attribute` top-level nem por GUID inline do `Level` da `Transaction`
- se a frente introduzir atributos novos usados em `selection`, filtros, abas ou navegacao, tratar o pacote como caso misto `Transaction + WorkWithForWeb + Attribute`
- ao inserir ou alterar action, localizar estruturalmente a `Selection` alvo no XML interno antes de editar `<actions>`; não usar substituicao textual ampla em tags repetidas
- validar que a action nova ficou exatamente uma vez no `Selection` correto; duplicidade ou action em escopo ambiguo bloqueia o pacote ate reinspecao
- se o objetivo incluir a camada física, lembrar que `Table` e `Index` seguem outra trilha: `Table` e top-level próprio e `Index` aparece embutido em `Table`

### Table e Index

- tratar `Table` como objeto top-level da camada física e `Index` como estrutura interna da `Table`
- quando a pergunta envolver `Index`, consultar primeiro um molde comparavel de `Table`, não um suposto corpus de `Index` isolado
- preservar bloco de chave, `<Indexes>`, `Index/@Type`, `Index/@Source` e ordem dos `Member`
- nesta KB, tratar prefixo `I` como índice automático do GeneXus e prefixo `U` como índice manual criado por humano
- se um índice `I...` tiver nome descritivo, assumir primeiro que houve apenas renomeacao editorial do nome, sem mudanca de campos ou ordem
- ler índices automáticos de auditoria como casos de FK automática renomeada, não como familia especial separada
- tratar índice `User` como tuning manual empirico para ordenacao/performance, especialmente quando a ordenacao real divergir dos índices automáticos disponíveis
- não supor que toda `Table` precise de índice `User`; a ausencia de `U...` pode ser a decisão correta quando o volume esperado não compensa custo extra
- fora de evidencia comparavel forte, preferir a hipotese conservadora `PK + poucos Automatic Duplicate` antes de inventar `User` adicional
- não usar casos excepcionais locais sem `Automatic Duplicate`, como `OperacaoFiscal`, `Pais` e `TipoDocumento`, como molde preferencial para novas inferencias
- preferir pacotes comparaveis com `Transaction` junto quando a pergunta depender da ponte lógica -> física
- abortar se o caso exigir inventar índice novo, chave física nova ou tratar `Index` como top-level sem evidencia externa adicional

### WebPanel

- identificar primeiro a familia estrutural usando `04-webpanel-familias-e-templates.md`
- selecionar um molde interno da mesma familia; quando houver anexo sanitizado completo, ele pode ser a fonte final do prototipo
- preservar `layout`, `events`, `variables`, `Part type`, controles e bindings do molde-base
- abortar se a familia não estiver clara ou se o alvo exigir `grid`, `tab`, componente customizado ou contexto de `parent` ausente no molde escolhido

## Regras de serializacao XPZ

- o objeto clonado deve continuar como XML bem-formado com raiz única `<Object>`
- blocos `Source` e `InnerHtml` que vierem em `CDATA` devem permanecer em `CDATA`
- o agente deve incluir o objeto em `<Objects>` seguindo o envelope XPZ observado documentado em `02-regras-operacionais-e-runtime.md`
- em pacote misto com `Transaction`, `WorkWithForWeb` e atributos novos, `Transaction` e `WorkWithForWeb` ficam em `<Objects>` e os atributos top-level ficam em `<Attributes>`
- se houver `WorkWithForWeb` no pacote misto, preservar também a referencia de `Pattern` no bloco `Dependencies`
- ao gerar ou alterar XML de objeto GeneXus, obter o horario local no momento da gravacao e preencher `lastUpdate` com `max(UtcNow + 60s, lastUpdate do acervo oficial + 60s)` quando houver baseline oficial, ou `UtcNow + 60s` quando o objeto for novo
- `lastUpdate` não é detalhe cosmetico; ele deve ser conferido no arquivo salvo depois de cada gravacao local
- se o objeto mudou, `lastUpdate` deve ser regravado pelo helper ou por cálculo equivalente, nunca por palpite, hora cheia, minuto arredondado, copia de outro arquivo ou valor herdado do acervo
- se o objeto não mudou e entrou apenas para dependencia, preservar o `lastUpdate` oficial
- não concluir XML ou pacote enquanto o `lastUpdate` do arquivo final não tiver sido relido e confirmado
- não concluir XML GeneXus grande apenas porque a escrita terminou; reler cabecalho, cauda e trecho funcional afetado, validar XML bem-formado, fechamento da raiz e `CDATA` antes de empacotar
- para ler XML/XPZ grande sem despejar `CDATA` inteiro na conversa, preferir `scripts\Extract-XpzObject.ps1`, `scripts\Get-GeneXusObjectSummary.ps1` e, para `Panel`, `scripts\Compare-GeneXusPanelShape.ps1`; ao comparar Panel SD, observar pelo menos `actionEventCoverage`, `namedEventNames`, `standardEventNames`, `variableEventNames` e `tapEventNames`, além de `eventNames`
- para `WebPanel` classico, `scripts\Get-GeneXusObjectSummary.ps1` expoe o bloco `webpanel` (tables com `tableType` Flex/Responsive e `depth`, controls, buttons em `<action>` e `<ucw>` Button, `eventNames`, e um bloco `coverage` que reporta `gxControlType` desconhecido em `unknownUcwControlTypes` e não deve ser lido como ausencia silenciosa); usar antes de editar layout/eventos de WebPanel em vez de reconstruir o `CDATA` na mao
- para adicionar um botao a `WebPanel`, preferir `scripts\Add-GeneXusButton.ps1` (insercao cirurgica antes ou após a celula de um controle folha em tabela Flex via `-BeforeControlName`/`-AfterControlName`, mutuamente exclusivas, com stub de Event e bump de `lastUpdate`) em vez de editar o `CDATA` na mao; em tabela Responsive com `responsiveSizes` preenchido aborta fail-closed (`RESPONSIVE_UNSAFE`) em vez de reescrever os breakpoints
- se heredoc, here-string ou mecanismo equivalente terminar por EOF antes do delimitador esperado, tratar o arquivo como truncado/corrompido e regenerar por método controlado
- em PowerShell, se houver interpolacao com chamada de método dentro de here-string, usar subexpressao `$()` ou evitar here-string para essa composicao; `$variavel.Metodo()` pode sair literal
- em clonagem conservadora de `WebPanel` que deveria preservar bindings, comparar antes do pacote os bindings serializados relevantes do original e do clone; no mínimo, `fieldSpecifier` deve bater em contagem e nomes
- se houver export real comparavel da IDE para a mesma composicao, preferir repetir o shape desse export em vez de improvisar `Dependencies` ou `ObjectsIdentityMapping`
- para pacote misto com `Transaction`, `WorkWithForWeb` e `Procedure`, preferir objetos embutidos em `<Objects>` quando esse for o formato validado pelo molde real
- quando o formato exigir UTC com `Z`, converter corretamente a partir do horario local real; não reaproveitar timestamp antigo nem de rodada anterior
- em wrappers compartilhados de empacotamento XPZ, parsear JSON do stdout por padrão; não adicionar `-AsJson` por tentativa-erro. Se uma pasta paralela ainda exigir `-AsJson` nesses wrappers, atualizar os wrappers locais com a skill `xpz-kb-parallel-setup`. Para caminhos de entrada, preferir `-InputPath`; para listas nominais de objetos em formato `Tipo:Nome`, preferir `-ObjectList`.
- para empacotamento com `Build-GeneXusImportFileEnvelope.ps1`, informar obrigatoriamente `-AcervoPath <ObjetosDaKbEmXml>`; o script sempre executa o gate de `lastUpdate`, e o agente deve informar `-ModifiedObjectNames` ou `-ModifiedObjectGuids` para que o script bloqueie `lastUpdate` velho, igual ao acervo em objeto modificado ou futuro demais antes de escrever o pacote; para `Panel`, o helper repassa automaticamente `-TemplatePackagePath` como `-PanelReferencePath` e propaga `information`/`warnings` do gate de par `level id`/`layout id`
- para empacotamento por frente com `New-XpzImportPackage.ps1`/`.py`, o gate de drift 9-FD (`Test-GeneXusFrontAcervoDrift.ps1`) executa sempre antes do empacotamento (fail-closed) e bloqueia XMLs na frente com `lastUpdate` mais antigo que o homônimo no acervo; `-AcervoPath <ObjetosDaKbEmXml>` é opcional e, quando omitido, o acervo canônico `<RepoRoot>/ObjetosDaKbEmXml` é resolvido automaticamente; sem acervo resolvível o empacotamento é bloqueado, e o JSON reporta `acervoResolvedBy` (`explicit` ou `convention`); findings `front-older-than-acervo` (`fail`) bloqueiam o empacotamento; findings `front-equals-acervo` e `lastupdate-unparseable` (`warn`) exigem confirmação explícita; colisao de rodada retorna JSON com `status=bloqueado`, `reason=PACKAGE_ROUND_COLLISION`, `blockingReasons` e `nextFreeNN`; resolução de drift: usar `Copy-GeneXusAcervoToFront.ps1` para copiar do acervo para a frente com bump automático de `lastUpdate`, depois re-executar o gate 9-FD para confirmar que o drift foi resolvido; para seed inicial de objeto que ainda não existe na frente, chamar o mesmo script com `-ObjectList`, `-ObjectNames` ou `-ObjectGuids` explicito; a pasta da frente deve já existir, aberta por `New-GeneXusXpzFront.ps1` (wrapper `New-*KbFront.ps1`, `-ReuseIfExists` para retomar), nunca criada manualmente — `Copy-GeneXusAcervoToFront.ps1` e os gates 9-* apenas populam ou inspecionam uma frente existente
- editar `ObjetosDaKbEmXml` esperando que o pacote use essa versão é anti-padrão; o motor de empacotamento lê da pasta da frente, nunca do acervo; o gate 9-FD detecta drift, mas o anti-padrão conceitual permanece mesmo quando o `lastUpdate` coincide; para alterar um objeto, copiar do acervo para a frente, editar a cópia e bump o `lastUpdate` — nunca editar o acervo diretamente
- o agente deve tratar `ObjectsIdentityMapping` como mapeamento de contexto; não repetir ali cada objeto exportado nem inventar pares `Object` -> `ObjectIdentity` 1:1
- quando o objeto depender de `parentGuid` ou `moduleGuid` externos relevantes, o agente deve preferir manter no `ObjectsIdentityMapping` a identidade correspondente com o mesmo `Guid`
- o agente deve preservar sempre preenchidos, no formato normal, `Source/Version/@name`, `Object/@name` e `ObjectIdentity/@Name`
- o agente deve garantir também que `Source/@kb` e `Source/Version/@guid` sejam GUIDs sintaticamente validos; placeholders textuais já falharam em parse real nesta trilha
- GUID sintaticamente valido não basta para import headless por agente: quando houver identidade local esperada, `Source/@kb` também precisa corresponder a KB nativa local; divergencia é indicio de pacote de outra KB e deve ser encaminhada para importação manual pela IDE
- ao clonar/criar objeto a partir de XML existente, procurar residuos do objeto molde em `Object/@name`, `fullyQualifiedName`, `guid`, propriedade `Name`, `Description`, `Source`, `Rules/parm`, chamadas internas, dependencias e `ObjectsIdentityMapping`
- cada residuo do objeto molde deve ser classificado como intencional, dependencia necessária ou erro de clonagem; ocorrência sem classificação bloqueia o pacote
- o agente não deve gerar `KnowledgeBase`, `Settings` nem elemento top-level com nome da KB ao montar `.xpz` normal de objetos
- se a serializacao depender de bloco especial de KB, o agente deve tratar isso como export especial e recusar a montagem normal de objetos
- o agente pode usar a pasta local `from-anywhere-to-GeneXus` apenas como confirmacao secundaria de envelope mínimo; não deve copiar dela valores hardcoded como `Build=0`, `SampleKB`, `BusinessLogic`, `root`, `parentGuid` fixo ou `moduleGuid` fixo
- antes de empacotar, validar parse XML, presenca de todos os `Part type` recorrentes e coerência entre objeto clonado e molde-base
- o agente não deve afirmar “sem erro de importação”; deve afirmar apenas que seguiu a especificacao mais conservadora disponível
- ha evidência direta de importação bem-sucedida para um caso mínimo de `Procedure`; isso ajuda a validar o envelope normal, mas não autoriza generalizacao irrestrita para todos os tipos

## Regras de fonte

- Fonte valida: XML bruto de objeto
- Fonte valida: envelope XPZ observado documentado em `02-regras-operacionais-e-runtime.md`
- Fonte valida: exemplos sanitizados completos de `04-webpanel-familias-e-templates.md`, quando usados como molde de `WebPanel`
- Fonte valida: molde sanitizado canonico completo de `05b-procedure-relatorio-familias-e-templates.md`, quando o caso for `Procedure` de relatório simples dentro da cobertura `F2` ou `F3` e o bloco usado estiver marcado como `molde pronto`
- Fonte invalida: markdown apenas descritivo desta base, inclusive alias, tabelas e sinteses sem bloco `molde pronto`
- Fonte invalida: reconstrucoes livres baseadas em tabelas, frequencias ou descricoes
- Inferência forte: esta base documental já explica o envelope XPZ observado e já contem moldes sanitizados completos para `WebPanel`
- Inferência forte: esta base documental já contem moldes sanitizados completos também para `Transaction` em familias representativas
- Inferência forte: esta base documental já contem moldes sanitizados completos também para `Procedure`, `DataProvider`, `DataSelector`, `Panel`, `API`, `WorkWithForWeb`, `SDT`, `Domain`, `Theme`, `PackagedModule`, `DesignSystem`, `ColorPalette`, `ThemeClass`, `ThemeColor`, `Image`, `Table`, `Document`, `ExternalObject`, `UserControl`, `Module`, `SubTypeGroup`, `PatternSettings`, `DataStore`, `Dashboard`, `DeploymentUnit`, `Generator`, `Language`, `Folder`, `Stencil` e `File` em perfis representativos
- Regra operacional: quando `Procedure` de relatório simples estiver coberta por molde canonico da trilha, rotular a resposta como baseada em `molde sanitizado`; quando houver escalada, rotular explicitamente `XML real da KB atual`, `XML real de outra KB` ou `hipotese`
- Hipótese: no caso de `WorkWithForWeb`, os anexos ajudam a prototipar, mas ainda não eliminam a necessidade de cautela extra quando o caso concreto depender fortemente de `pattern` gerado e contexto do objeto pai
- Hipótese: nem todos os tipos da base chegaram nesse mesmo nível de cobertura; para varios deles ainda prevalece a orientacao por familia + molde bruto comparavel

## Risco de inferência inconsciente em investigações

Complemento ao sistema de níveis de confiança de `02-regras-operacionais-e-runtime.md`.

O risco mais difícil de detectar não é o agente que sabe que está especulando e não sinaliza.
É o agente que acredita estar reportando observação direta quando está, na prática, consolidando
por contexto — e por isso não percebe que deveria qualificar.

Três padrões concretos identificados empiricamente (2026-05-10):

- **Inferência por proximidade estrutural**: atribuir propriedade de uma linha a outra linha
  vizinha da mesma família, sem query literal da linha específica. Exemplo: concluir que o
  `EntityTypeNamespace` de um tipo é K2BTools porque os tipos vizinhos na mesma tabela têm
  esse namespace, sem ler o campo da linha alvo diretamente.

- **COUNT sem granularidade reportado como narrativa sobre elementos**: transformar um total
  agregado por critério textual em afirmação sobre elementos individuais sem verificar se
  todos têm o mesmo nome/tipo. Exemplo: "37 registros de FormDesigner" quando o COUNT mistura
  dois nomes distintos (`FormDesigner`=1, `FormDesignerPart`=36).

- **Consolidação de evidências de contexto sem preservar origem**: agrupar itens do mesmo
  provider/contexto em um único bloco e, ao redigir, deixar a proximidade sugerir vínculo
  que não foi provado. Exemplo: listar GUIDs de um provider junto ao trecho sobre um tipo
  específico sem declarar explicitamente a qual tipo cada GUID pertence.

Regra operacional: ao revisar ou registrar achados de investigação — próprios ou de outro
agente — verificar explicitamente se cada afirmação tem fonte direta rastreável (linha lida,
query executada, coluna nominada) ou se é inferência por consolidação de contexto. Em caso
de dúvida, qualificar como `Inferência forte` ou `Hipótese` antes de registrar como fato.
