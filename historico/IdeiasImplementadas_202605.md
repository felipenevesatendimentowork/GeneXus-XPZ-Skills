# Ideias Implementadas

Registro de ideias que sairam de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Disciplina mecanica de lastUpdate para XMLs gerados e empacotamento

**Importancia original:** media
**Status:** concluida em 2026-05-21

### Origem

Relato operacional de agente externo consolidou ocorrencias de 2026-05-13, 2026-05-14 e 2026-05-20: XMLs gerados para import via `xpz-builder` ficavam com `lastUpdate` velho, igual ao acervo, ou arbitrariamente no futuro.

### Problema concreto

- `lastUpdate` igual ou anterior ao acervo podia produzir import com mensagem operacional de sucesso, mas sem atualizacao efetiva do objeto na KB.
- `lastUpdate` varios minutos no futuro podia poluir o build posterior com avisos de KB modificada depois da hora atual, mascarando diagnosticos reais.
- A regra discursiva existente dependia de memoria do agente e nao bastava para impedir recorrencia.

### Implementacao

- `scripts/Get-GeneXusXpzLastUpdate.ps1`: passa a aceitar `-BaselineXmlPath` e `-FreshnessMarginSeconds`, retornando `max(UtcNow + margem, baseline lastUpdate + margem)`.
- `scripts/Build-GeneXusImportFileEnvelope.ps1`: `-AcervoPath <ObjetosDaKbEmXml>` passou a ser obrigatorio e o gate de `lastUpdate` roda sempre, com declaracao de objetos modificados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids`, bloqueando `lastUpdate` anterior ao acervo, igual ao acervo em objeto declarado modificado, margem insuficiente e futuro injustificado.
- `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `xpz-builder/SKILL.md` e `xpz-kb-parallel-setup/SKILL.md`: regra alinhada para `NEW_TS = max(UtcNow + 60s, lastUpdate do acervo oficial + 60s)`, preservando `lastUpdate` oficial apenas em dependencias reenviadas sem mudanca.
- `xpz-kb-parallel-setup/examples/Get-KbLastUpdate.example.ps1`: wrapper exemplo atualizado para repassar baseline e margem ao motor compartilhado.

### Decisao final

A frente foi implementada no motor de timestamp e no helper de envelope, em vez de ficar apenas como anotacao pendente. A validacao dentro de `Test-GeneXusImportFileEnvelope.ps1` puro continua limitada por nao ter, sozinho, contexto de acervo e classificacao de objeto modificado; por isso o enforcement principal ficou no ponto de montagem `Build-GeneXusImportFileEnvelope.ps1`, com `AcervoPath` obrigatorio e sem opt-in de frescor.

## Documenta `diagnosticDegraded` na base operacional e amplia escopo de `executionEvidence` em 09

**Importancia original:** media
**Status:** concluida em 2026-05-20

### Origem

Avaliacao pre-push apontada por agente externo em 2026-05-20. Dois gaps:

- `diagnosticDegraded` / `diagnosticDegradedReason` estavam contratados em `xpz-msbuild-import-export/SKILL.md` e emitidos em `scripts/Invoke-GeneXusXpzImport.ps1` e `scripts/Test-GeneXusXpzImportPreview.ps1`, mas a base operacional `10-base-operacional-msbuild-headless.md` e o inventario publico `09-inventario-e-rastreabilidade-publica.md` nao definiam o campo. Quem lesse so a base 10 nao tinha ancora para interpretar o campo no JSON.
- A linha de inventario em `09` sobre separacao `blockingReasons` / `executionEvidence` enumerava so as familias `xpz-msbuild-build` e `xpz-msbuild-import-export`. `scripts/Test-GeneXusKbConsistency.ps1` tambem emite `executionEvidence` via `New-ExecutionEvidence` e ficava orfao dessa narrativa.

### Implementacao

- `10-base-operacional-msbuild-headless.md`: novo item `diagnosticDegraded` / `diagnosticDegradedReason` no contrato de diagnostico JSON, com semantica explicita (nao reclassifica a task MSBuild) e sub-estado correto quando coexistir com `executionEvidence.msBuildExitCode=0`.
- `09-inventario-e-rastreabilidade-publica.md`: linha 51 complementada para incluir `Test-GeneXusKbConsistency.ps1` no escopo de `executionEvidence`; nova linha registrando `diagnosticDegraded`/`diagnosticDegradedReason` como contrato emitido por import e preview.

### Decisao final

Cobertura em `02-regras-operacionais-e-runtime.md` e `08-guia-para-agente-gpt.md` foi inicialmente avaliada como desnecessaria para contrato de campo. Revisao posterior da rotina pre-push decidiu registrar nesses documentos apenas a regra operacional minima: `diagnosticDegraded=true` indica diagnostico parcial, pode ocorrer sem `postProcessingFailed=true` e nao reclassifica automaticamente a chamada MSBuild como falha operacional.

### Rastreabilidade

- Commit: `9acc032` (`Documenta diagnosticDegraded e amplia escopo executionEvidence`)

## Setup popula `kb-source-metadata.md` a partir da KB nativa, sem depender do XPZ

**Importancia original:** alta
**Status:** concluida em 2026-05-20

### Origem

Investigacao iniciada em 2026-05-17 a partir de relato da pasta paralela `C:\Dev\Test\Gx_wsEducacaoSpTeste`. A IDE GeneXus exportava `.xpz` com `<Source />` vazio em pelo menos dois caminhos de export, deixando `kb-source-metadata.md` sem `Source/@kb` e `Source/Version/@guid`. Como `Test-GeneXusImportFileEnvelope.ps1` bloqueia `Source` vazio, empacotamentos posteriores dependiam de workaround inadequado como `SkipGate`.

### Implementacao

- `scripts/Resolve-GeneXusKbIdentity.ps1`: motor compartilhado somente leitura para resolver identidade estavel da KB nativa local.
- `scripts/Update-XpzKbSourceMetadataIdentity.ps1`: atualizador conservador dos campos de identidade estavel em `kb-source-metadata.md`, preenchendo ausentes e bloqueando divergencias nao vazias sem aprovacao explicita.
- `xpz-kb-parallel-setup/examples/Resolve-KbIdentity.example.ps1`: wrapper sanitizado para reconstrucao local controlada.
- `xpz-kb-parallel-setup/SKILL.md`: setup inicial com KB nativa confirmada deve resolver identidade antes de declarar `kb-source-metadata.md` apto; metadata ausente, incompleto ou ilegivel e bloqueado pelos gates de metadata; divergencia preenchida contra a KB nativa ficou registrada como frente futura em `999-ideias-pendentes.md`; correcao de campos ausentes ou divergentes usa o atualizador somente em frente aprovada.
- `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `README.md`, `09-inventario-e-rastreabilidade-publica.md`, `xpz-builder/SKILL.md` e `xpz-msbuild-import-export/SKILL.md`: regras alinhadas para autoridade de campo, bloqueio cross-KB e rastreabilidade operacional.

### Decisao final

A frente do `Resolve` esta encerrada. O fluxo normal downstream continua lendo `kb-source-metadata.md`; `Resolve` nao vira fallback ad hoc de `xpz-sync`, `xpz-builder` ou import MSBuild. Se no futuro surgir necessidade de wrapper adicional ou automacao local especifica, isso deve ser tratado como nova frente: o agente deve estudar a documentacao vigente e propor o caminho aplicavel naquele contexto.

### Rastreabilidade privada

O exemplo sanitizado `xpz-kb-parallel-setup/examples/Resolve-KbIdentity.example.ps1` foi registrado no `GeneXus-XPZ-PrivateMap`, ligado ao alias privado `KB_Teste_Paralela_A`.

## Wrapper compartilhado para auditoria de naming de `ObjetosDaKbEmXml`

**Importância:** média
**Maturidade:** implementada em 2026-05-18

**Origem:** avaliacao de sugestao de agente externo em 2026-05-01.

**Status em 2026-05-18:** promovida para implementacao no motor compartilhado como `scripts/Test-XpzObjetosDaKbNaming.ps1`, com wrapper exemplo `xpz-kb-parallel-setup/examples/Test-KbObjetosDaKbNaming.example.ps1` e integracao em `scripts/Test-XpzSetupAudit.ps1`.

### Problema concreto que motiva a ideia

A verificacao de naming dos diretorios de container em `ObjetosDaKbEmXml` e executada hoje como procedimento narrado pelo agente seguindo o bloco `8.g2` da `xpz-kb-parallel-setup`. O fluxo esta bem especificado — cobre todos os diretorios sem excecao, exige leitura de pelo menos um XML por diretorio, mapeia o GUID de `Object/@type` para o nome canonico via catalogo e produz saida estruturada em tabela — mas depende de interpretacao local do agente a cada sessao.

O risco pratico nao e de ambiguidade na regra, mas de variancia entre execucoes: agentes distintos podem diferir na forma de localizar o XML, nomear as colunas da tabela ou reportar a evidencia, mesmo seguindo a mesma secao da skill.

### Ideia de melhoria implementada

Adicionar ao motor compartilhado um script `Test-XpzObjetosDaKbNaming.ps1` que:

- receba como entrada o caminho de `ObjetosDaKbEmXml`
- liste todos os subdiretorios presentes
- leia pelo menos um XML por diretorio, extraia o elemento raiz ou `Object/@type`
- mapeie o GUID para o nome canonico usando o mesmo catalogo ja consumido por `Build-KbIntelligenceIndex.py`
- emita saida estruturada por diretorio com as colunas `Diretorio`, `Tipo real encontrado`, `Status` e, quando divergente, `Nome canonico esperado`
- retorne `NAMING_OK` quando todos os diretorios estiverem conformes, `NAMING_DIVERGENT: <lista>` quando houver inversao ou `NAMING_INDETERMINADO: <lista>` quando houver diretorio sem XML classificavel ou GUID desconhecido

O wrapper local de cada pasta paralela chamaria esse script e repassaria o resultado ao handoff, em vez de o agente executar o mapeamento inline.

### Criterio que justificou implementar

O limiar de maturidade foi atingido apos novo relato operacional em 2026-05-18: loops PowerShell inline para naming em pastas paralelas estavam gerando atrito recorrente, parser fragil e necessidade de scripts temporarios em `Temp/`. A implementacao consolida a verificacao no motor compartilhado e permite que `Test-XpzSetupAudit.ps1` reporte `naming/objetos-da-kb` de forma deterministica.

### Perguntas a responder antes de decidir

- O catalogo de GUIDs em `01a-catalogo-e-padroes-empiricos.md` ja esta em formato consumivel por um script PowerShell, ou exigiria extracao adicional?
- O script deve ficar no motor compartilhado (ao lado de `Build-KbIntelligenceIndex.py`) ou como wrapper exemplo desta skill, seguindo o padrao dos `*.example.ps1`?
- A saida estruturada do script deve ser consumida diretamente pelo `Test-*KbSetupAudit.ps1` ou reportada separadamente no handoff?
- Como manter sincronia entre o catalogo de GUIDs e o mapeamento interno do script sem duplicar a fonte autoritativa?

## ENCERRADO — Gate 9-WW estruturalmente errado para WorkWithForWeb do acervo

**Status:** RESOLVIDO em 2026-05-15/16 em duas etapas.

**Etapa 1 (2026-05-15)** — a prosa do gate 9-WW em `xpz-builder/SKILL.md` foi corrigida para reconhecer ambos os formatos estruturais (Form A: Part `babfa2b2-...` no formato de empacotamento; Form B: Part `a51ced48-...` com `<Data Pattern="...">` no acervo materializado). CONSTRAINTS, QUALITY CHECKLIST e o caveat em 9-IDO também foram atualizados.

**Etapa 2 (2026-05-16)** — sub-fase 1.2 do refator estrutural concluída: o gate 9-WW foi extraído para `scripts/Test-GeneXusWorkWithWebApply.ps1` com 10 códigos de finding cobrindo detecção de forma, leitura de Apply (Form A) ou Apply implícito True (Form B), resolução de linked Transaction nos dois formatos, e verificação de `Apply:78cecefe-...=True` na Transaction em batch ou corpus. Validado contra `Gx_FabricaBrasil` (WorkWithWebCarga → Carga com Apply:GUID=True → pass).

**Pendência residual menor:** a detecção WorkWithForWeb → linked Transaction em `Test-GeneXusBatchDependencyOrdering.ps1` (gate 9-IDO) continua não-wired ao script, mesmo que o algoritmo agora exista em `Test-GeneXusWorkWithWebApply.ps1`. O caveat em 9-IDO do SKILL.md ainda exige que o agente verifique essa dimensão de ordenação manualmente quando o batch contém WorkWithForWeb e a Transaction linkada juntos. Pode ser fechado em frente futura reusando `Get-WorkWithForWebDetails` em 9-IDO.

**Importância:** alta
**Maturidade:** pesquisa feita

**Origem:** descoberta empírica em 2026-05-15 durante refator da Fase 1 do `xpz-builder` (sub-fase 1.2 da extração de gates determinísticos para scripts). O gate 9-WW foi suspenso da Fase 1 e a sub-fase 1.3 (9-PSM) tomou seu lugar até que esta correção seja decidida.

### Problema concreto que motiva a ideia

O gate 9-WW em `xpz-builder/SKILL.md` instrui localizar o Part `babfa2b2-19a0-4ef1-b5f4-81b7c7be79dc` dentro de cada `WorkWithForWeb` no batch ativo e ler `<Property><Name>Apply</Name>` em `<Source><Properties>`. Validação empírica contra a KB de teste `Gx_wsEducacaoSpTeste`: nenhum dos 10 WorkWithForWeb materializados em `ObjetosDaKbEmXml/WorkWithForWeb/` contém esse Part.

O Part `babfa2b2-...` é estrutura de **molde de empacotamento** documentada em `01e-moldes-sanitizados-core.md` (linha 1718), não de acervo materializado. WorkWithForWeb tem duas formas estruturais distintas conforme contexto:

- **acervo materializado** (`ObjetosDaKbEmXml/WorkWithForWeb/*.xml`): Part `a51ced48-7bee-0001-ab12-04e9e32123d1` com Data Pattern em CDATA; link com Transaction via `<transaction transaction="<guid>-<name>" />` dentro do CDATA.
- **pacote `import_file.xml`** ou XML gerado a partir de molde sanitizado: Part `babfa2b2-...` com `<Source><Properties><Property>Apply</Property>...`.

Implicação: o gate como está hoje aborta com falso-positivo `ww-apply-property-absent` (equivalente, na prosa atual) em qualquer batch que contenha WorkWithForWeb copiado ou extraído do acervo oficial. Casos cobertos legitimamente pelo gate (XML em formato de empacotamento) ficam misturados com casos cobertos errado (XML em formato de acervo) sem distinção.

### Direção técnica proposta

Antes de extrair o gate para script (continuação da Fase 1 do refator), o gate deve ser fortalecido para entender ambos os formatos:

- detectar a forma estrutural do WorkWithForWeb pelo Part presente:
  - se Part `babfa2b2-...` existe: ler `Apply` e `Transaction` de `<Source><Properties>` desse Part (lógica atual da prosa).
  - se Part `a51ced48-...` existe e contém `<Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b">`: ler o link Transaction de `<transaction transaction="<guid>-<name>" />` no CDATA; tratar `Apply` como implicitamente `True` (objeto materializado pelo pattern existe).
- continuar a verificação de `Apply:78cecefe-be7d-4980-86ce-8d6e91fba04b = True` na Transaction linkada — esse Property vive em `<Object>/<Properties>` e tem o mesmo padrão nos dois formatos.

### Decisões em aberto

- O agente pode confiar em "objeto materializado no acervo => pattern já aplicado por construção"? Há cenário em que o WorkWithForWeb do acervo tem `updateTransaction="Apply WW Style"` (visto em `WorkWithWebCarga.xml`) com semântica diferente do `Apply=True/False` do formato empacotamento?
- Quando o batch contém ambos os formatos para o mesmo objeto (raro mas possível em frente longa), qual prevalece para a verificação do gate?
- A correção é só do bloco 9-WW em `xpz-builder/SKILL.md`, ou também das CONSTRAINTS e do QUALITY CHECKLIST que se referenciam ao Part `babfa2b2-...` (linhas 691, 765, 766) usando a mesma premissa errada?

### Limiar para implementar

Implementar antes da retomada da sub-fase 1.2 do refator estrutural do `xpz-builder` (extração do gate 9-WW para `scripts/Test-GeneXusWorkWithWebApply.ps1` ou similar). Sem essa correção, o script extraído replicaria o bug em código e o problema ficaria mais difícil de tratar depois.

## ENCERRADO — Gate de parse AST para `scripts/*.ps1` e `.example.ps1` das skills

**Importância:** baixa
**Maturidade:** implementada

**Origem:** revisão pré-push de 2026-05-16 sobre os gates da Fase 9 do `xpz-builder`; sugestão original do agente revisor ("smoke de parse AST em CI seria útil"); discussão e fechamento de design na mesma sessão.

**Encerramento:** implementado em 2026-05-18 com `scripts/Test-PsScriptsParse.ps1`, workflow `.github/workflows/parse-ps-scripts.yml` e alinhamento documental do contrato `pwsh >= 7.4`.

### Objetivo

Pegar regressão sintática silenciosa em scripts PowerShell mantidos por esta raiz antes que ela apareça na próxima execução real do gate ou na próxima cópia de um `.example.ps1` para wrapper local de pasta paralela de KB.

### Design fechado

Combo de duas peças:

1. **Script local** `scripts/Test-PsScriptsParse.ps1`:
   - Varre `scripts/*.ps1` e `**/*.example.ps1` da raiz
   - Para cada arquivo, chama `[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errs)`
   - Reporta cada erro com path, linha e mensagem
   - Sai com código `0` se tudo limpo, `1` se houver pelo menos um erro de parse
   - Invocável manualmente e integrável na rotina de revisão pré-push descrita no `AGENTS.md`

2. **Workflow GitHub Actions** `.github/workflows/parse-ps-scripts.yml`:
   - Dispara em `push` e `pull_request` com filtro `paths: ['scripts/**/*.ps1', '**/*.example.ps1']`
   - Roda em `windows-latest` com shell explícito `pwsh`, validando o contrato operacional `PowerShell >= 7.4`
   - Único step relevante: invocar `scripts/Test-PsScriptsParse.ps1`
   - Não duplica lógica — o workflow é apenas o gatilho

### Contrato de runtime decidido em 2026-05-18

- Runtime mínimo suportado para os scripts desta raiz: `pwsh` com PowerShell 7.4 LTS ou superior.
- Runtime recomendado: versão LTS mais recente disponível.
- Premissa de parque: usuários das skills XPZ podem ter pelo menos Windows 10 nas máquinas.
- Windows PowerShell 5.1 (`powershell.exe`) não é runtime suportado para os scripts da base; parse ou execução em 5.1 pode falhar e não deve bloquear a evolução dos scripts.
- O workflow deve testar o contrato real (`pwsh >= 7.4`), não compatibilidade legada com 5.1.

### Escopo

- `scripts/*.ps1` — todos, não só `Test-GeneXus*.ps1`; cobre wrappers `Build-*`, `Invoke-*`, `Sync-*`, etc.
- `**/*.example.ps1` em qualquer skill — esses arquivos viram molde de wrapper local em pasta paralela de KB (regra explícita no `README.md` raiz: "exemplos metodológicos importantes para bootstrap técnico e reconstrução assistida de wrappers locais"); se quebrarem parse, viram fonte de cópia ruim
- Excluído: scripts dentro de `historico/`, se houver

### Limitações conhecidas

- Parse AST é puramente sintático. **Não pega** bugs sob `Set-StrictMode -Version Latest` em runtime (ex: `.Count` em null, `-split` retornando escalar quando não há separador, propriedade XML inexistente acessada por shorthand). Essa categoria continua coberta pela memória global do usuário (`feedback_*`) e por disciplina de teste pós-edição.
- **Não garante** comportamento funcional dos scripts; só garante que os arquivos carregam sintaticamente no runtime contratado.
- **Não cobre** Windows PowerShell 5.1, por decisão explícita de contrato operacional.

### Revisão de premissas em 2026-05-18

Durante a revisão da própria pendência, foi executado parse manual de 70 arquivos no escopo atual:

- Em `pwsh` 7.6.1: `FILES=70; ERRORS=0`.
- Em Windows PowerShell 5.1: foram reportados erros de parse em scripts que passam em `pwsh`; isso confirmou que 5.1 não deve ser usado como contrato de compatibilidade.

O bloqueio anterior ("não há gatilho concreto") deixou de valer porque a decisão de runtime foi fechada: validar automaticamente `pwsh >= 7.4` é uma melhoria pequena, objetiva e alinhada ao contrato da base.

### Correção aplicada

- Criado `scripts/Test-PsScriptsParse.ps1`, com `#requires -Version 7.4`, varredura de `scripts/*.ps1` e `**/*.example.ps1` fora de `historico/`, relatório textual/JSON e exit code `1` em erro de parse.
- Criado workflow `.github/workflows/parse-ps-scripts.yml`, usando `windows-latest` com shell explícito `pwsh`, checagem de versão mínima e chamada ao script local.
- Ajustado `.gitignore` com exceção estreita para versionar workflows `.github/workflows/*.yml`.
- Atualizado `xpz-builder/quality-checklist.md` para apontar para o script compartilhado e remover a premissa de Windows PowerShell 5.1.
- Registrado o contrato de runtime em `README.md`, `02-regras-operacionais-e-runtime.md` e `08-guia-para-agente-gpt.md`.

### Critério de aceite

- `scripts/Test-PsScriptsParse.ps1` executa em `pwsh` 7.4+ e reporta zero erros no escopo atual.
- O workflow delega a lógica ao script local, sem duplicar a varredura.
- A documentação correlata não contradiz mais o contrato de runtime.

### Relacionado

- `xpz-builder/quality-checklist.md` (seção *PowerShell script hygiene*) foi alinhado ao contrato `pwsh >= 7.4`.

## ENCERRADO — Atributo `[ordered]` inválido em declaração de parâmetro em `Test-GeneXusKbConsistency.ps1`

**Importância:** baixa
**Maturidade:** implementada

**Origem:** detectado em revisão pré-push de 2026-05-17 ao validar `Parser.ParseFile` no script após rename de campo JSON.

**Encerramento:** corrigido em 2026-05-18; as três declarações agora usam `[System.Collections.Specialized.OrderedDictionary]`.

### Problema concreto

Antes da correção, três funções de `scripts/Test-GeneXusKbConsistency.ps1` declaravam parâmetro com tipo `[ordered]`:

- linha 327: `Resolve-ScriptExitCode` — `param([int]$MsBuildExitCode, [ordered]$ConsistencyResult)`
- linha 338: `Resolve-StatusLabel` — `param([int]$ScriptExitCode, [ordered]$ConsistencyResult)`
- linha 350: `Resolve-SummaryText` — `param([int]$ScriptExitCode, [ordered]$ConsistencyResult, [bool]$FixMode)`

`[ordered]` é um atributo de literal hashtable (`[ordered]@{...}`), não um tipo válido para anotação de parâmetro. `Parser.ParseFile` reporta:

> The ordered attribute can be specified only on a hash literal node.

O teste de 2026-05-18 mostrou que o Windows PowerShell não era permissivo nesse caso: o script não carregava, mesmo com `-ExecutionPolicy Bypass`, porque o erro era de parse.

### Correção aplicada

Foi trocado `[ordered]$ConsistencyResult` por `[System.Collections.Specialized.OrderedDictionary]$ConsistencyResult` (tipo real) nas três funções.

### Critério de aceite

`ParseFile` retorna zero erros no script após o fix. Saída do script (JSON e exit codes) deve permanecer idêntica em rodada de fumaça de `KB consistente` e `inconsistências detectadas`.

### Relacionado

- Detecção feita durante a frente que normalizou `msbuildExitCode` → `msBuildExitCode` (commit `4531b14`); o flag foi diferido para esta entrada por estar fora do escopo daquela frente.
- Item de checklist em `xpz-builder/quality-checklist.md` (seção *PowerShell script hygiene*): "Every gate script edited in the round was re-parsed (...) and produced zero parse errors". Aplicar esse mesmo gate retroativamente neste script.

## Inventário determinístico de objetos em `import_file.xml`

**Importância original:** média
**Status:** subfrente concluída em 2026-05-19

### Origem

Incidente operacional documentado em 2026-05-13: export MSBuild com `-ObjectList` gerou `.xpz` com dependências e módulo de plataforma. O risco identificado foi importar pacote sem inventário completo do conteúdo real, assumindo incorretamente que a lista nominal do export coincidia com os objetos efetivamente presentes no artefato.

### Implementação

- `scripts/Get-GeneXusImportPackageObjectInventory.ps1`: inventaria XML com raiz `<ExportFile>`, lista objetos sob `<Objects>` e atributos top-level sob `<Attributes>`.
- O script mapeia GUIDs de tipo por `scripts/gx-object-type-catalog.json`.
- O script aceita delta declarado em arquivo texto no formato `Tipo:Nome` e pode falhar com `-FailOnDeltaMismatch` quando há extras, ausentes ou itens incomparáveis.
- `xpz-msbuild-import-export/SKILL.md`, `xpz-builder/SKILL.md`, `10-base-operacional-msbuild-headless.md` e `08-guia-para-agente-gpt.md` passaram a tratar o inventário como verificação determinística para `import_file.xml` antes de importação real.

### Limite preservado como pendência (superado em 2026-05-25)

Suporte direto a `.xpz` não foi implementado nesta subfrente inicial. A extensão foi entregue na frente «Inventário de pacote em `.xpz` e export embutido» abaixo.

## Inventário de pacote em `.xpz` e export embutido

**Importância original:** média
**Status:** concluída em 2026-05-25

### Origem

Incidente operacional em KB FabricaBrasil (2026-05-25): export com 28 entradas em `-ObjectList` gerou `.xpz` com 467 `<Object>` e 1045 `<Attribute>` top-level, incluindo módulos de plataforma; `exitCode=0` não revelava o gap. Comportamento textual já existia na skill, mas faltava automação, sub-estado de export e regra de comunicação ao usuário.

### Implementação

- `scripts/Get-GeneXusImportPackageObjectInventory.ps1`: aceita `.xpz` (ZIP em memória, um único `ExportFile` interno), `-DeclaredDeltaItems` inline (`Tipo:Nome`, separador `;` ou linha), agrega `objectsByType`, detecta `systemModulesPresent` via `scripts/gx-system-modules.txt` em objetos `PackagedModule` (export real GeneXus 18) ou `Module`; confronto de extras em export seletiva considera somente bloco `<Objects>`.
- `scripts/Invoke-GeneXusXpzExport.ps1`: após XPZ gerado, preenche `packageInventory` resumido no diagnóstico, grava sempre `package-inventory.json` no diretório de artefatos, expõe `operationalSubState` e `inventoryDegraded` sem rebaixar exit da task MSBuild.
- `scripts/Test-GeneXusImportPackageObjectInventorySelfTest.ps1`: bateria mínima XML + `.xpz` sintético.
- Governança: `xpz-msbuild-import-export/SKILL.md` (secção inventário após export, sub-estados, CONSTRAINT, checklist), `10-base-operacional-msbuild-headless.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, handoff em `xpz-kb-parallel-setup/SKILL.md`.

### Limite preservado (fora desta frente; sem entrada em `999-ideias-pendentes.md`)

- Encadeamento local envelope + inventário + import num único wrapper da pasta paralela.
- Catálogo de módulos de sistema por KB/versão além de `scripts/gx-platform-objects.json` compartilhado.

## Inventário: atributos top-level e ExternalObject de plataforma no pacote

**Importância original:** média
**Status:** concluída em 2026-05-25

### Origem

Melhoria contínua após fechamento do inventário automático pós-export (commit `47842aa` e correções correlatas). Evidência em KB FabricaBrasil: export seletivo com centenas de `<Attribute>` top-level sem `Transaction` na lista nominal não alterava `operationalSubState`; ExternalObjects SDK (ex.: Camera) diluíam-se em extras genéricos.

### Implementação

- `scripts/Get-GeneXusImportPackageObjectInventory.ps1`: warning `attributes-top-level-em-export-cirurgico` e `attributesTopLevelUnreconciled` em export seletiva sem `Transaction` declarada; detecção de ExternalObjects de plataforma (hoje via `systemObjectsPresent` e `gx-platform-objects.json`).
- `scripts/Invoke-GeneXusXpzExport.ps1`: repassa sinais no `packageInventory` e promove sub-estado quando aplicável (sem competir com `exportErrors`).
- `scripts/Test-GeneXusImportPackageObjectInventorySelfTest.ps1`: controle negativo com `Transaction` na lista; fixture `ExternalObject:Camera`.
- Governança: `xpz-msbuild-import-export/SKILL.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `10-base-operacional-msbuild-headless.md`, handoff em `xpz-kb-parallel-setup/SKILL.md` (redação unificada `import_file.xml` / `.xpz`).

### Limite preservado (fora desta frente; sem entrada em `999-ideias-pendentes.md`)

- Catálogo unificado `gx-platform-objects.json` / `systemObjectsPresent` (ver entrada «Consolidar catálogos de plataforma SDK», 2026-05-26).

### Rastreabilidade

- Commit: `8bdeb3e` (`Inventário: sinais de atributos top-level e ExternalObject de plataforma`)

## Inventário pós-build em motores xpz-builder

**Importância original:** média
**Status:** concluída em 2026-05-25

### Origem

A frente de inventário automático pós-export MSBuild (`packageInventory` em `Invoke-GeneXusXpzExport.ps1`) não cobria pacotes montados localmente; o agente podia relatar a contagem nominal de `-ModifiedObjectNames` em vez do conteúdo real do envelope.

### Implementação

- `scripts/GeneXusPackageInventorySupport.ps1`: funções compartilhadas para resumo `packageInventory` e delta declarado.
- `scripts/Build-GeneXusImportFileEnvelope.ps1`: inventário após gravar `import_file.xml` com confronto via `-ModifiedObjectNames`/`-ModifiedObjectGuids`.
- `scripts/New-XpzImportPackage.ps1`: inventário após o motor Python, confrontando objetos `Object` da frente.
- `scripts/Test-XpzBuilderPackageInventorySelfTest.ps1`: bateria mínima do suporte compartilhado.
- `xpz-builder/SKILL.md` (secção inventário pós-build, CONSTRAINT) e `xpz-builder/quality-checklist.md`.

### Rastreabilidade

- Commit: `3b0c85a` — Inventário pós-build em motores xpz-builder (ponto 4).

## Regras conceituais para provider/item desconhecido fora do XPZ/XML

**Importância original:** FALTA AVALIAR
**Status:** subfrente conceitual encerrada em 2026-05-10

### Origem

Investigação sobre falso negativo em busca de resíduos K2BTools na KB `wsEducacaoSpTeste`. A busca por XPZ/XML e pelo índice SQLite derivado não encontrava certos itens porque metadados de designer de provider estavam persistidos apenas no banco interno da KB (`GX_KB_*`), em tabelas como `EntityType`, `Entity`, `EntityVersion` e `EntityVersionComposition`.

### Implementação conceitual

A dimensão de classificação e comunicação foi aplicada diretamente na base compartilhada e nas skills:

- `02-regras-operacionais-e-runtime.md`: seção "Limite do XPZ/XML frente a providers e extensoes GeneXus", com regras operacionais conceituais.
- `xpz-reader/SKILL.md`: regra para classificar item antes de concluir ausência.
- `xpz-index-triage/SKILL.md`: regra análoga para resultado negativo do índice.

### Limite preservado como pendência

A capacidade operacional de diagnóstico SQL somente leitura no banco interno da KB não foi implementada. A pendência restante continua em `999-ideias-pendentes.md`: definir sede, forma de conexão, script/procedimento e validações para consultas somente leitura contra `GX_KB_*`, sem jamais propor limpeza direta por SQL.

## Enriquecimento de `$env:PATH` em `xpz-msbuild-import-export` por simetria

**Importância original:** média
**Status:** concluída em 2026-05-20

### Origem

Frente concluída em 2026-05-20 aplicou enriquecimento automático de `$env:PATH` com subdirs do GeneXus 18 em `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1`. Sem isso, tasks internas que invocam `gxexec`, `UpdConfigWeb`, `BuildService` ou `Reor.exe` por nome falham em MSBuild headless, porque o `PATH` herdado do agente externo não inclui os mesmos subdirs que a IDE GeneXus injeta implicitamente.

### Implementação

- `scripts/Invoke-GeneXusXpzImport.ps1` e `scripts/Invoke-GeneXusXpzExport.ps1` passaram a enriquecer preventivamente o `$env:PATH` após resolver `GeneXusDir` e antes de invocar `MSBuild`.
- `scripts/Test-GeneXusXpzImportPreview.ps1` passou posteriormente a aplicar a mesma política antes do preview de importação.
- O enriquecimento usa os subdirs conhecidos do GeneXus 18: raiz `GeneXus18\`, `gxnet\`, `gxnet\bin\` e `gxnetcore\`.
- O resultado é registrado no JSON em `observedContext.pathEnrichment`, com `applied`, `subdirsAdded` e `subdirsSkipped`.
- `xpz-msbuild-import-export/SKILL.md` documenta o contrato do novo campo.
- `10-base-operacional-msbuild-headless.md` registra a política dos wrappers e a evidência empírica complementar.

### Evidência e limite da conclusão

Rodada empírica em `C:\KBs\OnlineShopSS` importou alteração estrutural simples de atributo (`ShoppingCartItemQuantity`, `Length`/`AttMaxLen` 4→5) sem enriquecimento manual de `PATH` e importou a reversão (5→4) com `PATH` enriquecido manualmente. Ambas concluíram com sucesso operacional e `importedItems` contendo o atributo esperado; não houve sinal de `Database Impact Analysis`, `Reorganization`, `bldReorganization`, `gxexec`, `UpdConfigWeb`, `BuildService`, `Reor.exe` nem erro de resolução de caminho no stdout.

Conclusão limitada: import/export puro não demonstrou dependência observável desses subdirs nessa rodada. A mudança foi aplicada como defesa preventiva e simetria de ambiente headless com `xpz-msbuild-build`, cuja necessidade já estava provada empiricamente.

### Rastreabilidade

- Commit: `c08089b` (`Enriquece PATH em wrappers MSBuild headless`)
- Commit: `5509d2d` (`Aplica PATH preventivo em import export XPZ`)
- Commit: `ebc7678` (`Corrige gaps da revisão pré-push MSBuild`)

## Classificação de environment inválido e `Join` nulo no BuildAll

**Importância original:** média
**Status:** concluída em 2026-05-20

### Origem

Em 2026-05-20, durante verificação empírica da frente de PATH enriquecido, observou-se que quando o MSBuild falhava em fase muito inicial, sem produzir conteúdo filtrável em stdout/stderr, o pós-processamento de `scripts/Invoke-GeneXusKbBuildAll.ps1` podia explodir com:

```
"Exception calling \"Join\" with \"2\" argument(s): \"Value cannot be null. (Parameter 'values')\""
```

O caso reproduzível usava `EnvironmentName='NETFrameworkPostgreSQL'`, que era nome de pasta de output, não `EnvironmentName` válido. O MSBuild emitia `error : Ambiente 'NETFrameworkPostgreSQL' não existe`, mas o wrapper retornava `falha operacional` com `exitCode: 90`, mascarando a causa real.

### Implementação

- `scripts/Invoke-GeneXusKbBuildAll.ps1` passou a detectar falha de `Set Active Environment` no stdout.
- O wrapper extrai o environment ausente e o environment ativo quando disponíveis, emitindo `blockingReasons` específico para `SetActiveEnvironment`.
- O `Join` frágil no filtro de ruído de stderr foi trocado por expressão array-safe com `@(...) -join`, evitando exceção quando a coleção vem vazia.
- A correção de `Join` frágil também foi aplicada aos wrappers `scripts/Get-GeneXusKbProperty.ps1`, `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1`, `scripts/Open-GeneXusKbHeadless.ps1` e `scripts/Test-GeneXusKbConsistency.ps1`.

### Critério de aceite

Falha inicial por environment inexistente deve ser classificada com causa operacional explícita no JSON, em vez de quebrar no pós-processamento. O diagnóstico top-level deve apontar que o environment solicitado não existe nesta KB e orientar omitir `-EnvironmentName` para usar o environment ativo.

### Rastreabilidade

- Commit: `d3be871` (`Corrige classificação de environment inválido no BuildAll`)
- Commit: `94cb81c` (`Corrige Join frágil em wrappers MSBuild`)
- Scripts afetados: `scripts/Invoke-GeneXusKbBuildAll.ps1`; para `Join` frágil, também `scripts/Get-GeneXusKbProperty.ps1`, `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1`, `scripts/Open-GeneXusKbHeadless.ps1` e `scripts/Test-GeneXusKbConsistency.ps1`

## Alinhamento de bloqueios MSBuild em import/export e abertura headless

**Importância original:** média
**Status:** concluída em 2026-05-20

### Origem

Após a correção inicial de `SetActiveEnvironment` inválido em `BuildAll`, a mesma classe de falha precisava ficar alinhada nos wrappers da família `xpz-msbuild-import-export` e na abertura headless isolada. Sem esse alinhamento, uma versão ou `Environment` inexistente podia aparecer como falha operacional genérica do MSBuild, sem orientar claramente que o parâmetro explícito deveria ser omitido para usar o contexto ativo.

### Implementação

- `scripts/Invoke-GeneXusXpzExport.ps1`, `scripts/Invoke-GeneXusXpzImport.ps1`, `scripts/Open-GeneXusKbHeadless.ps1` e `scripts/Test-GeneXusXpzImportPreview.ps1` passaram a detectar falha de `SetActiveVersion` e `SetActiveEnvironment`.
- Os wrappers extraem, quando disponível, a versão ou o `Environment` ativo e o `Environment` ausente reportado pelo MSBuild.
- O diagnóstico estruturado passou a emitir `blockingReasons` específico para parâmetro inexistente e orientar omitir `-VersionName` ou `-EnvironmentName` quando o objetivo for usar o contexto ativo.
- `00-indice-da-base-genexus-xpz-xml.md`, `08-guia-para-agente-gpt.md` e `xpz-msbuild-import-export/SKILL.md` foram atualizados para registrar a regra operacional.

### Critério de aceite

Falhas de posicionamento explícito de versão ou `Environment` devem ser diagnosticadas como bloqueio operacional de parâmetro inválido, e não como quebra genérica do wrapper. O exit code bruto do MSBuild pode continuar presente como evidência complementar, mas a causa acionável precisa estar explícita.

### Rastreabilidade

- Commit: `f8f811a` (`Alinha bloqueios MSBuild de import export`)
- Commit: `a3eac08` (`Registra alinhamento MSBuild e ajusta warning`)
- Scripts afetados: `scripts/Invoke-GeneXusXpzExport.ps1`, `scripts/Invoke-GeneXusXpzImport.ps1`, `scripts/Open-GeneXusKbHeadless.ps1`, `scripts/Test-GeneXusXpzImportPreview.ps1` e, no ajuste residual do commit `a3eac08`, `scripts/Invoke-GeneXusKbBuildAll.ps1`

## Separação entre causas acionáveis e evidência bruta em wrappers MSBuild

**Importância original:** média
**Status:** concluída em 2026-05-20

### Origem

Após o alinhamento de bloqueios para versão e `Environment` inválidos, os diagnósticos JSON ainda podiam acumular em `blockingReasons` tanto a causa acionável quanto o fato bruto `MSBuild terminou com exitCode N`. Isso preservava evidência, mas tornava a lista de bloqueios mais ruidosa.

### Implementação

- `blockingReasons` passou a priorizar causas acionáveis de decisão.
- A evidência bruta de execução passou a ser registrada em `executionEvidence`, com `msBuildExitCode`, `msBuildFailed`, `wrapperExitCode` e caminhos dos logs brutos.
- Quando o MSBuild falha sem causa acionável classificada, o wrapper mantém um bloqueio fallback orientando consultar `executionEvidence` e os logs.
- A separação foi aplicada aos wrappers `Open-GeneXusKbHeadless.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzImport.ps1`, `Invoke-GeneXusXpzExport.ps1`, `Get-GeneXusKbProperty.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1` e `Invoke-GeneXusKbBuildAll.ps1`.
- A extensão posterior incluiu `Test-GeneXusKbConsistency.ps1` no padrão canônico de `executionEvidence`, preservando `msBuildExitCode` top-level apenas como compatibilidade transitória.

### Critério de aceite

Falha com causa específica não deve duplicar em `blockingReasons` o texto genérico de exit code. O exit bruto deve continuar disponível no JSON, agora em `executionEvidence`.

### Rastreabilidade

- Commit: `b0f65f1` (`Separa evidência bruta de bloqueios MSBuild`)
- Commit: `968be69` (`Padroniza executionEvidence em wrappers MSBuild`)
- Commit: `646cdd7` (`Corrige contrato executionEvidence de consistência`)
- Commit: `ebc7678` (`Corrige gaps da revisão pré-push MSBuild`)

## Rótulo da task Export para Work With for Web (`exportTaskLabel`)

**Importância original:** alta
**Status:** concluída em 2026-05-25

### Origem

Frente combinada (Parte A): export seletiva com `-ObjectList "WorkWithForWeb:..."` emitia `error : WorkWithForWeb is not a valid type` e `invalidTypesRejected`, com fallback por nome na task.

### Implementação

- Matriz A1 em FabricaBrasil18 / `WorkWithWebCliente`; artefatos em `C:\Dev\Prod\Gx_FabricaBrasil\Temp\export-task-label-matrix-20260525\`.
- Rótulo vencedor da task Export: **`WorkWith`** (não `WorkWithForWeb`).
- `exportTaskLabel` em `scripts/gx-object-type-catalog.json`; documento `10a-gx-export-task-labels.md`; links em `10-base`, `08`, `09`, `xpz-msbuild-import-export/SKILL.md`.

### Rastreabilidade

- Commit: `7df2c73` (`Documenta exportTaskLabel WorkWith e limpa governança de export.`)

## Dead code em `Resolve-ExportOperationalSubState` e escopo C do sidecar inventário

**Importância original:** baixa
**Status:** concluída em 2026-05-25

### Origem

Frente combinada (Partes B e C conservador).

### Implementação

- Removido branch redundante em `scripts/GeneXusXpzExportInventoryGovernance.ps1` (`inventoryDegraded` duplicava retorno de `operationalSubState`).
- `scripts/GeneXusPackageInventorySupport.ps1`: comentário + `[System.Text.UTF8Encoding]::new($false)` explícito no sidecar `package-inventory.json`.
- Unificação repo-wide de `Get-Utf8NoBomEncoding` permanece em `999-ideias-pendentes.md`.

### Rastreabilidade

- Commit: `7df2c73` (`Documenta exportTaskLabel WorkWith e limpa governança de export.`)

## Catálogo unificado de códigos de saída MSBuild (JSON + espelho no `10-base`)

**Importância original:** média
**Status:** concluída em 2026-05-26

### Origem

Sessão de alinhamento watcher MSBuild e revisão pré-push (2026-05-22). Documentação já citava `scripts/msbuild-exit-codes.catalog.json` (Categoria B / exit 48) antes do arquivo existir.

### Implementação

- `scripts/msbuild-exit-codes.catalog.json` (`schemaVersion: 1`): índice de exits dos wrappers MSBuild (probe `10`–`16`, headless `20`–`25`, import/export `31`–`34`/`41`–`42`, export pré-validação **33**, build `40`–`45`, política **46** com `causes[]`, cancelamento **47**, Categoria B **48**, falha **90**); `variants[]` para **32**, **40**–**43**, **42**.
- `scripts/Test-MsBuildExitCodesCatalog.ps1` — parse JSON, validação de **46**/**48**, paridade com `exit`/`exitCode` nos wrappers prioritários (sentinela `MSBUILD_EXIT_CODES_CATALOG_OK`).
- `10-base-operacional-msbuild-headless.md`: secção «Catálogo canônico de códigos de saída».
- `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `xpz-msbuild-build/SKILL.md`: ponteiros e regra de desambiguação do **46**.

### Decisões preservadas

- Sem renumeração de códigos; sem import do JSON em runtime nos wrappers (fase documental).
- `32` permanece um único exit com `variants[]` (não breaking change).

### Rastreabilidade

- Commit: `f022911` (`Adiciona catálogo JSON de códigos de saída MSBuild e teste de paridade.`)

## Detecção de defasagem do extrator KbIntelligence vs índice gerado

**Importância original:** média
**Status:** concluída em 2026-05-26

### Origem

Achado 4 (2026-05-23): índices com timestamps frescos mas cobertura incompleta após evolução de `Build-KbIntelligenceIndex.py` (ex.: commit `122a171`).

### Implementação

- `scripts/Build-KbIntelligenceIndex.py`: grava `extractor_signature_version` (constante `EXTRACTOR_SIGNATURE_VERSION`, iniciada em `"2"`) e `extractor_signature_hash` (SHA-256 do motor) na tabela `metadata`.
- `scripts/GeneXusKbIntelligenceExtractorContract.ps1` + `scripts/Test-GeneXusKbIntelligenceExtractorSignatureSelfTest.ps1`.
- `xpz-kb-parallel-setup/examples/Test-KbIndexGate.example.ps1`: bloqueia indice sem assinatura ou com extrator defasado.
- `scripts/README-kb-intelligence.md`, `xpz-kb-parallel-setup/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`.

### Decisão final

Assinatura composta: versão semântica explícita (mudança material de cobertura) + hash do script do motor. Ausência dos campos na metadata equivale a motor antigo.

### Rastreabilidade

- Commit: `787086d` (`Detecta índice KbIntelligence gerado por extrator defasado.`)

## Consolidar catálogos de plataforma SDK em `gx-platform-objects.json`

**Importância original:** média
**Status:** concluída em 2026-05-26

### Origem

Frente combinada 2026-05-25 (Parte D): `gx-system-modules.txt` e `gx-system-external-objects.txt` alimentavam funções e campos JSON separados (`systemModulesPresent`, `systemExternalObjectsPresent`).

### Implementação

- `scripts/gx-platform-objects.json` (`schemaVersion: 1`): entradas `{ name, kind }` com `kind` em `packagedModule` | `externalObject` (nomes podem repetir entre kinds).
- `scripts/GeneXusPlatformObjectsCatalogSupport.ps1`: `Import-GeneXusPlatformObjectsCatalog`, `Get-PlatformObjectKindSets`, `Get-SystemObjectsPresent`.
- `scripts/Get-GeneXusImportPackageObjectInventory.ps1`: parâmetro `-PlatformObjectsCatalogPath`; saída única `systemObjectsPresent` (objetos com `name`, `kind`, `typeName` no pacote).
- `scripts/GeneXusPackageInventorySupport.ps1`, `scripts/GeneXusXpzExportInventoryGovernance.ps1`: resumo e sub-estado usam `systemObjectsPresent`.
- Remoção de `gx-system-modules.txt` e `gx-system-external-objects.txt`.
- `scripts/Test-GeneXusPlatformObjectsCatalogSelfTest.ps1`; self-tests de inventário e sub-estado atualizados.
- `10-base-operacional-msbuild-headless.md`, `09-inventario-e-rastreabilidade-publica.md`, `xpz-msbuild-import-export/SKILL.md`, `xpz-kb-parallel-setup/SKILL.md`, `xpz-builder/SKILL.md`, `xpz-builder/quality-checklist.md`.

### Decisão final

Sem período de compatibilidade: campos legados `systemModulesPresent` / `systemExternalObjectsPresent` removidos do contrato JSON.

### Rastreabilidade

- Commit: `067af90` (`Unifica catálogo de objetos de plataforma SDK em gx-platform-objects.json.`)

## Campanha P5 `exportTaskLabel` multi-KB (matriz MSBuild)

**Importância original:** média
**Status:** concluída em 2026-05-30

### Origem

Ideia em `999-ideias-pendentes.md` (`exportTaskLabel` para `DataView` e tipos SDP) e frente de prompt externo (pasta paralela FabricaBrasil) sobre risco de fallback silencioso por nome. Plano A+ aprovado: união de índices em FabricaBrasil18, wsEducacaoSpTeste e OnlineShopSS; MSBuild na KB nativa do espécime.

### Implementação

- Motores de manutenção: `scripts-maintenance/GeneXusExportTaskLabelSupport.ps1`, `Build-ExportTaskLabelCoverageMap.ps1`, `Run-ExportTaskLabelMatrix.ps1`, `Invoke-ExportTaskLabelCampaign.ps1` (`-ParseOnly`, `-Force`), `Merge-ExportTaskLabelCampaignResults.ps1` (`-ApplyCatalog`).
- Artefatos: `historico/export-task-label-matrix-20260530/` (33 matrizes, `consolidation-report.json`).
- `10a-gx-export-task-labels.md`: seção campanha P5, anexos de tipos sem divergência, sem espécime e observações (inconclusos / só nome).
- Correções de robustez: `packageInventory` nulo no `export.json`; relatório `catalogMatchesTask` sem perder campos em `[ordered]@{}`.

### Resultado empírico

- **Divergência** confirmada apenas para `WorkWithForWeb` → `WorkWith` (já no catálogo; reconfirma matriz A1).
- **22 tipos** com `Tipo:Nome` usando o mesmo rótulo do catálogo (lista em `10a`).
- **7 tipos** sem instância nas 3 KBs indexadas (`DataView`, `Query`, `SmartDevicesApplication`, `SmartDevicesPlus`, `WorkPanel`, `WorkWithPlusInstance`, `WorkWithPlusTemplate`) — manter ausência de `exportTaskLabel`.
- **10 tipos** testados sem divergência de rótulo mas inconclusos ou só com export por nome (detalhe em `10a`); não inventar `exportTaskLabel`.

### Decisão final

Fechar a ideia pendente de `DataView`/SDP sem label inventado: campanha executada; ausência de espécime ou de evidência de divergência permanece estado honesto. Reabrir só com KB que materialize instância ou falha MSBuild reproduzível.

## Pré-validação KbIntelligence no export seletivo (P1)

**Importância original:** alta (anti-padrão fallback silencioso por nome)
**Status:** concluída em 2026-05-30

### Origem

Prompt de agente na pasta paralela FabricaBrasil e frente P3+P4/P5: exit 48 e `exportTaskLabel` não cobrem homônimo nem objeto ausente no acervo com MSBuild aparentemente limpo.

### Implementação

- `scripts/GeneXusObjectListIdentityPreflight.ps1`: parse `Tipo:Nome`, `object-info` + `search-objects`, vereditos `ok` / `ambiguous` / `not_in_index`.
- `Invoke-GeneXusXpzExport.ps1`: parâmetros `-ParallelKbRoot`, `-IndexPath`, `-CatalogOverridePath`; export seletivo **exige** índice (Opção C); homônimo ou índice inválido → **exit 35**; `not_in_index` → aviso e segue MSBuild.
- `objectListPreflight` no `export.json`; `scripts/msbuild-exit-codes.catalog.json` exit 35.
- `Run-ExportTaskLabelMatrix.ps1` / campanha P5: repasse de `-ParallelKbRoot`.
- `scripts/Test-GeneXusObjectListIdentityPreflightSelfTest.ps1`; alinhamento em `xpz-msbuild-import-export/SKILL.md`, `02`, `08`.

### Decisão final

Não bloquear só por `not_in_index` (objeto pode existir apenas na KB nativa antes do sync). Import espelhado (P1 v2) ficou fora desta entrega.

## Pré-validação KbIntelligence no import seletivo (P1 v2)

**Importância original:** alta (simetria com P1 export; homônimo antes do MSBuild Import)
**Status:** concluída em 2026-05-30

### Implementação

- `GeneXusObjectListIdentityPreflight.ps1`: `GateContext` `export`|`import`; `Split-GeneXusMsBuildItemFilter`; disparo com `-IncludeItems`.
- `Invoke-GeneXusXpzImport.ps1` e `Test-GeneXusXpzImportPreview.ps1`: `-ParallelKbRoot`, `-IndexPath`, `-CatalogOverridePath`; estágio `pre-import-identity`; `objectListPreflight` com `gateContext=import`.
- Exit **35** estendido em `msbuild-exit-codes.catalog.json`; self-test ampliado; docs `02`, `08`, `10a`, `xpz-msbuild-import-export/SKILL.md`.

## Extrator de `Property Formula` em `Attribute` (grafo who-uses)

**Importância original:** alta
**Status:** concluída em 2026-05-31

### Origem

Lacuna confirmada em pasta paralela: procedures usadas somente em atributo calculado eram invisíveis a `who-uses`.

### Implementação

- `Build-KbIntelligenceIndex.py`: extrator `extract_attribute_formula_call_evidence`, com assinatura do extrator `3`.
- `Test-KbIntelligenceAttributeFormulaExtractionSelfTest.ps1`: self-test dedicado.
- `gx-object-type-catalog.json` e `scripts/README-kb-intelligence.md`: notas de contrato e operação.

### Pendência operacional externa à ideia

Pastas paralelas com índice gerado por extrator anterior a `3` precisam de rebuild para enxergar chamadas em `Property Formula` de `Attribute`. Quando aplicável, validar também extrator `4` e paridade de gravabilidade com `Test-*KbIndexGate.ps1` e `Test-GeneXusKbIntelligenceWritabilityParity.ps1`.

### Rastreabilidade

- Commit: `fdb4b3f` (`Indexa chamadas em Property Formula de Attribute para who-uses (extrator v3).`)

## Gravabilidade de atributos materializada no índice SQLite

**Importância original:** alta
**Status:** concluída em 2026-05-31

### Origem

Validação pós-caso real de `Procedure` com `New` atribuindo atributo `Formula`, discutida em 2026-05-23.

### Problema concreto que motivou a ideia

Antes da entrega, a consulta `transaction-writable-attributes` reduzia abertura ampla de XMLs, mas não materializava no SQLite a classificação completa usada pelos gates de gravabilidade. A decisão final dependia de `Test-GeneXusTransactionWritability.ps1` ou `Test-GeneXusNewWritableTargets.ps1`, que reimplementavam o algoritmo em PowerShell a partir do acervo XML no momento da validação, com risco de divergência em relação ao indexador.

Em KBs grandes, isso preservava segurança, mas ainda podia custar tempo e tokens quando o agente precisava explorar muitos atributos ou várias Transactions antes de decidir como gerar uma `Procedure`, `Transaction` ou lote de importação.

### Implementação

O `KbIntelligence` passou a gravar, durante `Build-KbIntelligenceIndex.py`, uma tabela derivada de gravabilidade por `Transaction`/`Level`/`Attribute`, com campos como:

- `transaction_name`
- `level_name`
- `attribute_name`
- `classification`
- `writable`
- `canAssignInNew`
- `reason`
- `evidence`
- `source_rule_version`

A classificação cobre o mesmo contrato dos gates: `key-attribute`, `extended-parent-fk`, `formula`, `extended-subtype-key`, `extended-subtype-descriptive`, `extended-fk-key`, `extended-fk-descriptive`, `own-physical` e estados `unclassified-*`.

### Benefícios obtidos

- redução de abertura repetida de XMLs do acervo na triagem
- consultas amplas sobre risco de `New`, `Formula`, atributos descritivos e campos não graváveis via índice
- paridade validada entre índice materializado e gates (`Test-GeneXusKbIntelligenceWritabilityParity.ps1`)
- fonte canônica única: `GeneXusTransactionWritabilityCore.py` (build, consultas e gates PowerShell)

### Limites e decisões remanescentes

- escopo do snapshot: somente `ObjetosDaKbEmXml`; não materializa XML de frente em `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- alteração do algoritmo exige atualizar o núcleo Python, bump de `writability_rule_version` / extrator e rebuild das pastas paralelas
- novos casos de validação em `Test-KbIntelligenceQueries.ps1` podem ser acrescentados conforme KBs reais revelarem bordas
- reabrir apenas se o algoritmo dos gates PowerShell mudar sem atualização do núcleo Python, ou se for necessário materializar também XML de frente em `ObjetosGeradosParaImportacaoNaKbNoGenexus`

### Entrega

- núcleo canônico: `scripts/GeneXusTransactionWritabilityCore.py` (`writability_rule_version=1`)
- tabela `transaction_attribute_writability` no SQLite (`schema_version=2`, extrator `4`)
- consultas `transaction-attributes` / `transaction-writable-attributes` leem a tabela materializada
- paridade obrigatória: `scripts/Test-GeneXusKbIntelligenceWritabilityParity.ps1` (validado em wsEducacaoSpTeste e FabricaBrasil)
- gates PowerShell `Test-GeneXusTransactionWritability.ps1` e `Test-GeneXusNewWritableTargets.ps1` delegam ao núcleo via `GeneXusTransactionWritabilitySupport.ps1`, sem algoritmo duplicado
- `Test-GeneXusNewWritableTargets.ps1` permanece obrigatório para blocos `New` em `Procedure`

### Rastreabilidade

- Commit: `a9e9bc9` (`Materializa gravabilidade de Transaction no indice SQLite (schema 2, extrator 4).`)
- Commit: `76f11a6` (`Delega gates de gravabilidade ao nucleo Python canonico.`)
- Commit: `4e34051` (`Alinha documentacao com gravabilidade materializada e gates Python.`)

## `Update-KbSourceMetadata` preserva campos fora de escopo e EOL no `xpz-sync`

**Importância original:** alta
**Status:** concluída em 2026-05-28

### Origem

Incidente real em pasta paralela FabricaBrasil18, reportado por agente externo. A função legada `Update-KbSourceMetadata` em `Sync-GeneXusXpzToXml.ps1` regerava `kb-source-metadata.md` inteiro e apagava `last_setup_audit_run_at` após setup bem-sucedido, forçando `AUDIT_REQUIRED` na sessão seguinte.

### Incidente

1. **Autoridade de campo violada:** o template do sync só incluía campos de materialização; `last_setup_audit_run_at` (setup) sumia a cada materialização oficial.
2. **EOL:** reescrita total não preservava EOL dominante nem newline final do arquivo existente (CRLF/misto em pastas com política local divergente).

### Implementação

| Commit | Entrega |
|---|---|
| `7402e58` | Pré-requisito: `XpzTextFileEolSupport.ps1`, `Set-XpzSetupAuditTimestamp.ps1`, `Update-XpzKbSourceMetadataIdentity.ps1`, `Test-XpzSetupAuditTimestampEolSelfTest.ps1`. |
| `20e9e49` | Etapa A: `scripts/XpzKbSourceMetadataEditSupport.ps1` com `Update-XpzKbSourceMetadataFromSync`; `Sync-GeneXusXpzToXml.ps1` deixa de regerar o arquivo; `Test-XpzSyncKbMetadataSelfTest.ps1` (sentinela `XPZ_SYNC_KB_METADATA_SELFTEST_OK`). |
| `06eba2e` | Etapa B: `09-inventario-e-rastreabilidade-publica.md`, `xpz-sync/SKILL.md` (autoridade por campo + atualização cirúrgica). |
| `f759971` | `README.md` trilíngue + ajustes finais de redação em `xpz-sync/SKILL.md` (handoff sem "reescrito"). |

Comportamento atual quando `-KbMetadataPath` está ativo:

| Campo / bloco | Ação |
|---|---|
| `updated`, `last_xpz_materialization_run_at`, `source_xpz`, `source_refresh_status` | atualizar ou inserir no frontmatter |
| Tabelas `## KMW`, `## Source`, `## Source/Version` | atualizar valores (merge pacote/baseline de tabela inalterado) |
| `last_setup_audit_run_at` e demais frontmatter/seções fora do escopo | preservar intactos |
| EOL e newline final | `Write-TextFilePreservingEol` via `XpzTextFileEolSupport.ps1` |
| Arquivo ausente | template completo (`Write-NewKbSourceMetadataTemplate`), sem carimbo de setup até o setup gravar |

### Decisões registradas

- **Criação do arquivo ausente:** manter template completo (equivalente ao legado), não minimal; setup continua responsável por identidade estável depois.
- **Frontmatter desconhecido futuro:** preservar genericamente tudo que não for dos quatro campos de materialização do sync; não whitelist fechada além do que o motor já não toca.
- **Self-test:** bateria dedicada `Test-XpzSyncKbMetadataSelfTest.ps1`, em vez de estender só o self-test do carimbo de setup.

### Follow-ups opcionais não mantidos como pendência desta entrada

- `Get-KbSourceMetadataSnapshot` ainda lê apenas tabelas Markdown e ignora frontmatter de materialização; avaliar em nova entrada própria se refresh parcial futuro precisar ler `source_xpz` / `source_refresh_status` do YAML.
- XML do acervo em `Write-ItemToDestination`: `WriteAllText` sem preservar EOL do XML existente; frente separada, risco menor enquanto XMLs são gerados do zero com LF na raiz.
- Rename `kb-source-metadata.md` -> `kb-parallel-state.md` já permanece como entrada separada em `999-ideias-pendentes.md`.

### Rastreabilidade

- Commit: `7402e58` (`Preserva EOL ao mutar kb-source-metadata.md no Windows.`)
- Commit: `20e9e49` (`Sync: atualização cirúrgica de kb-source-metadata (etapa A).`)
- Commit: `06eba2e` (`Sync: documenta mutação cirúrgica de metadata e fecha frente E (etapa B).`)
- Commit: `f759971` (`Docs: alinha README trilíngue e xpz-sync à autoridade de kb-source-metadata.`)
