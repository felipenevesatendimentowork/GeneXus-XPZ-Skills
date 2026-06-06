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

- Commit: este commit

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

- Commit: este commit

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

- Commit: este commit
