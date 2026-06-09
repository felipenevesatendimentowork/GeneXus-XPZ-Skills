# Ideias Implementadas

Registro de ideias que sairam de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Unificar `Get-Utf8NoBomEncoding` repo-wide

**Importancia original:** baixa
**Status:** concluida em 2026-06-04

### Origem

Frente combinada 2026-05-25 (Parte C). O escopo conservador daquela frente tinha limitado a padronizacao de UTF-8 sem BOM ao sidecar `package-inventory.json`, deixando a higiene repo-wide registrada em `999-ideias-pendentes.md`.

### Problema concreto

Scripts PowerShell da raiz gravavam texto em UTF-8 sem BOM por padroes locais diferentes: funcoes `Get-Utf8NoBomEncoding` duplicadas, funcao especifica de inventario de environment, construtores inline `[System.Text.UTF8Encoding]::new($false)` e `New-Object System.Text.UTF8Encoding($false)`.

### Implementacao

- `scripts/Utf8NoBomEncodingSupport.ps1`: novo suporte compartilhado com `Get-Utf8NoBomEncoding`.
- Scripts em `scripts/*.ps1` que faziam escrita simples em UTF-8 sem BOM passaram a carregar o suporte compartilhado e chamar `Get-Utf8NoBomEncoding`.
- Casos de leitura/deteccao de encoding, BOM deliberado ou validacao estrita de bytes permaneceram inline, porque usam semantica diferente de escrita simples sem BOM.
- `02-regras-operacionais-e-runtime.md` e `09-inventario-e-rastreabilidade-publica.md` passaram a registrar o contrato para novas manutencoes.

### Decisao final

A trilha adotou helper compartilhado em vez de manter duplicacao local ou padronizar apenas por estilo inline. A regra futura e reutilizar `scripts/Utf8NoBomEncodingSupport.ps1` para escrita simples em UTF-8 sem BOM e reservar construtores inline de `UTF8Encoding` para casos semanticamente especiais.

### Rastreabilidade

- Commit: `95cf6d8` (`Centraliza codificacao UTF-8 sem BOM`)

## Detecção robusta de eventos pós-build por marcador de fase

**Importancia original:** baixa
**Status:** concluida em 2026-06-04

### Origem

Ideia levantada em 2026-05-12 como evolução natural do tratamento de eventos pós-build introduzido na frente de filtro de ruído GAM/NetCore.

### Problema concreto

A detecção de eventos pós-build em `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` usava regex enumerativa para linhas `start c:` / `start cmd`, com ou sem `REM`. Isso cobria os formatos vistos, mas deixava invisíveis comandos pós-build com formatos novos, como `call`, `cmd /k`, `powershell` ou comando direto sem `start`.

### Implementacao

- `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1`: novo suporte compartilhado para extrair `postBuildEvents`.
- `scripts/Invoke-GeneXusKbBuildAll.ps1` e `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1` passaram a usar a janela iniciada por `Executando eventos pos-construcao ...` e encerrada pelo próximo separador `==========`.
- A regex histórica para `start c:` / `start cmd` permanece como fallback quando o marcador de fase não existe no log.
- `scripts/Test-GeneXusMsBuildPostBuildEventsSupportSelfTest.ps1` cobre comandos `start`, `call`, `cmd /k`, `powershell`, `REM` e fallback legado.
- `02-regras-operacionais-e-runtime.md` e `xpz-msbuild-build/SKILL.md` foram atualizados para documentar a janela por marcador e o fallback.

### Decisao final

A trilha adotou detecção por fase como caminho preferencial, sem remover compatibilidade com a regex antiga. Assim o wrapper cobre formatos futuros observados dentro da fase pós-build e evita regressão em logs antigos ou variantes que ainda não emitam o marcador.

### Rastreabilidade

- Commit: `be4ac59` (`Detecta eventos pos-build por janela MSBuild`)

## Gate para opções caras de build (`CompileMains=true` / `DetailedNavigation=true`)

**Importancia original:** baixa
**Status:** concluida em 2026-06-05

### Origem

Ideia levantada em 2026-05-13 durante a frente que introduziu o gate de
`-ForceRebuild=true` em `Invoke-GeneXusKbBuildAll.ps1` e
`Invoke-GeneXusKbSpecifyGenerate.ps1`.

### Problema concreto

`CompileMains=true` compila também objetos Main além do Developer Menu.
`DetailedNavigation=true` executa navegação detalhada durante a especificação. Essas
opções não equivalem a `Rebuild All`, mas podem ampliar bastante o custo de uma
validação cotidiana em KB grande.

### Implementacao

- `Invoke-GeneXusKbBuildAll.ps1`: bloqueia `CompileMains=true` e
  `DetailedNavigation=true` sem `-AllowCostlyBuildOptions`.
- `Invoke-GeneXusKbSpecifyGenerate.ps1`: bloqueia `DetailedNavigation=true` sem
  `-AllowCostlyBuildOptions`.
- `Invoke-GeneXusXpzImportThenBuild.ps1`: propaga `-AllowCostlyBuildOptions` e
  `-ConfirmCostlyBuildOptions` para o build pós-import.
- `scripts/msbuild-exit-codes.catalog.json`, `10-base-operacional-msbuild-headless.md`
  e `xpz-msbuild-build/SKILL.md`: documentam o novo gate.

### Decisao final

A trilha adotou gate separado de `-AllowWideRebuild` para não misturar regeneração
total (`ForceRebuild=true`) com opções caras de build incremental. A confirmação exige
a frase exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`.

### Rastreabilidade

- Commit: `c2a09b7` (`Adiciona gate para opções caras de build`)

## Documentos de governança na raiz

**Importancia original:** baixa
**Status:** concluida em 2026-06-05

### Origem

Ideia registrada em `999-ideias-pendentes.md` a partir do alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17, e reforçada na frente pré-push de 2026-05-21 como lacuna de orientação para contribuidores humanos.

### Problema concreto

O repositório já era público e continha base metodológica com potencial de adoção externa, mas não tinha os arquivos canônicos de governança para orientar segurança, contribuição, conduta e registro de mudanças.

### Implementacao

- `SECURITY.md`: política mínima para reporte privado de vulnerabilidades, vazamento de dados e riscos operacionais.
- `CONTRIBUTING.md`: guia curto para contribuidores humanos, com leitura obrigatória, anti-duplicata em `998`/`999`, cuidado com dados reais e ponte para a revisão pré-push.
- `CODE_OF_CONDUCT.md`: código de conduta trilíngue, alinhado ao propósito GeneXus XPZ/XML e explícito contra desqualificação de participantes por trabalharem com GeneXus ou IA.
- `CHANGELOG.md`: registro inicial de mudanças a partir desta adoção, sem reconstrução retroativa de versões.

### Decisao final

A frente adotou documentos mínimos e trilíngues, com português como fonte editorial primária, sem duplicar integralmente `README.md` ou `AGENTS.md`. O histórico anterior permanece nos commits, em `historico/` e na documentação das frentes já encerradas.

### Rastreabilidade

- Commit: `b0408a0` (`Adiciona documentos de governança do repositório`)
- Commit: `1ef85e1` (`Documenta contato privado para contribuicoes`)
- Commit: `4e919ff` (`Ajusta email de contato comunitario`)
- Commit: `0123b9b` (`Vincula contribuicao ao changelog`)

## Teste de integração para bloqueio de XML de referência no `Build-GeneXusImportFileEnvelope`

**Importancia original:** baixa
**Status:** concluida em 2026-06-04

### Origem

Fechamento da frente de bloqueio de XML de referência/exemplo/template em empacotamento, discutida em 2026-05-23 e registrada em `999-ideias-pendentes.md`.

### Problema concreto

`Build-GeneXusImportFileEnvelope.ps1` bloqueava arquivos de entrada explícita em `-ObjectXmlPaths` e `-TopLevelAttributesXmlPaths` quando o nome indicava XML de referência, exemplo, template ou molde, mas esse contrato só estava coberto por parse PowerShell e inspeção do diff.

### Implementacao

- `scripts/Test-BuildGeneXusImportFileEnvelopeSelfTest.ps1`: novo autoteste com fixture temporária mínima.
- O teste chama o script real `Build-GeneXusImportFileEnvelope.ps1`, com template `ExportFile`, XML de objeto com `lastUpdate`, acervo baseline e atributo top-level sintético.
- A cobertura confirma bloqueio em `-ObjectXmlPaths`, bloqueio equivalente em `-TopLevelAttributesXmlPaths` e controle positivo em que `-TemplatePackagePath` contém `template` no nome sem acionar o bloqueio.

### Decisao final

A trilha passou a ter cobertura executável para o bloqueio nominal dos XMLs de entrada do pacote, preservando o uso legítimo de pacote template como fonte comparável do envelope.

### Rastreabilidade

- Commit: `2bf4e05` (`Cobre bloqueio de XML de referencia no envelope`)

## Gates consultivos de reforço da fase semântica da pré-push

**Importancia original:** média
**Status:** concluida em 2026-06-06

### Origem

Uma revisão pré-push perdeu a propagação de um alias novo (`-ObjectList`) a uma menção pré-existente. Investigar a causa levou a um padrão maior: a fase semântica acerta a verificação "para frente" (o que entrou está presente?) e é cega à verificação reversa/invariante (adicionar isto tornou alguma afirmação existente falsa? algum conteúdo viola regra documentada?).

### Problema concreto

Gaps dessa classe não eram capturados de forma reproduzível. Bateria empírica: 12 execuções de revisão pré-push, 6 modelos (Claude/Opus, GPT-5.5, DeepSeek, GLM, MiniMax, Kimi), 3 harnesses; sobre 3 gaps reais plantados, 10 das 12 não acharam nenhum, e só o GPT-5.5 achou algo (2 runs, subconjuntos disjuntos). Diligência, amplitude de busca e nível de raciocínio não mudaram o resultado.

### Implementacao

Quatro gates consultivos no orquestrador `Invoke-PrePushMechanicalChecks.ps1`, cada um com self-test, e reforço conceitual no `13` (passos 2 e 3):
- `Test-PrePushNewTokenPropagation.ps1` — termo de contrato novo não propagado a menções co-localizadas (transição no diff, filtro por morfema).
- `Test-PrePushSharedScriptSkillCoverage.ps1` — script compartilhado alterado documentado em `SKILL.md`/`quality-checklist.md` fora do diff.
- `Test-PrePushHistoryCommitPlaceholder.ps1` — placeholder genérico em campo `Commit:`/`PR:` de `historico/`.
- `Test-PrePushGateEnumerationParity.ps1` — enumeração de gates na doc que ficou subconjunto próprio do que o orquestrador executa (deriva a verdade do código).
Também: preenchimento de hashes reais no histórico e correção de gaps nos self-tests (regra UTF-8 `09:103`; cobertura de caso vazio).

### Decisao final

Mecanizar só a classe cuja fonte-de-verdade é derivável do código (paridade de enumeração, propagação de termo). Para o resíduo semântico puro ("o que virou falso"), a salvaguarda é diversidade de modelo na revisão — mitigante probabilístico, não garantia. Ideia de lint UTF-8 avaliada e descartada (`998-ideias-descartadas-e-porque.md`).

### Rastreabilidade

- Commit: `a5b9ef6` (`Adiciona gate consultivo de propagacao de termo novo a pre-push`)
- Commit: `7b0ff77` (`Adiciona gate consultivo de cobertura de skill transversal a pre-push`)
- Commit: `7cc62fa` (`Adiciona gate consultivo de placeholder de rastreabilidade a pre-push`)
- Commit: `173cb9a` (`Preenche hash real nos campos Commit: do historico de junho`)
- Commit: `19b5859` (`Adiciona gate de paridade de enumeracao de gates e fecha a causa-raiz`)
- Commit: `2db41f8` (`Corrige gaps dos self-tests da pre-push achados na bateria de harnesses`)

## Contrato de nomenclatura de parametros das skills XPZ

**Importancia original:** media
**Status:** concluida em 2026-06-07

### Origem

Feedback de uma sessao real operando a pasta paralela de KB com as skills XPZ: num unico ciclo de empacotar/importar, varias chamadas falharam por inconsistencia de contrato entre wrappers. A parte de saida/`-AsJson` ja fora tratada em frente anterior; restava a nomenclatura de parametros, que nunca foi registrada em `999-ideias-pendentes.md` (entrou direto como frente nesta sessao).

### Problema concreto

Conceitos equivalentes apareciam com nomes diferentes entre wrappers/motores: selecao de objeto como `-ObjectNames` (Copy) vs `-ObjectList` (export/preflight/governance); entrada primaria como `-InputPath` (sync/sanity/extract/summary) vs `-XpzPath` (import). Sem vocabulario canonico unico nem aliases, um agente caia em tentativa-erro de flag. Conceitos so aparentemente irmaos (`-ExpectedItems`, `-ModifiedObject*`, `-IncludeItems`/`-ExcludeItems`) corriam risco de unificacao indevida.

### Implementacao

- Selecao por nome: `-ObjectList` canonico, `-ObjectNames` sinonimo. `Invoke-GeneXusXpzExport.ps1` passou `-ObjectList` a `[string[]]` com alias `ObjectNames` e normalizacao interna; `Copy-GeneXusAcervoToFront.ps1` reframeado (aceita ambos).
- Entrada primaria: `-InputPath` canonico com alias `-Path` em 7 scripts (`Sync-GeneXusXpzToXml`, `Edit-GeneXusXmlSurgical`, `Extract-XpzObject`, `Get-GeneXusObjectSummary`, `Test-GeneXusObjectVariableDelta`, `Test-GeneXusTransactionCoherence`, `New-GeneXusUnknownTypeMaintainerPrompt`).
- Familia de import (decisao C3): `-InputPath` canonico com aliases `-XpzPath` (retrocompativel) e `-Path` em `Invoke-GeneXusXpzImport.ps1`, `Invoke-GeneXusXpzImportThenBuild.ps1` e `Test-GeneXusXpzImportPreview.ps1`; chaves `XpzPath` do JSON de saida preservadas.
- Regra de direcao: artefato de saida mantem nome por papel (`-XpzPath` no export, sem alias `-InputPath`).
- Conceitos distintos preservados: `-ModifiedObjectNames`/`-ModifiedObjectGuids` (handoff), `-ExpectedItems` (assercao), `-IncludeItems`/`-ExcludeItems` (task MSBuild).
- Trava deterministica nova: `scripts/Test-XpzParameterNamingContract.ps1` (nomes, aliases, tipo e regra de direcao via metadados, sem KB).
- Vocabulario canonico documentado em `02-regras-operacionais-e-runtime.md`; propagacao em `10-base-operacional-msbuild-headless.md`, `xpz-msbuild-import-export/SKILL.md`, `xpz-kb-parallel-setup/SKILL.md` e no exemplo `Copy-KbAcervoToFront.example.ps1`. `README.md` (trilingue) e `08-guia-para-agente-gpt.md` ja traziam a preferencia canonica.

### Decisao final

Em vez de renomear a familia, fixou-se vocabulario canonico com aliases aditivos (sem quebra), preservando conceitos genuinamente distintos e a regra de direcao entrada/saida. A decisao C3 (renomear o primario do import para `-InputPath` mantendo `-XpzPath` como alias) foi escolhida sobre aliasar so o import, para evitar excecao permanente no canone — preferencia por coerencia de medio/longo prazo. Pre-push revisada tambem por modelo independente: os gates consultivos `newTokenPropagation` e `sharedScriptSkillCoverage` foram integralmente justificados.

### Rastreabilidade

- Commit: `13a33eb` (`Unifica contrato de nomenclatura de parametros nas skills XPZ`)

## Endurecimento do gate de propagacao por classe e o teto da revisao de modelo unico

**Importancia original:** media
**Status:** concluida em 2026-06-07

### Origem

Fechamento da frente de nomenclatura (acima): a revisao pre-push por um modelo distinto (MiniMax) encontrou um gap de propagacao (lista de parametros gemea divergente: `10-base...md:765` vs `xpz-msbuild-import-export/SKILL.md:322`, e `xpz-kb-parallel-setup/SKILL.md:557`) que tres passadas do mesmo modelo (Opus) descartaram em lote sob justificativa coletiva. Investigar levou a uma cadeia de endurecimento do gate `Test-PrePushNewTokenPropagation.ps1` e a um aprendizado sobre o limite do revisor de modelo unico.

### Problema concreto

O gate emitia todas as candidatas com severidade uniforme `warn`, sem distinguir prosa (que cita o nome canonico) de lista de parametros gemea (que de fato divergiu); isso convidava o revisor a descartar tudo em lote. Alem disso, o teto `-MaxFindings` truncava o total em ordem de varredura, derrubando candidatas de subpastas (skills) antes de alcanca-las.

### Implementacao

- `mentionClass` por candidata (`prose`/`param-list-item`/`param-table-cell`/`command-example`), em campo estruturado e no sufixo `[classe=...]` da mensagem; rastreio de blocos de codigo cercados (commit `2485f20`).
- Truncamento ciente de classe: o teto aplica-se so a `prose`; nao-prosa nunca truncada; campos `classCounts` e `truncatedProseCount` (commit `4b50e62`).
- Orquestrador segrega as nao-prosa em `nonProseVerdictRequired` e injeta no `agentSemanticChecklist` a exigencia de livro-razao item a item; acima de 5 nao-prosa recomenda segunda passada por modelo distinto (commit `fc8533d`).
- `13-revisao-pre-push.md`: disciplina de confronto por classe (prosa admite justificativa coletiva, nao-prosa exige veredito individual contra a lista-gemea) e salvaguarda de diversidade de modelo promovida de reserva para recomendada-acima-de-limiar. `08-guia-para-agente-gpt.md` espelhou as regras novas. Self-test do gate estendido com asserts de classe e de truncamento por classe.

### Decisao final

A mecanica foi util mas tem teto: forcar exaustividade num revisor de modelo unico nao garante veredito correto. Em experimento controlado (mesmo prompt minimo, mesmo modelo, so a rotina mudando entre rodadas), o Opus melhorou o processo (passou a confrontar todas as candidatas em livro-razao) mas piorou o veredito — racionalizou cada item como justificado, inclusive revertendo um veredito antes correto. So um modelo distinto pegou os gaps. Conclusao registrada em `998-ideias-descartadas-e-porque.md`: a diversidade de modelo e o backstop; nao tentar mecanicamente consertar o revisor unico. Os gaps de propagacao e o espelho do `08` foram mantidos abertos como fixtures durante os experimentos e corrigidos no fechamento desta frente.

### Rastreabilidade

- Commit: `2485f20` (`Classifica candidatas do gate de propagacao por forma da mencao`)
- Commit: `4b50e62` (`Torna o truncamento do gate de propagacao ciente de classe`)
- Commit: `fc8533d` (`Forca veredito individual das candidatas nao-prosa na pre-push`)

## Gate de drift 9-FD fail-closed e motor de re-carimbo de `lastUpdate`

**Importancia original:** media
**Status:** concluida em 2026-06-07

### Origem

Frente operacional do empacotamento por frente: o gate de drift frente-vs-acervo (9-FD) do `New-XpzImportPackage.ps1` so rodava quando `-AcervoPath` era informado, o que permitia pular silenciosamente a verificacao de `lastUpdate` simplesmente omitindo o parametro. Junto, faltava um motor dedicado para apenas re-carimbar o `lastUpdate` de um XML da frente ja editado em rodadas subsequentes, sem copiar do acervo nem reaplicar delta.

### Problema concreto

Footgun nomeado: um pacote cujo objeto tem `lastUpdate` menor ou igual ao objeto vivo na KB e aceito pelo import sem erro (`exitCode 0`), mas a KB nao atualiza o objeto — desperdicando um ciclo import+build inteiro. O contrato condicional do gate (so com `-AcervoPath`) deixava esse footgun escapar por omissao. Para re-bumpar o timestamp, agentes recorriam a busca-e-troca textual manual do atributo, fragil e sem validacao de well-formedness.

### Implementacao

- `New-XpzImportPackage.ps1`: gate de drift 9-FD tornado **fail-closed** — executa sempre antes do motor Python; `-AcervoPath` virou opcional e, quando omitido, o acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` e auto-resolvido; sem acervo resolvivel o empacotamento e bloqueado; o JSON ganhou `acervoResolvedBy` (`explicit`/`convention`). Self-test do contrato fail-closed: `scripts/Test-NewXpzImportPackageDriftSelfTest.ps1`.
- Novo motor compartilhado `scripts/Set-GeneXusXmlLastUpdate.ps1` (com `scripts/Test-SetGeneXusXmlLastUpdateSelfTest.ps1`): re-carimba o `lastUpdate` da raiz do Object in-place, recalculando `max(UtcNow + margem, baseline + margem)` via `Get-GeneXusXpzLastUpdate.ps1` e reusando as funcoes de leitura/gravacao/validacao de `GeneXusXmlSurgicalEditSupport.ps1`, com backup `.bak`, restauracao em `XML_NOT_WELLFORMED_AFTER`, `-DryRun` e `-AsJson`. Contrato `-InputPath` (alias `-Path`) adicionado a enumeracao de `scripts/Test-XpzParameterNamingContract.ps1`.
- Footgun do import inocuo por `lastUpdate` velho/igual nomeado e documentado em `xpz-msbuild-import-export/SKILL.md`, com o limite honesto da protecao (os gates comparam contra o acervo, nao contra a KB viva).
- Propagacao do contrato fail-closed em `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `README.md` (trilingue), `xpz-builder/SKILL.md`, `xpz-builder/quality-checklist.md`, `xpz-kb-parallel-setup/SKILL.md` e no exemplo `xpz-kb-parallel-setup/examples/New-KbImportPackage.example.ps1`. Entrada correspondente em `CHANGELOG.md` (`Unreleased`, trilingue).

### Decisao final

Optou-se por fail-closed com auto-resolucao canonica em vez de manter o gate condicional: omitir `-AcervoPath` nao pode ser um caminho para pular a verificacao. A protecao cobre o caso comum (esquecer de bumpar), mas nao substitui ressincronizar o acervo quando ha suspeita de defasagem frente a KB viva — limite registrado explicitamente na doc. A propagacao do contrato antigo (condicional) para o novo (fail-closed) foi inicialmente incompleta e so fechada apos revisao pre-push por modelos distintos (GLM, DeepSeek, MiniMax), que tambem apontaram a paridade de enumeracao no gate de parametros, a entrada de CHANGELOG e este registro de historico.

### Rastreabilidade

- Commit: `2c8b699` (`Torna fail-closed o gate de drift de lastUpdate no empacotamento por frente`)
- Commit: `8949c76` (`Adiciona Set-GeneXusXmlLastUpdate para re-bumpar lastUpdate sem delta`)
- Commit: `5aa96cb` (`Atualiza o inventario 09 com o contrato fail-closed e o motor Set-`)
- Commit: `e77c67e` (`Alinha README trilingue e molde da kb-parallel-setup ao contrato fail-closed do gate de drift`)
- Commit: `94fc0cf` (`Completa a propagacao do contrato fail-closed do gate de drift em 02, 08 e kb-parallel-setup`)

## Suporte a WebPanel classico: inspetor de shape, regra de botao e Add-GeneXusButton

**Importancia original:** media
**Status:** concluida em 2026-06-08

### Origem

Prompt de agente externo de pasta paralela de KB (relato de adicionar botoes e remover marcadores de teste no source de eventos de um `WebPanel`). O agente travava em engenharia reversa do `CDATA`, distincao Flex vs Responsive e edicao whitespace-fragil. Campanha de quatro frentes (A, B, C, D) avaliada sob a regua de priorizar a comunidade usuaria das skills no longo prazo, nao o pedido literal.

### Problema concreto

- O `Get-GeneXusObjectSummary.ps1` so calculava shape para `Panel` (SD), devolvendo `panel=null` para `WebPanel` classico — sem inspetor, o agente lia o `CDATA` na mao.
- A estrutura de botao em `WebPanel` nao estava documentada como regra: duas serializacoes (`<action>` e `<ucw>` Button), confundiveis com `<actions>` de pattern WorkWith e com referencias `.Visible`/`.Icon` em codigo.
- Nao havia helper para inserir botao com a serializacao correta (em especial o `ucw` escapado) tratando Flex vs Responsive.
- A skill `xpz-msbuild-import-export` nao demarcava que edicao de source pertence ao `xpz-builder`.

### Implementacao

- Frente A — `scripts/Get-GeneXusObjectSummary.ps1` ganhou o bloco `webpanel` (parse estrutural do `GxMultiForm`): `tables` com `tableType` Flex/Responsive e `depth`, `controls`, `buttons` nas duas formas, `eventNames` e `coverage` honesto (`unknownUcwControlTypes`). Catalogo versionado `scripts/gx-ucw-gxcontroltype-catalog.json` (doc em `04b-ucw-gxcontroltype-reference.md`). Teste `scripts/Test-GeneXusWebPanelShapeContract.ps1`.
- Frente B — regra interpretativa de botao em `xpz-builder/responsibilities-by-type/webpanel.md` (declaracao unica + On Click Event; desambiguacao layout/`<actions>`/`.Visible`), com cross-ref no `04b`. Sem molde redundante: os moldes do `04` ja cobrem ambas as formas.
- Frente C — `scripts/Add-GeneXusButton.ps1`: insere `<cell>` com botao (forma action/ucw) apos controle folha em tabela Flex, com stub de Event e bump de `lastUpdate`, reusando `GeneXusXmlSurgicalEditSupport.ps1`; gate fail-closed `RESPONSIVE_UNSAFE`. Teste `scripts/Test-GeneXusAddButtonContract.ps1`.
- Frente D — fronteira de escopo em `xpz-msbuild-import-export/SKILL.md`, com descarte da alternativa em `998-ideias-descartadas-e-porque.md`.
- Decisao derivada — `Compare-GeneXusPanelShape.ps1` orienta ao bloco `webpanel` (permanece Panel-only); extensao a WebPanel registrada em `999-ideias-pendentes.md`.

### Decisao final

A distincao `<action>` vs `<ucw>` Button e de serializacao, nao de modelagem (confirmado por evidencia da KB FabricaBrasil, Wiki GeneXus e skill Nexa) — conceitualmente e o mesmo Button. O inspetor declara a propria cobertura para nunca induzir falso negativo; o helper falha de forma segura (`RESPONSIVE_UNSAFE`) no caso Responsive arriscado em vez de reescrever o array de breakpoints.

### Rastreabilidade

- Commit: `83a50b4` (`Demarca fronteira de edicao de source na import-export e registra descarte no 998`)
- Commit: `8260923` (`Adiciona inspetor de shape de WebPanel classico ao Get-GeneXusObjectSummary`)
- Commit: `5cb5b30` (`Cita o bloco webpanel do inspetor no guia do agente (08)`)
- Commit: `5b6add3` (`Orienta WebPanel no Compare-GeneXusPanelShape e registra extensao no 999`)
- Commit: `9ca850d` (`Documenta a regra interpretativa de botao em WebPanel (Frente B)`)
- Commit: `8b26fcb` (`Adiciona Add-GeneXusButton: insercao cirurgica de botao em WebPanel (Frente C)`)
- O commit de fechamento desta frente (paridade de enumeracao no gate de parametros, entrada de `CHANGELOG.md` e este registro) e majoritariamente meta-documental e permanece visivel via `git blame` no arquivo mensal, conforme `historico/AGENTS.md`

## Eventos pos-build declarativos e gate de deploy bin por sucesso operacional factual

**Importancia original:** media
**Status:** concluida em 2026-06-08

### Origem

Relato de sessao real: build do environment `NETPostgreSQL` da KB FabricaBrasil com `-PostImportDeployValidation` apos importar um WebPanel. Um evento pos-build benigno — um "sino" de fim de build (`SoundPlayer ... PlaySync()`) configurado na KB — rebaixava o status do build e, como efeito colateral, suprimia o gate de validacao de deploy que o usuario pedira; o hand-off manual de `-BuildStartedAt` para o diagnostico avulso completava a friccao.

### Problema concreto

- O gate de `web\bin` (`-PostImportDeployValidation`) decidia rodar pela **string de status**: qualquer rebaixamento (inclusive um sino benigno) tirava o status de `compilou limpo` e pulava a validacao pedida.
- O rebaixamento por evento pos-build era cego: qualquer item em `stdoutSignals.postBuildEvents` rebaixava, mesmo um deploy `.Bat` legitimo configurado pelo usuario.
- `Test-GeneXusDeployBinFreshness.ps1` exigia `-BuildStartedAt` manual, forcando extracao do `timing.msbuildStart` do JSON do build na mao.

### Implementacao

- Frente 1 — `scripts/GeneXusKbDeployBinSupport.ps1`: a decisao do gate passou de string (`-BuildSuccessStatus`) para sucesso operacional factual (`-BuildOperationallySucceeded`: MSBuild exit 0 + marcador de conclusao); funcao `Test-GeneXusKbDeployBinBuildSuccessStatus` e array `GeneXusKbDeployBinSuccessStatuses` removidos. Teste `scripts/Test-GeneXusDeployBinPolicySelfTest.ps1`.
- Frente 2 — `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1` ganhou classificacao declarativa (`Get-GeneXusPostBuildEventClassification` + `Get-GeneXusPostBuildEventNormalizedHash` SHA-256, `Test-GeneXusPostBuildEventInert` para `REM`, `Test-GeneXusPostBuildEventBenignBySound`); campo novo `kb_environment_post_build_event_hashes` em `kb-source-metadata.md`, lido por `Get-GeneXusRegisteredPostBuildEventHashesForEnvironment` em `scripts/GeneXusKbDeploymentEnvironmentSupport.ps1`; `scripts/Register-GeneXusKbPostBuildEvents.ps1` registra os eventos conhecidos por environment (campo de fingerprints + secao-espelho legivel; confirmacao por frase exata interativa ou `-ConfirmRegistration` em modo agente). Evento registrado = esperado (nao rebaixa); nao registrado/nao reconhecido = rebaixa por cautela. Testes `scripts/Test-GeneXusPostBuildEventClassificationSelfTest.ps1` e `scripts/Test-GeneXusKbPostBuildEventsRegistrationSelfTest.ps1`.
- Frente 3 — `scripts/Test-GeneXusDeployBinFreshness.ps1` ganhou `-BuildResultJsonPath` (deriva a linha de corte de `timing.msbuildStart` do build; `-BuildStartedAt` opcional, explicito prevalece; `buildStartedAtSource` no resultado). Teste `scripts/Test-GeneXusDeployBinFreshnessBuildStartedAtSelfTest.ps1`.
- Paridade documental: `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `10-base-operacional-msbuild-headless.md`, README trilingue, `CHANGELOG.md` trilingue, `xpz-kb-parallel-setup/SKILL.md` (+ molde `examples/Register-KbPostBuildEvents.example.ps1`), `xpz-msbuild-build/SKILL.md` (catalogo de status do BuildAll) e `xpz-msbuild-import-export/SKILL.md` (propagacao das flags de validacao de deploy bin pelo wrapper integrador, como categoria distinta dos gates de autorizacao).

### Decisao final

O gate de deploy e uma verificacao factual e ortogonal a cautela de seguranca do status — por isso decide por exit 0 + marcador de conclusao, nao pela narrativa. Eventos pos-build legitimos sao reconhecidos por registro declarativo por environment (fingerprint), nao por heuristica de padrao, porque ambientes reais tem comandos legitimos (ex.: deploy `.Bat`) que nenhuma allowlist generica pode confiar; uma rede de seguranca reconhece player de som como benigno quando nao ha registro. A revisao pre-push por multiplos modelos independentes (prompt nu, sem contaminacao do contexto) fechou os gaps de paridade restantes.

### Rastreabilidade

- Commit: `07e5408` (`Desacopla gate de deploy bin da string de status (Frente 1)`)
- Commit: `cd92f41` (`Classifica eventos pos-build por registro declarativo (Frente 2)`)
- Commit: `a083dd1` (`Deriva BuildStartedAt do JSON do build no diagnostico avulso (Frente 3)`)
- Commit: `b7df50f` (`Fecha gaps de paridade documental da campanha pos-build (revisao pre-push)`)
- Commit: `5a5681e` (`Fecha gap do 08 e adiciona molde de registro de eventos pos-build`)
- Commit: `328bf92` (`Espelha classificacao de evento pos-build no catalogo de status do BuildAll`)
- Commit: `cafa134` (`Documenta propagacao das flags de validacao de deploy bin no import-then-build`)
