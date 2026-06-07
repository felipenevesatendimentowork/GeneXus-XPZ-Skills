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
