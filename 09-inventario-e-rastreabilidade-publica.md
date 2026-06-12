# 09 - Inventario e Rastreabilidade Publica

## Papel do documento
índice e rastreabilidade

## Nível de confianca predominante
alto

## Depende de
nenhum

## Usado por
00-indice-da-base-genexus-xpz-xml.md, 01-base-empirica-geral.md

## Objetivo
Preservar rastreabilidade da consolidacao, inventario documental, inventario bruto publico sanitizado e o mapeamento usado para reorganizar a base consolidada.

## Nota sobre histórico detalhado

- `Evidência direta`: a raiz desta base passou a priorizar estado atual de trabalho, sem manter no corpo principal a arqueologia completa das rodadas de teste.
- `Evidência direta`: o histórico detalhado de validacoes, rodadas de importação e reclassificacoes deve ficar separado em `historico/`, para não competir com os `.md` operacionais da raiz.

## Nota sobre documentos de governança pública

- `Evidência direta`: `CHANGELOG.md` registra mudanças relevantes a partir da adoção do changelog, sem reconstruir retroativamente versões antigas.
- `Evidência direta`: `CONTRIBUTING.md` orienta contribuições humanas, revisão pré-push, cuidado com dados reais e avaliação de atualização do changelog quando houver impacto público.
- `Evidência direta`: `SECURITY.md` define o fluxo privado para reportar vulnerabilidades, vazamentos e riscos operacionais sensíveis.
- `Evidência direta`: `CODE_OF_CONDUCT.md` define o código de conduta aplicável às interações ligadas ao projeto.

## Nota sobre a rastreabilidade privada

- `Evidência direta`: existe uma pasta privada separada, `GeneXus-XPZ-PrivateMap`, usada para manter rastreabilidade editorial entre aliases publicos e artefatos reais.
- `Regra editorial`: essa rastreabilidade privada não substitui a documentação consolidada desta raiz; ela existe apenas como apoio privado de manutencao, sanitizacao e continuidade editorial.

## Nota sobre o motor operacional compartilhado

- `Evidência direta`: o script `scripts/Sync-GeneXusXpzToXml.ps1` e parte da infraestrutura operacional desta base publica.
- `Evidência direta`: esse script pode ser consumido por wrappers e fluxos locais de projetos de producao que mantenham acervos versionados de XMLs extraidos de `XPZ`.
- `Regra editorial`: a pasta `scripts/` existe como apoio operacional e utilitario compartilhavel, mas não funciona como fonte normativa da documentação consolidada da raiz.
- `Regra operacional`: esse arquivo não deve ser apagado silenciosamente do repositório publico.
- `Regra operacional`: se houver refatoracao, mudanca de local ou substituicao do motor, a alteracao deve ser documentada explicitamente e propagada aos consumidores externos antes de remover o arquivo anterior.
- `Evidência direta`: o script recebeu adição do parâmetro `-KbMetadataPath` para persistir metadados da KB em formato Markdown (`kb-source-metadata.md`), facilitando reuso em envelopes de importação; quando o caminho está ativo, o comportamento atual é mutação cirúrgica via `scripts/XpzKbSourceMetadataEditSupport.ps1` (ver entrada dedicada abaixo), não regeneração integral do arquivo.
- `Evidência direta`: `scripts/gx-object-type-catalog.json` inclui `DataView`, `SmartDevicesApplication` e `SmartDevicesPlus` (GUIDs Evo1 / GeneXus 18 U13 + pesquisa C4); ver `01a-catalogo-e-padroes-empiricos.md`.
- `Evidência direta`: `scripts/gx-object-type-catalog.json` pode incluir `exportTaskLabel` quando o rótulo da task MSBuild `Export` divergir do nome do tipo no catálogo; tabela operacional em `10a-gx-export-task-labels.md`.
- `Evidência direta`: `scripts-maintenance/GeneXusExportTaskLabelSupport.ps1`, `scripts-maintenance/Build-ExportTaskLabelCoverageMap.ps1`, `scripts-maintenance/Run-ExportTaskLabelMatrix.ps1`, `scripts-maintenance/Invoke-ExportTaskLabelCampaign.ps1` e `scripts-maintenance/Merge-ExportTaskLabelCampaignResults.ps1` implementam a campanha de manutenção da base para matriz `exportTaskLabel` (cobertura, execução MSBuild por tipo, consolidação e opcional `-ApplyCatalog`); não são runtime público das skills em pastas paralelas de KB; evidência de rodada em `historico/export-task-label-matrix-20260530/` e contrato em `10a-gx-export-task-labels.md`.
- `Evidência direta`: `scripts/Get-GeneXusImportPackageObjectInventory.ps1` inventaria `import_file.xml`, XML com raiz `<ExportFile>` ou `.xpz` (XML interno único), lista objetos e atributos top-level, agrega `objectsByType`, detecta objetos de plataforma/SDK via `scripts/gx-platform-objects.json` (`systemObjectsPresent` com `name` e `kind`), emite `attributes-top-level-em-export-cirurgico` quando export seletiva traz atributos top-level sem `Transaction` na lista declarada, e confronta delta declarado (`-DeclaredDeltaPath` ou `-DeclaredDeltaItems`); em divergencia de rotulo Export documentada (`exportTaskLabel`), preenche `deltaComparison.aliasResolutions[]` (regra `exportTaskLabel`) e ajusta `requestedItemsFound`/`missingCount` — resumo em `packageInventory` via `scripts/GeneXusPackageInventorySupport.ps1` (`aliasResolutionCount`, `aliasResolutions` ou `aliasResolutionsFullListAt`).
- `Evidência direta`: `scripts/GeneXusObjectListIdentityPreflight.ps1` valida identidade `Tipo:Nome` contra `KbIntelligence` antes de export/import seletivo MSBuild; consumido por `scripts/Invoke-GeneXusXpzExport.ps1` (`gateContext=export`, estágio `pre-export-identity`), `scripts/Invoke-GeneXusXpzImport.ps1` e `scripts/Test-GeneXusXpzImportPreview.ps1` (`pre-import-identity`); homônimo ou índice ausente/inválido → exit **35** (`objectListPreflight` no JSON); `not_in_index` → aviso sem bloquear MSBuild; `scripts/Test-GeneXusObjectListIdentityPreflightSelfTest.ps1` cobre export/import seletivo sem índice.
- `Evidência direta`: `scripts/Invoke-GeneXusXpzExport.ps1` após exportação com XPZ gerado preenche `packageInventory` resumido no diagnostico JSON via `scripts/GeneXusPackageInventorySupport.ps1` (carregado por `scripts/GeneXusXpzExportInventoryGovernance.ps1`), grava `package-inventory.json` completo no diretório de artefatos, expoe `nominalInventoryAt` apontando para o sidecar quando gravado (lista nominal completa); em confronto seletivo com delta, `extrasFullListAt` repete o mesmo caminho do sidecar para a lista completa de extras de `<Objects>`; `extrasSample`/`extrasSampleTruncated` para extras de `<Objects>` no resumo, classifica `operationalSubState` no módulo de governanca de export e marca `inventoryDegraded=true` sem rebaixar o exit code da task MSBuild quando o inventario falha.
- `Evidência direta`: `scripts/GeneXusXpzExportInventoryGovernance.ps1` concentra `New-ExportPackageInventoryBlock`, `Resolve-ExportPackageInventoryOperationalSubState` e `Resolve-ExportOperationalSubState` (precedencia: `exportErrors` > inventario degradado > sub-estado do inventario); `scripts/Test-GeneXusXpzExportSubStateClassifierSelfTest.ps1`; sentinela `EXPORT_SUBSTATE_CLASSIFIER_SELFTEST_OK`.
- `Evidência direta`: `scripts/msbuild-exit-codes.catalog.json` — índice versionado de `exitCode` dos wrappers MSBuild (probe `10`–`16`, import/export `31`–`35`/`41`–`42`, politica **46** com `causes[]`, cancelamento **47**, Categoria B **48**, build **40**–**45**, deploy bin freshness **49**, falha interna **90**); exit **35** = pré-validação de identidade em lista seletiva (`objectListPreflight`); exit **46** inclui, entre outras causas, `ForceRebuild=true` sem `-AllowWideRebuild`, `CompileMains=true`/`DetailedNavigation=true` sem `-AllowCostlyBuildOptions` e confirmações desacopladas de seus switches; verificacao `scripts/Test-MsBuildExitCodesCatalog.ps1` (sentinela `MSBUILD_EXIT_CODES_CATALOG_OK`).
- `Evidência direta`: `scripts/GeneXusMsBuildConcurrencySupport.ps1` e `scripts/Test-GeneXusMsBuildKbConcurrency.ps1` implementam o bloqueio preventivo de `MSBuild.exe` concorrente para a mesma KB GeneXus: reconciliam processos em execução via `Win32_Process`, extraem o `.msbuild` da linha de comando, leem `KBPath` do projeto e bloqueiam somente quando a mesma KB é confirmada; processos sem linha de comando, sem `.msbuild` ou sem `KBPath` reconciliável são avisos, não bloqueios. Os wrappers `Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1`, `Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1` e `Test-GeneXusXpzImportPreview.ps1` registram `msBuildConcurrency` no JSON e retornam `exitCode=46` com `status='bloqueado por MSBuild concorrente'` quando há conflito confirmado; a trilha não enfileira, não aguarda e não faz retentativa em loop; `scripts/Test-GeneXusMsBuildConcurrencySupportSelfTest.ps1` valida parsing de command line, leitura de `KBPath` e classificação bloqueada/ok com processos simulados (sentinela `GENEXUS_MSBUILD_CONCURRENCY_SUPPORT_SELFTEST_OK`).
- `Evidência direta`: `scripts/Invoke-GeneXusKbBuildAll.ps1` bloqueia `CompileMains=true` e `DetailedNavigation=true` sem `-AllowCostlyBuildOptions`; `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1` bloqueia `DetailedNavigation=true` sem `-AllowCostlyBuildOptions`; ambos registram `AllowCostlyBuildOptionsRequested`, `AllowCostlyBuildOptionsConfirmed` e `ConfirmCostlyBuildOptionsMode` no JSON e exigem a frase exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar` para execução interativa; `scripts/Invoke-GeneXusXpzImportThenBuild.ps1` propaga `-AllowCostlyBuildOptions` e `-ConfirmCostlyBuildOptions` para o build pos-import.
- `Evidência direta`: `scripts/Invoke-GeneXusXpzImportThenBuild.ps1` foi incorporado como wrapper integrador para a rodada `Invoke-GeneXusXpzImport.ps1` → `Invoke-GeneXusKbBuildAll.ps1`; executa os filhos em processos `pwsh -NoProfile -File`, grava `import.json` e `build.json` em diretório de artefatos, e só chama `BuildAll` quando `importReadyForBuild.ready=true` (`exitCode=0`, sem `blockingReasons`, sem `msBuildCategoryBBlocked` e sem status de falha/bloqueio). Quando a importação não fica apta, o JSON final traz `roundtripStatus='import-blocked-or-failed'`, `buildJson=null` e `buildSkippedReason`; o `exitCode` final acompanha o import ou usa **46** quando não há código mais específico.
- `Evidência direta`: `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1` centraliza a extração de `postBuildEvents` em stdout MSBuild (janela iniciada por `Executando eventos pos-construcao ...` até o próximo separador `==========`, com fallback histórico `start c:` / `start cmd`) **e** a classificação declarativa desses eventos: `Get-GeneXusPostBuildEventNormalizedHash` (SHA-256 normalizado), `Test-GeneXusPostBuildEventInert` (linha `REM` comentada, inerte), `Test-GeneXusPostBuildEventBenignBySound` (player de som como rede de segurança) e `Get-GeneXusPostBuildEventClassification` (separa esperado/inesperado/inerte/benigno e devolve `shouldDowngrade`). `scripts/Invoke-GeneXusKbBuildAll.ps1` e `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1` comparam os eventos observados contra `kb_environment_post_build_event_hashes` do environment ativo (lido por `Get-GeneXusRegisteredPostBuildEventHashesForEnvironment` em `scripts/GeneXusKbDeploymentEnvironmentSupport.ps1`): evento registrado = esperado (não rebaixa); não registrado/não reconhecido = rebaixa por cautela; preenchem `stdoutSignals.postBuildEvents` e `stdoutSignals.postBuildEventClassification`. `scripts/Register-GeneXusKbPostBuildEvents.ps1` (autoria do campo, sob `xpz-kb-parallel-setup`) registra a partir do JSON de um build (`stdoutSignals.postBuildEvents`), grava o campo plano de fingerprints + a seção-espelho legível `## Eventos pos-build registrados`, com confirmação por frase exata (interativo) ou `-ConfirmRegistration` (agente). Self-tests: `scripts/Test-GeneXusMsBuildPostBuildEventsSupportSelfTest.ps1` (extração — `start`, `call`, `cmd /k`, `powershell`, `REM`, janela vazia, fallback legado; sentinela `GENEXUS_MSBUILD_POST_BUILD_EVENTS_SUPPORT_SELFTEST_OK`), `scripts/Test-GeneXusPostBuildEventClassificationSelfTest.ps1` (sentinela `GENEXUS_POST_BUILD_EVENT_CLASSIFICATION_SELFTEST_OK`) e `scripts/Test-GeneXusKbPostBuildEventsRegistrationSelfTest.ps1` (round-trip e preservação multi-environment; sentinela `GENEXUS_KB_POST_BUILD_EVENTS_REGISTRATION_SELFTEST_OK`).
- `Evidência direta`: `scripts/GeneXusMsBuildGamPlatformsSupport.ps1` centraliza o filtro de ruido estrutural GAM/NetCore em stdout (`error MSB3491` ou `NuGet.targets(...): error :` com acesso negado sob `\Library\GAM\Platforms\` da instalacao GeneXus), expoe `Get-GamPlatformsStdoutPostFilterResult` (omite `environmentRemediationHints` quando não ha linhas filtradas) e, quando pelo menos uma linha e filtrada, monta `environmentRemediationHints.gamPlatformsWriteDeniedFiltered` com comandos `icacls` sugeridos (conceder/verificar/reverter) derivados de `resolvedPaths.GeneXusDir` e da conta Windows do processo — sem executar concessao NTFS; consumido por `scripts/Invoke-GeneXusKbBuildAll.ps1` e `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1` com pos-processamento resiliente (`postProcessingFailed`/`postProcessingError`, sem rebaixar MSBuild limpo para exit 90); `scripts/Test-GeneXusMsBuildGamPlatformsSupportSelfTest.ps1` (sentinela `GENEXUS_MSBUILD_GAM_PLATFORMS_SUPPORT_SELFTEST_OK`, inclui cenário zero ruido filtrado).
- `Evidência direta`: `scripts/Read-MsBuildImportSignals.ps1` classifica linhas `error :` do stdout/stderr por estágio (`export`, `import`, `preview`, `build-all`, `specify-generate`) em `exportErrors`, `importErrors`, `previewErrors`, `buildErrors`, `specifyErrors`, tipos rejeitados em `invalidTypesRejected` e ruido conhecido em `knownStdOutNoise`; `scripts/GeneXusMsBuildCategoryBSupport.ps1` implementa rebaixamento para exit **48** (Categoria B); `scripts/Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` rebaixam `exitCode` para 48 quando `executionEvidence.msBuildExitCode=0` mas o log traz rejeicao B (`msBuildCategoryBBlocked=true` no top-level do JSON); `operationalSubState` por trilha: export `exportação parcial com errors do MSBuild — artefato não confiável`, import `importação com errors do MSBuild — alteração não confiável`, preview `preview com errors do MSBuild — diagnóstico não confiável`, build `build com errors do MSBuild — resultado não confiável`; `scripts/Test-GeneXusMsBuildCategoryBSupportSelfTest.ps1` (sentinela `MSBUILD_CATEGORY_B_SUPPORT_SELFTEST_OK`); `scripts/Test-GeneXusXpzExportErrorBarringSelfTest.ps1` (sentinela `EXPORT_ERROR_BARRING_SELFTEST_OK`).
- `Evidência direta`: `scripts/gx-platform-objects.json`, `scripts/GeneXusPlatformObjectsCatalogSupport.ps1` e `scripts/Test-GeneXusPlatformObjectsCatalogSelfTest.ps1` — catálogo unificado de plataforma/SDK (`kind` `packagedModule` | `externalObject`); sentinela `GENEXUS_PLATFORM_OBJECTS_CATALOG_SELFTEST_OK`.
- `Evidência direta`: `scripts/Test-GeneXusImportPackageObjectInventorySelfTest.ps1` valida o motor `scripts/Get-GeneXusImportPackageObjectInventory.ps1` em XML e `.xpz` sintetico (delta seletivo, `PackagedModule` e `ExternalObject` de plataforma, sinal de atributos top-level sem `Transaction` na lista e controle negativo com `Transaction`); sentinela `GENEXUS_PKG_INVENTORY_SELFTEST_OK`.
- `Evidência direta`: `scripts/Test-XpzParameterNamingContract.ps1` trava o contrato de nomenclatura de parâmetros das skills XPZ via metadados (`Get-Command`, sem KB): selecao por nome `-ObjectList` com alias `-ObjectNames` (`[string[]]` no export), entrada primaria `-InputPath` com alias `-Path`, familia de import (`Invoke-GeneXusXpzImport`, `Invoke-GeneXusXpzImportThenBuild`, `Test-GeneXusXpzImportPreview`) com `-InputPath` e aliases `-XpzPath`/`-Path`, e a regra de direcao (export mantem `-XpzPath` de saida, sem alias `-InputPath`), além da trava negativa de contrato de saida do motor de sanidade (`Test-GeneXusSourceSanity.ps1` não expoe `-AsJson`, pois emite JSON por padrão); contrato documentado em `02-regras-operacionais-e-runtime.md`; sentinela `XPZ_PARAMETER_NAMING_CONTRACT_OK`.
- `Evidência direta`: `scripts/GeneXusObjectTypeCatalogSupport.ps1` mescla `gx-object-type-catalog.json` com override local `scripts/gx-object-type-catalog.override.json`, agrega tipos desconhecidos no XPZ e formata mensagens de triagem.
- `Evidência direta`: `scripts/Register-GeneXusObjectTypeCatalogOverride.ps1` grava override paliativo com `-UserApproved` e `upstreamPending=true`.
- `Evidência direta`: `scripts/Test-XpzCatalogOverrideSessionReminder.ps1` emite lembrete de sessao quando override local exige alinhamento upstream em GeneXus-XPZ-Skills (exit 2 quando `reminderRequired`).
- `Evidência direta`: `scripts/New-GeneXusUnknownTypeMaintainerPrompt.ps1` gera prompt copiavel para o mantenedor registrar tipo no catálogo compartilhado.
- `Evidência direta`: `scripts/Test-GeneXusUnknownTypeDiscoverySelfTest.ps1` valida agregacao de GUID desconhecido, override, lembrete e inventario pos-merge; sentinela `OK: Test-GeneXusUnknownTypeDiscoverySelfTest.ps1`.
- `Evidência direta`: `Sync-GeneXusXpzToXml.ps1` aceita `-ParallelKbRoot`, `-CatalogOverridePath`, `-DiscoveryReportPath`; falha com amostras (`name`, `parent`, `parentType`, snippet) antes da materialização quando o GUID não está no catálogo efetivo.
- `Evidência direta`: `Get-GeneXusImportPackageObjectInventory.ps1` aceita `-FailOnUnknownTypes` (exit 3), `-ParallelKbRoot`, `-CatalogOverridePath` e expoe `unknownTypesDiscovery` para pre-varredura de sync.
- `Evidência direta`: `Test-XpzObjetosDaKbNaming.ps1` usa o mesmo catalogo efetivo (base + override via `GeneXusObjectTypeCatalogSupport.ps1` e `-ParallelKbRoot`) para auditoria de naming em `ObjetosDaKbEmXml`.
- `Evidência direta`: `scripts/GeneXusPackageInventorySupport.ps1` com `scripts/Build-GeneXusImportFileEnvelope.ps1` e `scripts/New-XpzImportPackage.ps1` embute `packageInventory` no JSON de retorno após gravar o pacote; `scripts/Test-XpzBuilderPackageInventorySelfTest.ps1` valida o fluxo xpz-builder (delta declarado, `extrasCount` e `ConvertTo-DeclaredDeltaItemsFromObjectDocuments`); sentinela `XPZ_BUILDER_PACKAGE_INVENTORY_SELFTEST_OK`; `scripts/Test-GeneXusPackageInventorySupportSelfTest.ps1` valida o contrato resumido compartilhado (`nominalInventoryAt`, `extrasFullListAt`, `attributesTopLevelUnreconciled` em pacote sintetico); sentinela `GENEXUS_PACKAGE_INVENTORY_SUPPORT_SELFTEST_OK`.
- `Inferência forte`: esse inventario complementa a validação de envelope; ele não transforma a pasta `scripts/` em fonte normativa, mas registra motor compartilhado relevante para rastreabilidade operacional.
- `Evidência direta`: `scripts/Test-GeneXusImportFileEnvelope.ps1` valida estaticamente `import_file.xml` e, para `Panel`, aceita `-PanelReferencePath` para registrar `panel-level-layout-confirmed` em `information`; sem referencia comparavel ou com par divergente, registra respectivamente `panel-level-layout-unverified` ou `panel-level-layout-suspicious` em `warnings`.
- `Evidência direta`: `scripts/Get-GeneXusObjectSummary.ps1` e `scripts/Compare-GeneXusPanelShape.ps1` foram ampliados para diagnostico compacto de `Panel`, incluindo eventos serializados em `detail/@events`, cobertura action/event e categorias `namedEventNames`, `standardEventNames`, `variableEventNames` e `tapEventNames`, sem despejar XML/CDATA completo.
- `Evidência direta`: `scripts/Get-GeneXusObjectSummary.ps1` ganhou o bloco `webpanel` para `WebPanel` classico (`type c9584656-94b6-4ccd-890f-332d11fc2c25`): `tables` com `tableType` (Flex/Responsive) e `depth`, `controls`, `buttons` nas formas `<action>` e `<ucw>` Button (desserializado de `PATTERN_ELEMENT_CUSTOM_PROPERTIES`), `eventNames` e um bloco `coverage` que declara limites e reporta `gxControlType` desconhecido em `unknownUcwControlTypes`. O `gxControlType` e resolvido pelo catalogo versionado `scripts/gx-ucw-gxcontroltype-catalog.json` (doc em `04b-ucw-gxcontroltype-reference.md`); regressao em `scripts/Test-GeneXusWebPanelShapeContract.ps1`.
- `Evidência direta`: `scripts/Add-GeneXusButton.ps1` adiciona um botao a `WebPanel` de forma cirurgica — insere `<cell>` (forma `<action>` ou `<ucw>` Button) antes ou após a celula de um controle folha nomeado (`-BeforeControlName`/`-AfterControlName`, mutuamente exclusivos via parameter sets) em tabela `Flex`, com stub de `Event`, bump de `lastUpdate` e validação de bem-formado (reusa `GeneXusXmlSurgicalEditSupport.ps1` — cujo primitivo `Invoke-GeneXusXmlLiteralPatch` ganhou o modo `InsertBefore` —, não re-serializa o CDATA); aborta fail-closed (`RESPONSIVE_UNSAFE`) em tabela `Responsive` com `responsiveSizes` preenchido. Regressao em `scripts/Test-GeneXusAddButtonContract.ps1`.
- `Evidência direta`: `scripts/Test-GeneXusTransactionCoherence.ps1` (gate `9-TWS` de coerência de Transaction, base do passo 9-TWS do `xpz-builder`; recebe `-InputPath`/`-Path`, emite JSON com `-AsJson`) ganhou o finding `wwp-screen-code-on-non-generated-transaction` (`fail`): Transaction com `GenerateObject=False` que carrega código de tela WorkWithPlus DVelop orfao (`Call("LoadWWPContext")`/`Call("<Trn>WW")`) em Events/Rules e barrada antes do empacotamento (`src0246`/`src0294`, `confirmado-import` GX18U13 + WorkWithPlus_Web 16.0.3.1); Work With nativo (`Apply:78cecefe`) fica fora de escopo. Regressao em `scripts/Test-GeneXusTransactionCoherenceSelfTest.ps1` (sentinela `OK: Test-GeneXusTransactionCoherenceSelfTest.ps1`).
- `Evidência direta`: `scripts/Search-GeneXusXmlSourceBlock.ps1` foi incorporado como ponto de entrada publico para busca textual pontual em blocos `<Source>` de XML GeneXus, separando `events`, `layout`, `code` e `serialized`; evita tratar `GxMultiForm` inline de `WebPanel` como evidencia de code-behind e emite resultado compacto ou JSON (`-AsJson`) sem despejar CDATA gigante; `scripts/Test-SearchGeneXusXmlSourceBlockSelfTest.ps1` valida a separacao layout/events/code em fixture sintetica (sentinela `SEARCH_GENEXUS_XML_SOURCE_BLOCK_SELFTEST_OK`).
- `Evidência direta`: `scripts/Resolve-GeneXusKbIdentity.ps1` foi incorporado como motor compartilhado somente leitura para resolver identidade estavel da KB nativa local a partir de `model.ini`, `knowledgebase.connection` e banco interno da KB.
- `Evidência direta`: `scripts/Update-XpzKbSourceMetadataIdentity.ps1` foi incorporado como atualizador conservador e localizado dos campos de identidade estavel em `kb-source-metadata.md`, preenchendo ausentes e bloqueando divergencias não vazias salvo aprovacao explicita; reescrita via `scripts/XpzTextFileEolSupport.ps1` preserva EOL dominante e newline final do arquivo.
- `Evidência direta`: `scripts/Test-XpzWrapperInventory.ps1` passou a emitir `INVENTORY_LEGACY_ORPHANS` quando scripts legados permanecem lado a lado com nomes canonicos atuais e `INVENTORY_RECOMMENDED_MISSING` quando sinais objetivos de uso recomendam wrappers finos ainda ausentes; para `Set-KbSourceMetadataDeployment.example.ps1`, detecta wrapper local que ainda repassa descoberta automática de environments (`InventoryFromKbNativePath`/`InventoryFromGeneXusMsBuild`) ou omite `-KbEnvironmentNames`, `-KbEnvironmentOutputDirs` e parâmetros de validação MSBuild (`KbNativePath`, `InventoryWorkingDirectory`).
- `Evidência direta`: `scripts/Test-XpzKbDeploymentMetadata.ps1` valida plausibilidade estrutural dos campos de environment/deploy/output em `kb-source-metadata.md` (contagem vs lista, `deployment_environment_name` na lista, mapeamento `kb_environment_output_dirs`/`kb_environment_web_dirs` por environment, rejeicao de nomes tipicos de metadata legado por scan de pastas `web\`); integrado em `scripts/Test-XpzSetupAudit.ps1` como dimensao `metadata/deploy`; não substitui pergunta ao usuário nem validação MSBuild de nomes declarados.
- `Evidência direta`: `scripts/Test-XpzWrapperInventorySelfTest.ps1` foi incorporado como bateria mínima de validação do inventario de wrappers locais, cobrindo a classificação `INVENTORY_CUSTOMIZED` por divergencia de `#requires -Version`, a exceção intencional do wrapper de runtime, o sinal bloqueante `INVENTORY_LEGACY_ORPHANS` para scripts legados lado a lado com nomes canonicos e o sinal consultivo `INVENTORY_RECOMMENDED_MISSING` para wrappers finos recomendados por evidencia objetiva de uso.
- `Evidência direta`: `scripts/Build-GeneXusImportFileEnvelope.ps1` foi incorporado como motor compartilhado de montagem de `import_file.xml` a partir de objetos XML locais e template validado, com gate embutido de colisao de pacote e, atualmente, `-AcervoPath <ObjetosDaKbEmXml>` obrigatório e gate mecanico de `lastUpdate` que bloqueia timestamp anterior ou igual ao acervo em objeto declarado modificado por `-ModifiedObjectNames` ou `-ModifiedObjectGuids`, além de futuro injustificado (inclusive quando o objeto não tem baseline no acervo). Para `Panel`, o helper repassa `-TemplatePackagePath` ao gate de envelope como `-PanelReferencePath` e propaga no resultado `information` (incluindo `panel-level-layout-confirmed` quando comprovado) ou `warnings` (`panel-level-layout-unverified`/`panel-level-layout-suspicious`), em substituicao ao aviso genérico anterior de acoplamento.
- `Evidência direta`: `scripts/Test-BuildGeneXusImportFileEnvelopeSelfTest.ps1` exercita o motor real `Build-GeneXusImportFileEnvelope.ps1` com fixture mínima e confirma que XMLs com nome de referência/exemplo/template/molde são bloqueados quando passados como `-ObjectXmlPaths` ou `-TopLevelAttributesXmlPaths`, enquanto `-TemplatePackagePath` pode conter `template` no nome por ser fonte comparável legítima do envelope (sentinela `BUILD_GENEXUS_IMPORT_FILE_ENVELOPE_SELFTEST_OK`).
- `Evidência direta`: `scripts/New-XpzImportPackage.ps1` é o wrapper PowerShell do empacotamento por frente e delega ao motor Python `scripts/New-XpzImportPackage.py`, que lê `kb-source-metadata.md`, resolve as pastas padrão da pasta paralela, classifica raízes `Object`/`Attribute` da pasta da frente, executa o gate de colisao e monta `import_file.xml`. A saída de máquina é JSON por padrão no stdout (sem `-AsJson`); bloqueios esperados retornam objeto estruturado com `status`, `exitCode`, `stage` e `blockingReasons` (colisao de rodada: `reason=PACKAGE_ROUND_COLLISION`, `nextFreeNN`/`nextFreeRound`, exit 20), nunca stack/ANSI no canal de máquina; o wrapper executa sempre, antes do empacotamento, o gate de drift 9-FD (`Test-GeneXusFrontAcervoDrift.ps1`) em modo fail-closed: `-AcervoPath` é opcional e, quando omitido, o acervo canônico `<RepoRoot>/ObjetosDaKbEmXml` é resolvido automaticamente; sem acervo resolvível o empacotamento é bloqueado, e o JSON reporta `acervoResolvedBy` (`explicit` ou `convention`). Verificação do motor por `scripts/Test-NewXpzImportPackage.py` (bloqueio de XML de referência e contrato do gate de colisao livre/ocupado) e do contrato fail-closed do wrapper por `scripts/Test-NewXpzImportPackageDriftSelfTest.ps1`.
- `Evidência direta`: `scripts/Test-XpzPackageCollision.ps1` é o motor compartilhado do gate de colisao de rodada de pacote, consumido por `scripts/Build-GeneXusImportFileEnvelope.ps1` e pelos wrappers locais `Test-*KbPackageCollision.ps1`; aceita `-PackagePath` (aliases `-Path`/`-InputPath`) ou `-FrontPrefix`/`-NN`/`-OutputDir` e emite JSON por padrão no stdout — rodada livre `status=ok`/`reason=COLLISION_OK`/exit 0; colisao `status=bloqueado`/`reason=PACKAGE_ROUND_COLLISION`/`nextFreeNN`/`nextFreeRound`/exit 20; `scripts/Test-XpzPackageCollisionSelfTest.ps1` cobre rodada livre, colisao com sugestao de próximo `nn` e alias `-Path` (sentinela `OK: Test-XpzPackageCollisionSelfTest.ps1`).
- `Evidência direta`: `scripts/Test-GeneXusSourceSanity.ps1` é o motor compartilhado do gate de sanidade mínima de `Source` de XML de objeto GeneXus (base do wrapper local `Test-*KbSourceSanity.ps1`); recebe `-InputPath` (alias `-Path`) e emite JSON por padrão no stdout (sem `-AsJson`) com `xmlWellFormed`, `sourceSanityStatus` e `probablyImportable`, bloqueando empacotamento quando `xmlWellFormed=false` ou `sourceSanityStatus=fail`.
- `Evidência direta`: `scripts/Test-GeneXusFrontAcervoDrift.ps1` foi incorporado como gate de drift frente-vs-acervo (passo 9-FD): para cada XML de objeto na pasta da frente, busca o homônimo no acervo por GUID ou nome e compara `lastUpdate`; findings `front-older-than-acervo` (severidade `fail`) bloqueiam o empacotamento via `New-XpzImportPackage.ps1` (gate fail-closed, executado sempre), `front-equals-acervo` e `lastupdate-unparseable` (`warn`) exigem confirmação, `front-only-new-object` e `front-newer-than-acervo` (`info`) são informativos. O gate não substitui o passo 12 (verificação de edições locais indevidas no acervo).
- `Evidência direta`: `scripts/Copy-GeneXusAcervoToFront.ps1` foi incorporado como motor de resolução de drift e seed explicito: copia XMLs do acervo para a pasta da frente quando o acervo é mais recente, com bump automático de `lastUpdate` (`max(UtcNow + margin, acervoLastUpdate + margin)`, margem padrão 60s); resolve o anti-padrão "editar acervo esperando que o pacote pegue" (ver `02-regras-operacionais-e-runtime.md` e `xpz-builder/SKILL.md` passo 9-FD); suporta `-ObjectList` (`Tipo:Nome`, usando o nome para localizar XML), `-ObjectNames` e `-ObjectGuids` para seleção e, quando um alvo explicito ainda não existe na frente, faz seed inicial desse único objeto a partir do acervo; frente vazia sem alvo explicito continua `not-applicable`; `-DryRun` para preview; a saída de máquina é JSON por padrão no stdout; findings `front-older-than-acervo` e `front-equals-acervo` resultam em cópia+bump, `seeded-and-bumped` registra seed com bump, `seed-target-not-found`/`seed-target-ambiguous`/`seed-destination-exists` bloqueiam o seed solicitado, `front-only-new-object` e `front-newer-than-acervo` são ignorados, `lastupdate-unparseable-skip` (ação `skip`) requer resolução manual; self-test `scripts/Test-CopyGeneXusAcervoToFrontSelfTest.ps1` cobre frente vazia sem seed implicito, seed explicito por nome/GUID, seed via `-ObjectList` e alvo inexistente.
- `Evidência direta`: a frente de geração e empacotamento local passou a registrar a fidelidade textual do delta como verificacao previa ao pacote: copias alteradas em `ObjetosGeradosParaImportacaoNaKbNoGenexus` devem preservar comentarios, `CDATA`, indentacao, linhas em branco, ordem de nos, quebras de linha e whitespace herdado fora do delta aprovado; ruido de reserializacao ou whitespace fora do delta deve bloquear a entrega ate correcao cirurgica ou aprovacao explicita.
- `Evidência direta`: `scripts/Get-GeneXusXpzLastUpdate.ps1` foi incorporado como motor compartilhado de timestamp canonico GeneXus, retornando `max(UtcNow + margem, lastUpdate do baseline + margem)` quando `-BaselineXmlPath` apontar para XML do acervo oficial, com margem padrão de 60 segundos.
- `Evidência direta`: `scripts/Edit-GeneXusXmlSurgical.ps1` e `scripts/GeneXusXmlSurgicalEditSupport.ps1` implementam edicao cirurgica de XML de objeto GeneXus em modo raw (`Replace` / `InsertAfter`, validação de ancora literal, `-DryRun`, `-OutputPath` opcional, bump automático de `lastUpdate` com escape `-PreserveLastUpdate`, backup e restauracao em `XML_NOT_WELLFORMED_AFTER`); o bump delega a `Get-GeneXusXpzLastUpdate.ps1`; verificacao `scripts/Test-EditGeneXusXmlSurgicalContract.ps1` (sentinela `EDIT_GENEXUS_XML_SURGICAL_CONTRACT_OK`); consumo normativo em `xpz-builder/SKILL.md` e exemplo `xpz-builder/examples/Edit-GeneXusXmlSurgical.example.ps1`.
- `Evidência direta`: `scripts/Set-GeneXusXmlLastUpdate.ps1` foi incorporado como motor de re-carimbo (bump) do `lastUpdate` da raiz de um XML de objeto GeneXus já editado, in-place, sem copiar do acervo nem aplicar delta; recalcula `max(UtcNow + margem, baseline + margem)` reusando `Get-GeneXusXpzLastUpdate.ps1` e as funções de leitura/gravacao/validacao de `GeneXusXmlSurgicalEditSupport.ps1` via dot-source (sem alterar `Edit-GeneXusXmlSurgical.ps1`), com backup `.bak`, restauracao em `XML_NOT_WELLFORMED_AFTER`, `-DryRun` e `-AsJson`; sem `-BaselineXmlPath` o baseline é o próprio arquivo (suficiente para ficar acima do objeto vivo na KB, que preserva o `lastUpdate` importado como Modified Date), e `-BaselineXmlPath` aponta para o acervo quando se quer garantir acima dele; self-test `scripts/Test-SetGeneXusXmlLastUpdateSelfTest.ps1` cobre bump simples, baseline no futuro, `-DryRun`, XML sem `lastUpdate` e input inexistente; consumo normativo em `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `xpz-builder/SKILL.md` e `xpz-builder/quality-checklist.md`.
- `Evidência direta`: `scripts/Test-GeneXusObjectVariableDelta.ps1` foi incorporado como diagnostico conservador para variáveis de XML de objeto GeneXus, com modo de delta por `-VariableName` (falha em variável declarada ausente, duplicada, sem propriedade `Name`, com nome divergente ou sem evidencia de tipo suficiente) e modo consultivo sem `-VariableName` para varrer legado sem reprovar automaticamente formas raras; aceita `-AllowShapeOnlyType` para casos justificados de tipagem por propriedades estruturais; consumo normativo em `xpz-builder/SKILL.md`, `xpz-builder/quality-checklist.md`, `02-regras-operacionais-e-runtime.md` e `08-guia-para-agente-gpt.md`.
- `Evidência direta`: `scripts/Find-CsAttributeAssignments.ps1` e `scripts/GeneXusCsAttributeAssignmentSupport.ps1` mapeiam atribuicoes de atributo Transaction no `.cs` gerado (camada web), `AssignAttri` por método e padrão triplet do Specifier (`cascadeOrder`); `methods[].name` preserva o nome literal gerado e deve ser interpretado pelo mapa canonico dos quatro métodos em `xpz-builder/responsibilities-by-type/transaction.md`; verificacao `scripts/Test-FindCsAttributeAssignmentsContract.ps1` (sentinela `FIND_CS_ATTRIBUTE_ASSIGNMENTS_CONTRACT_OK`); consumo complementar pos-build em `xpz-msbuild-build/SKILL.md`.
- `Evidência direta`: a base passou a registrar catalogo consultavel de clausulas `on <evento>` e restrições de `Events` em `Transaction` (rejeicoes `src0056`/`spc0150` na trilha XPZ), anti-padroes nomeados em `02-regras-operacionais-e-runtime.md`, rotulos de evidencia para geração XPZ e encaminhamento em `xpz-msbuild-import-export/SKILL.md`, `xpz-msbuild-build/SKILL.md` e `08-guia-para-agente-gpt.md`; fonte canonica do catalogo: `xpz-builder/responsibilities-by-type/transaction.md`; uso correto de linguagem GeneXus permanece em skill **nexa** e documentação de produto.
- `Evidência direta`: `scripts/New-GeneXusXpzFront.ps1` foi incorporado como motor compartilhado de abertura de frente em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, criando ou reutilizando subpasta `NomeCurto_GUID_YYYYMMDD` em chamada atômica e devolvendo GUIDs adicionais quando solicitado.
- `Evidência direta`: `13-revisao-pre-push.md` concentra a rotina pre-push autoritativa (mecanico, semantica, avaliacao de `CHANGELOG.md` para mudancas com impacto publico, paridade motor↔doc, veredicto); `AGENTS.md` apenas aponta para esse arquivo.
- `Evidência direta`: `14-revisao-pre-push-reforcada.md` define o tier reforcado e opcional da rotina pre-push — orquestracao de painel multi-modelo diverso por cima da rotina do `13`, regua de convergencia (push-ready só quando o painel inteiro responde "sem gap" sobre o estado final) e papeis (montagem mecanica e opiniao do agente vs decisão humana de triagem, convergencia e push); o mecanismo de delegacao a LLM secundario fica em `xpz-llm-delegate/SKILL.md`.
- `Evidência direta`: `scripts/Invoke-PrePushMechanicalChecks.ps1` foi incorporado como orquestrador mecanico da rotina pre-push, coordenando contexto git no intervalo `BaseRef..HEAD` (default `origin/main..HEAD`), `git diff --check`, classificação de arquivos alterados, delegacao a `scripts/Test-PsScriptsParse.ps1` e parse Python via `scripts/Test-PyScriptsParse.ps1`, sem substituir a fase semantica obrigatória descrita em `13-revisao-pre-push.md`.
- `Evidência direta`: `scripts/Test-PyScriptsParse.ps1` valida sintaxe de `scripts/*.py` via `ast.parse`, sem `py_compile` e sem gerar `__pycache__/*.pyc`; sentinela textual `FILES=N; ERRORS=M`.
- `Evidência direta`: `scripts/Invoke-PrePushMechanicalChecks.ps1` passou a emitir aviso específico quando o intervalo altera scripts, skills, checklists ou documentos metodologicos que podem exigir atualizacao de `09-inventario-e-rastreabilidade-publica.md`; o aviso explicita que encontrar o termo no `09` não basta, sendo necessário comparar se a descrição ainda reflete a abrangencia atual do contrato.
- `Evidência direta`: `scripts/Test-PrePushTraceabilityCoverage.ps1` foi incorporado como gate consultivo de cobertura de rastreabilidade editorial na rotina pre-push, detectando riscos objetivos como regra de `AGENTS.md`/`13-revisao-pre-push.md` não espelhada em `08-guia-para-agente-gpt.md`, script compartilhado sem mencao nominal no `09`, token rastreavel ausente no `09`, paridade assimétrica Build/Query de catalogo (`ParallelKbRoot`, override), cobertura agregada demais entre motor e bateria de teste e referencia documental a versão antiga do extrator quando `Build-KbIntelligenceIndex.py` muda `EXTRACTOR_SIGNATURE_VERSION`.
- `Evidência direta`: `scripts/Test-GeneXusUnexpectedCharacter.ps1` foi incorporado como gate consultivo da rotina pre-push para detectar caracteres Unicode inesperados em linhas adicionadas de `.md` e `.ps1` fora de `historico/`; o gate preserva número real da linha nova no diff, ignora linhas dentro de blocos fenced Markdown a partir do arquivo atual completo e sempre reporta findings como revisao humana, não como substituto da fase semantica.
- `Evidência direta`: `scripts/Test-PrePushNewTokenPropagation.ps1` foi incorporado como gate consultivo da rotina pre-push para apoiar a regra simétrica do passo 2 de `13-revisao-pre-push.md`: detecta no diff `BaseRef..HEAD` termo de contrato introduzido por transição co-localizada (ex.: `- ...-ObjectNames`/`-ObjectGuids` -> `+ ...-ObjectList, -ObjectNames`/`-ObjectGuids`), filtra pares por morfema comum (prefixo ou sufixo >= 4), ignora variável `$Token` de código e declaração do próprio parâmetro, e lista menções do repositório que ficaram com o termo antigo sem o novo; findings entram em `agentWarnings` como candidatas a confrontar, nunca como veredito, e o gate não dispara sem transição co-localizada no mesmo hunk. Verificação por `scripts/Test-PrePushNewTokenPropagationSelfTest.ps1` (caso positivo da menção defasada, controle negativo já propagado, exclusão de declaração e de variável de código; sentinela `OK: Test-PrePushNewTokenPropagationSelfTest.ps1`).
- `Evidência direta`: `scripts/Test-PrePushSharedScriptSkillCoverage.ps1` foi incorporado como gate consultivo da rotina pre-push para a comparação documental do passo 3 de `13-revisao-pre-push.md`: quando o intervalo `BaseRef..HEAD` altera script compartilhado (`scripts/*.ps1`/`*.py`), procura o nome base do script em todos os `SKILL.md` e `quality-checklist.md` (fora de `historico/`) e lista os que citam o script e não estão no diff (skill transversal) como candidatas em `agentWarnings`; severity `warn`, com teto de candidatas, sem falhar o gate mecânico. Cobre o caso de wrapper documentado em mais de uma skill (ex.: `Invoke-GeneXusXpzImportThenBuild` em `xpz-msbuild-build/SKILL.md` e `xpz-msbuild-import-export/SKILL.md`). Verificação por `scripts/Test-PrePushSharedScriptSkillCoverageSelfTest.ps1` (candidata para skill e quality-checklist transversais fora do diff, exclusão da skill dona tocada e da skill que não cita o script; sentinela `OK: Test-PrePushSharedScriptSkillCoverageSelfTest.ps1`).
- `Evidência direta`: `scripts/Test-PrePushHistoryCommitPlaceholder.ps1` foi incorporado como gate consultivo da rotina pre-push para o checklist de gaps de `13-revisao-pre-push.md`: quando o intervalo `BaseRef..HEAD` toca `historico/*.md`, sinaliza campo de rastreabilidade `Commit:`/`PR:` com placeholder genérico (`este commit`, `este PR`, `TODO`, `TBD`, vazio ou `<...>`) em vez do hash real, conforme a convenção `` - Commit: `hash` (`mensagem`) `` do histórico; severity `warn`, escopo diff, sem falhar o gate mecânico. A exceção legítima (hash a preencher no commit seguinte) é confirmada pelo agente, não reprovada pelo gate. Verificação por `scripts/Test-PrePushHistoryCommitPlaceholderSelfTest.ps1` (candidata para placeholder em histórico no diff, exclusão de hash real, de histórico fora do diff e de arquivo fora de `historico/`; sentinela `OK: Test-PrePushHistoryCommitPlaceholderSelfTest.ps1`).
- `Evidência direta`: `scripts/Test-PrePushGateEnumerationParity.ps1` foi incorporado como gate consultivo da rotina pre-push para fechar a causa-raiz de um gap real (enumeração de gates defasada que três revisões perderam): deriva do orquestrador (`scripts/Invoke-PrePushMechanicalChecks.ps1`) o conjunto de gates realmente executados — exceto os gates de parse `Test-*ScriptsParse.ps1`, que são par mecânico fixo — e varre os `.md` da raiz sinalizando qualquer linha que enumere ≥ 2 desses gates como subconjunto próprio (afirmação fechada que ficou com o conjunto antigo). Severity `warn`, invariante (não diff-scoped), com teto, sem falhar o gate mecânico. Verificação por `scripts/Test-PrePushGateEnumerationParitySelfTest.ps1` (candidata para enumeração parcial de gates semânticos, exclusão do par de parse co-citado e de enumeração completa; sentinela `OK: Test-PrePushGateEnumerationParitySelfTest.ps1`).
- `Evidência direta`: `scripts/Test-XpzSetupAudit.ps1` passou a consolidar a dimensao `declarativo/timestamps`, detectando `DRIFT_TIMESTAMPS_LITERAIS` quando `AGENTS.md` ou `README.md` locais da pasta paralela gravam timestamps literais de materializacao/indice; essa verificacao materializa a regra operacional de `02-regras-operacionais-e-runtime.md` e o contrato de handoff da skill `xpz-kb-parallel-setup`. O mesmo orquestrador passou a tratar `INVENTORY_LEGACY_ORPHANS` como pendencia metodologica que rebaixa o estado operacional sugerido para `atualizacao_metodologica_pendente`.
- `Evidência direta`: `scripts/Get-XpzSetupContractSignature.ps1` calcula a assinatura deterministica da superficie de contrato declarada em `xpz-kb-parallel-setup/setup-contract.manifest.json`; `scripts/Test-XpzSetupFreshness.ps1` compara essa assinatura com `setup_contract_signature_*` auditado em `kb-source-metadata.md`, em vez de comparar contra a data do último commit do repositório inteiro; `scripts/Test-XpzSetupContractSignatureSelfTest.ps1` valida migracao conservadora, `GATE_ONLY` após gravacao, mudanca fora da superficie assinada sem auditoria e mudanca dentro da superficie com `AUDIT_REQUIRED`; sentinela `XPZ_SETUP_CONTRACT_SIGNATURE_SELFTEST_OK`.
- `Evidência direta`: `scripts/Set-XpzSetupAuditTimestamp.ps1` grava ou atualiza somente `last_setup_audit_run_at` e `setup_contract_signature_*` em `kb-source-metadata.md` da pasta paralela, preservando demais campos, EOL dominante e newline final via `scripts/XpzTextFileEolSupport.ps1`; molde `xpz-kb-parallel-setup/examples/Set-KbSetupAuditTimestamp.example.ps1`; complementa `scripts/Test-XpzSetupFreshness.ps1` após auditoria de setup bem-sucedida; `scripts/Test-XpzSetupAuditTimestampEolSelfTest.ps1` valida que fixture LF permanece sem CR após update e insert; sentinela `XPZ_SETUP_AUDIT_TIMESTAMP_EOL_SELFTEST_OK`.
- `Evidência direta`: `scripts/Utf8NoBomEncodingSupport.ps1` centraliza `Get-Utf8NoBomEncoding` para escrita simples em UTF-8 sem BOM; scripts novos em `scripts/*.ps1` devem reutilizar esse suporte em vez de duplicar construtores `[System.Text.UTF8Encoding]::new($false)` ou `New-Object System.Text.UTF8Encoding($false)`, exceto nos casos de leitura/deteccao de encoding, BOM deliberado ou validação estrita de bytes.
- `Evidência direta`: `scripts/XpzTextFileEolSupport.ps1` centraliza leitura/escrita de arquivos de texto versionados preservando EOL dominante e newline final; consumido por motores que mutam `kb-source-metadata.md` sem reescrever com `Environment.NewLine` no Windows.
- `Evidência direta`: `scripts/XpzKbSourceMetadataEditSupport.ps1` concentra `Update-XpzKbSourceMetadataFromSync` (mutacao cirurgica de `kb-source-metadata.md` sob autoridade do `xpz-sync`, preservando `last_setup_audit_run_at`, `setup_contract_signature_*` e frontmatter fora do escopo); invocado por `scripts/Sync-GeneXusXpzToXml.ps1` quando `-KbMetadataPath` está ativo; `scripts/Test-XpzSyncKbMetadataSelfTest.ps1` valida preservacao de carimbo de setup, frontmatter futuro e EOL LF após refresh; sentinela `XPZ_SYNC_KB_METADATA_SELFTEST_OK`.
- `Evidência direta`: `scripts/Measure-PtBrAccentDegradation.ps1` foi incorporado como medidor determinístico e reusável da degradação de acentuação pt-BR (forma ASCII onde caberia caractere acentuado) nos arquivos versionados; enumera via `git ls-files`, separa piso firme (lista curada de palavras inequívocas) de ambíguas marcadas como teto solto, suprime código fenced/inline e identificadores em `.md` e mede só comentários em `.ps1`/`.example.ps1`, segmentando a saída e excluindo `historico/` e aportes de terceiros do total de trabalho pendente; grava mapa transitório em `work/ptbr-accent-map.{md,json}` (git-ignored, regenerável). Lista curada em `scripts/ptbr-accent-wordlist.json` (critério de inclusão e exclusões documentados); verificação por `scripts/Test-MeasurePtBrAccentDegradationSelfTest.ps1` com golden files (supressão de fenced/inline/slug, `.ps1` só comentários, arquivo já corrigido e integridade da lista); sentinela `PTBR_ACCENT_MEASURE_SELFTEST_OK`. Baseline atual registrada em `999-ideias-pendentes.md`.
- `Evidência direta`: `scripts/Repair-PtBrAccentDegradation.ps1` é a contraparte aplicadora do medidor — corrige só as ocorrências inequívocas (palavras da lista curada cuja forma sem acento é sempre erro) nos arquivos indicados, reusando lista, regex, supressão de código e preservação de caixa do detector via dot-source; preserva EOL LF e UTF-8 sem BOM. Dispatch por extensão: em `.md` respeita a fronteira pt-BR (`Get-PtBrLineCount`, não toca `## Español`/`## English`) e suprime cercas/code inline; em `.ps1`/`.example.ps1` corrige **somente comentários**, isolados pelo tokenizer do PowerShell (tokens `Comment`, offset exato) — nunca toca código nem strings (mais seguro que o split-por-`#` do detector ao medir: `#` dentro de string não é corrigido, divergência deliberada). Tokens ambíguos e cópula geral ficam fora por construção (decisão humana). Verificação por `scripts/Test-RepairPtBrAccentDegradationSelfTest.ps1` (golden `.md` e `.ps1`: comentário corrigido com string-com-`#` e código intactos, idempotência, faixa pt-BR e caixa); sentinela `PTBR_ACCENT_REPAIR_SELFTEST_OK`. Usado na frente de correção de acentuação registrada no `999-ideias-pendentes.md`.
- `Evidência direta`: `xpz-kb-parallel-setup/SKILL.md` exige **plano consolidado de correcoes** após toda auditoria mínima (incluindo PRE-CONDICAO do gatilho global e `auditar_setup`), com oferta de execução na mesma sessao de tudo que a skill classificar como corrigivel na pasta; diagnostico isolado não basta quando houver item corrigivel.
- `Evidência direta`: `scripts/GeneXusObjectTypeCatalogCore.py` centraliza carga e merge do catalogo efetivo (base + override) para build e query.
- `Evidência direta`: `scripts/Query-KbIntelligenceIndex.py` bloqueia consultas semanticas (`who-uses`, `what-uses`, `impact-basic`, `functional-trace-basic`) quando `queryableByKbIntelligence=false` no **catalogo efetivo** (`--parallel-kb-root`, `--catalog-override-path`; `blocked`, `reason=QUERY_NOT_SEMANTIC_FOR_TYPE`, exit `11`); lista canônica no JSON (2026-05-30: acrescentados tipos com Part e grafo zero, ex. `Image`, `Theme`, `SubTypeGroup`); tipos com grafo assimétrico documentados em `scripts/README-kb-intelligence.md` (`API`, `DataSelector`, `WorkWithForWeb`, `ExternalObject`); bateria `scripts/Test-KbIntelligenceQueryableGuardSelfTest.ps1` (base e override); amostra multi-KB `scripts/Invoke-ParallelKbEnvelopeScan.ps1`.
- `Evidência direta`: `scripts/GeneXusPythonPrerequisite.ps1` resolve Python 3 utilizavel (rejeita stub `WindowsApps`); `scripts/Build-KbIntelligenceIndex.ps1` retorna exit `8` e mensagem `PREREQUISITO AUSENTE` quando ausente e propaga saida do `.py` em falha; consequência editorial: sync XPZ/XML oficial **não** conclui sem índice — declarar **fluxo incompleto** (materialização pode ter concluido), não sync OK; ver `README.md`, `08`, `xpz-sync` e molde `Update-KbFromXpz.example.ps1`.
- `Evidência direta`: `scripts/Build-KbIntelligenceIndex.py` mescla `gx-object-type-catalog.json` com override local (`--catalog-override-path` ou `--parallel-kb-root` / deteccao a partir de `ObjetosDaKbEmXml`), alinhado a `GeneXusObjectTypeCatalogSupport.ps1`.
- `Evidência direta`: `scripts/Build-KbIntelligenceIndex.py` grava `extractor_signature_version` e `extractor_signature_hash` (SHA-256 do próprio motor) na tabela `metadata`; `scripts/GeneXusKbIntelligenceExtractorContract.ps1` compara com o motor do repositório ativo; `scripts/Test-GeneXusKbIntelligenceExtractorSignatureSelfTest.ps1` (sentinela `KB_INTELLIGENCE_EXTRACTOR_SIGNATURE_SELFTEST_OK`); molde `xpz-kb-parallel-setup/examples/Test-KbIndexGate.example.ps1` bloqueia índice sem assinatura ou com extrator defasado mesmo quando timestamps parecem frescos.
- `Evidência direta`: `scripts/Build-KbIntelligenceIndex.py` foi ampliado para extrair criacao de WebComponent por `<WebPanel>.Create(...)` em `Source` efetivo de `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `API` e `DataSelector`, registrando relacao `creates_webcomponent` com regra `webpanel_dot_create`; a cobertura operacional está documentada em `scripts/README-kb-intelligence.md` e na bateria `scripts/kb-intelligence-fabricabrasil.validation-extraction-webcomponent-create.json`.
- `Evidência direta`: `scripts/Build-KbIntelligenceIndex.py` extrai chamadas resolviveis em `Property Formula` de `Attribute` para `Procedure`, `WebPanel` e `DataProvider` (regras `attribute_formula_procedure_direct_call` e `attribute_formula_procedure_dot_call`; cobertura introduzida na assinatura do extrator `3` e preservada no extrator atual `6`); `who-uses` em `Procedure` passa a incluir esse uso; self-test `scripts/Test-KbIntelligenceAttributeFormulaExtractionSelfTest.ps1`; baterias dedicadas `scripts/kb-intelligence-fabricabrasil.validation-extraction-attribute-formula.json` e `scripts/kb-intelligence-wseducacaospteste.validation-extraction-attribute-formula.json`; notas em `scripts/gx-object-type-catalog.json` e `scripts/README-kb-intelligence.md`.
- `Evidência direta`: `scripts/Build-KbIntelligenceIndex.py` extrai chamada efetiva de método em variável `exo:<ExternalObject>` no `Source` efetivo de `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `API` e `DataSelector`, registrando relacao `calls_external_object_method` com regra `source_external_object_method`; cobertura introduzida na assinatura do extrator `5`; self-test `scripts/Test-KbIntelligenceExternalObjectMethodExtractionSelfTest.ps1` cobre uso efetivo e protecao contra falso positivo de substring em chamada direta de `Procedure`.
- `Evidência direta`: `scripts/GeneXusTransactionWritabilityCore.py` concentra a classificação canonica de gravabilidade por `Transaction`/`Level`/`Attribute` (`writability_rule_version=1`); `scripts/Build-KbIntelligenceIndex.py` materializa o resultado em `transaction_attribute_writability` (`schema_version=3`, extrator atual `6`); consultas `transaction-attributes` e `transaction-writable-attributes` em `scripts/Query-KbIntelligenceIndex.py` leem a tabela materializada.
- `Evidência direta`: `scripts/Build-KbIntelligenceIndex.py` cataloga classes CSS na tabela `css_class` (camada 1: `model` `legacy-theme` de `ThemeClass` via propriedade `Name` / `design-system` de SCSS no Part Styles `c6b14574-...` de `DesignSystem` e `PackagedModule`; `origin` `kb-authored`/`packaged-module`; `UNIQUE(model, class_name, defining_object_name)`) e materializa uso (camada 2: relacoes `uses_css_class`/`uses_css_class_dynamic` em `relations`/`evidence`, `evidence_role` `css_layout`/`css_event`/`css_dynamic`, vetores de layout `class`/`cellClass`/`rowClass`/`formClass`) — bump `schema_version` `2`→`3` e `EXTRACTOR_SIGNATURE_VERSION` `5`→`6`; consultas `css-classes` e `css-class-usage` em `scripts/Query-KbIntelligenceIndex.py` (e wrapper `.ps1` com `-Model`/`-Origin`/`-IncludeImported`). Self-test `scripts/Test-KbIntelligenceCssClassExtractionSelfTest.ps1` cobre as 7 formas de uso, caso `:hover` (Name vs stem), heranca, dedup `@media`, comentarios `//` e `/* */`, `PackagedModule` e classe usada-mas-nao-catalogada; sentinela `OK: Test-KbIntelligenceCssClassExtractionSelfTest.ps1`.
- `Evidência direta`: `scripts/GeneXusTransactionWritabilitySupport.ps1` invoca o nucleo Python; `scripts/Test-GeneXusTransactionWritability.ps1` e `scripts/Test-GeneXusNewWritableTargets.ps1` são fachadas PowerShell (sem algoritmo duplicado); paridade índice↔gate via `scripts/Test-GeneXusKbIntelligenceWritabilityParity.ps1`; bateria de consulta `scripts/kb-intelligence-wseducacaospteste.validation-queries-writability.json`.
- `Evidência direta`: `scripts/Read-MsBuildImportSignals.ps1` foi ampliado como leitor compacto de sinais de importação MSBuild, preservando itens crus (`expectedItemsRaw`/`importedItemsRaw`), emitindo itens canonicos (`expectedItemsCanonical`/`importedItemsCanonical`), registrando equivalencias em `itemAliasMatches` e sinalizando leitura degradada de `GxImport.log` por `gxImportLogReadStatus`/`gxImportLogReadError`.
- `Evidência direta`: `scripts/Test-MsBuildImportSignalsClassifier.ps1` foi incorporado como bateria mínima de validação do leitor compacto, cobrindo ruido conhecido de `CssProperties.json`, lock de `GxImport.log` e equivalencia `Panel`/`SDPanel` em `itemAliasMatches`.
- `Evidência direta`: `scripts/Test-GeneXusXpzImportPreview.ps1` e `scripts/Invoke-GeneXusXpzImport.ps1` gravam `msbuild.import.signals.json` ao lado dos logs brutos quando `Read-MsBuildImportSignals.ps1` consegue executar e também embutem o objeto parseado no diagnostico JSON em `compactSignals`; falha nessa gravacao ou leitura degrada o diagnostico (`diagnosticDegraded`), mas não reclassifica a task Import como falha operacional quando `executionEvidence.msBuildExitCode` e stdout sustentam conclusao.
- `Evidência direta`: a skill `xpz-llm-delegate` incorporou cinco scripts em `scripts/`: `Invoke-OpenCode.ps1` (chamada sincrona ao opencode), `Start-OpenCodeJob.ps1` (disparo assincrono nao-bloqueante) e `Watch-OpenCodeJob.ps1` (monitor incremental do job) como backend opencode; e os de nucleo backend-agnostico `Resolve-OpenCodeModelLocality.ps1` (classifica `local`/`external`/`unknown` pelo `baseURL` do provider na config do opencode) e `Resolve-LlmDelegateAuthorization.ps1` (gate de confidencialidade `allow`/`ask`/`deny` combinando `payloadSensitivity` `kb-sensitive`/`public`, localidade e politica por-KB `opencode-delegation-policy.json`). Contrato em `xpz-llm-delegate/SKILL.md`; acionamento sempre humano; juizo estrutural GeneXus nunca e delegado.
- `Evidência direta`: o parsing do stream do opencode foi extraido para o motor compartilhado `scripts/OpenCodeStreamSupport.ps1` (`ConvertFrom-OpenCodeStreamLines`, `Get-OpenCodeStreamErrorMessage`, `Get-OpenCodeTextParts`, `Get-OpenCodeFinalText`, `Get-OpenCodeAllText`), consumido por `Invoke-OpenCode.ps1` e `Watch-OpenCodeJob.ps1` (resposta final = concatenacao das partes da última mensagem; surfacing de erro do stream como BLOCK/`status:error`). Self-tests deterministicos (sem opencode/rede): `scripts/Test-OpenCodeStreamSupportSelfTest.ps1` (sentinela `OK: Test-OpenCodeStreamSupportSelfTest.ps1`), `scripts/Test-OpenCodeModelLocalitySelfTest.ps1` (sentinela `OK: Test-OpenCodeModelLocalitySelfTest.ps1`) e `scripts/Test-LlmDelegateAuthorizationSelfTest.ps1` (sentinela `OK: Test-LlmDelegateAuthorizationSelfTest.ps1`).

- `Evidência direta`: a skill `xpz-skills-setup` incorporou scripts de setup e auditoria em `scripts/`. Bootstrap de repositório: `Initialize-XpzSkillsRepoGit.ps1` liga pasta baixada como ZIP ao remoto oficial (`git init` + `remote` + `fetch` + `reset --mixed origin/main`), instala Git por `winget` quando ausente e tem gate anti-destrutivo (`GIT_LINKED_WITH_DRIFT` só alinha o working tree via `-AlignToOfficial`); self-test `Test-XpzSkillsRepoGitSelfTest.ps1`. Auditoria de registro: `Test-XpzSkillsRegistration.ps1` (somente leitura) classifica cada skill x ferramenta em `OK`/`coberta_por_compatibilidade`/`ausente`/`orfa`/`quebrada`, detecta orfas e o freshness do MCP global do Cursor por hash (`MCP_OK`/`MCP_SERVER_STALE`/`MCP_CONFIG_INVALID`/`MCP_NOT_INSTALLED`); `overall` `REGISTRATION_OK`/`REGISTRATION_GAPS`; self-test `Test-XpzSkillsRegistrationSelfTest.ps1`. Auditoria de instrucionais globais: `Test-XpzGlobalInstructions.ps1` + contrato `xpz-global-instructions-topics.psd1` resolve a fonte efetiva por ferramenta (segue `@<caminho>`, `instructions[]` do OpenCode e o `agentsPath` do MCP do Cursor) e sinaliza a cobertura dos topicos minimos de forma conservadora (`presente`/`nao_detectado`); `overall` `GLOBAL_INSTRUCTIONS_OK`/`GLOBAL_INSTRUCTIONS_REVIEW`; self-test `Test-XpzGlobalInstructionsSelfTest.ps1` cobre deteccao e paridade contrato↔`SKILL.md`. Instalador do MCP global do Cursor (frente anterior da mesma skill): `Install-CursorGlobalInstructionsMcp.ps1` + `cursor-global-instructions-mcp/server.py` (servidor MCP stdio que serve o `AGENTS.md` efetivo ao Cursor, com merge em `mcp.json` preservando outros servidores). Skill externa gerenciada (`nexa`): `Initialize-NexaRepoGit.ps1` faz o bootstrap do repositório que hospeda a `nexa` (`genexuslabs/genexus-skills`), com deteccao do clone existente via vinculo global, clone quando ausente (capacidade que o bootstrap XPZ proibe de proposito), origin oficial tolerando remotos extras (ex.: `fork`) e gate `NEXA_DIR_NOT_REPO` anti-sobrescrita (labels `NEXA_ALREADY_LINKED`/`NEXA_ORIGIN_ADDED`/`NEXA_REPO_CLONED`/`NEXA_REMOTE_MISMATCH`); self-test `Test-NexaRepoGitSelfTest.ps1`. O motor `Test-XpzSkillsRegistration.ps1` foi estendido para classificar também a `nexa` em seção separada (`externalSkills`/`externalOverall` `EXTERNAL_SKILLS_OK`/`EXTERNAL_SKILLS_GAPS`, independente de `overall`), só a `nexa` por nome — demais skills do repo externo (ex.: `gx-sap`) ficam dormentes. Contrato em `xpz-skills-setup/SKILL.md`; os motores não criam/removem vinculos nem gravam instrucionais — as ações de resolucao são manuais, sob confirmacao explicita.

## Nota sobre a skill experimental de MSBuild

- `Evidência direta`: a skill `xpz-msbuild-import-export` passou a existir na raiz como contrato materializado em `xpz-msbuild-import-export/SKILL.md`.
- `Evidência direta`: essa skill permanece experimental e, nesta fase, já inclui a implementação inicial de `scripts/Test-GeneXusMsBuildSetup.ps1` como probe não invasivo de ambiente; a descoberta de `MSBuild.exe` delega ao contrato compartilhado `scripts/GeneXusMsBuildPathContract.ps1` (`vswhere` + catalogo estatico VS 18/2022/2019) e expoe `msBuildProbe` no JSON; regressao do catalogo em `scripts/Test-GeneXusMsBuildDiscoveryContract.ps1`.
- `Evidência direta`: `scripts/Test-PrePushMsBuildProbeDocParity.ps1` e gate mecanico da rotina pre-push (via `scripts/Invoke-PrePushMechanicalChecks.ps1`) para a frente MSBuild probe: paridade dos exemplos JSON em `10-base-operacional-msbuild-headless.md`, superficies doc (`10-base`, `xpz-msbuild-import-export/SKILL.md`) e inventario da skill quando o motor/probe mudam no intervalo; falha mecanica bloqueia o passo pre-push, aviso de frase legada no diff não bloqueia sozinho.
- `Evidência direta`: essa skill também já inclui a implementação inicial de `scripts/Open-GeneXusKbHeadless.ps1` para abertura e fechamento controlados da KB com captura de contexto.
- `Evidência direta`: essa skill também já inclui a implementação inicial de `scripts/Test-GeneXusXpzImportPreview.ps1` para `PreviewMode` de importação sem alteracao real da KB, validada nesta conversa com `XPZ` real.
- `Evidência direta`: essa skill também já inclui a implementação inicial de `scripts/Invoke-GeneXusXpzExport.ps1` para exportação headless de `XPZ` com parâmetros explicitos.
- `Evidência direta`: em exportação seletiva/cirurgica por MSBuild, a combinacao `DependencyType="None"` e `ReferenceType="None"` foi validada como prevencao de arrasto quando o objetivo e obter somente os itens de `Objects`/`ObjectList`; omitir esses parâmetros já produziu pacote com objetos extras e atributos top-level em caso real (`FabricaBrasil18`). A regra operacional em `02`, `08`, `10-base`, `README.md`, `xpz-msbuild-import-export/SKILL.md` e `scripts/Invoke-GeneXusXpzExport.ps1` exige `None`/`None` para pacote nominal, sem dispensar inventario pos-export.
- `Evidência direta`: essa skill também já inclui a implementação inicial de `scripts/Invoke-GeneXusXpzImport.ps1` para importação real de `XPZ` com parâmetros explicitos.
- `Evidência direta`: wrappers das familias `xpz-msbuild-build` e `xpz-msbuild-import-export` que executam build/import/export/preview (`Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1` e `Invoke-GeneXusXpzImport.ps1`) passaram a registrar o enriquecimento preventivo de `PATH` em `observedContext.pathEnrichment`, com `applied`, `subdirsAdded` e `subdirsSkipped`.
- `Evidência direta`: os scripts de environment/deploy têm papéis distintos em `kb-source-metadata.md`: `scripts/GeneXusKbEnvironmentInventorySupport.ps1` e `scripts/Get-GeneXusKbEnvironmentNames.ps1` validam via MSBuild os nomes declarados e retornam `kb_environment_names`/`kb_environment_count`; `scripts/Set-XpzKbSourceMetadataDeployment.ps1` grava `deployment_environment_name`, `deployment_hosting_kind`, `kb_environment_count`, `kb_environment_names`, `kb_environment_output_dirs` e `kb_environment_web_dirs` (setup: `-KbEnvironmentNames` e `-KbEnvironmentOutputDirs` declarados pelo usuário + validação MSBuild obrigatória via `SetActiveEnvironment` headless; scan automático por pastas removido); `scripts/GeneXusKbDeploymentEnvironmentSupport.ps1` le e valida esses campos; `scripts/Resolve-GeneXusGeneratedCsPath.ps1` consome `kb_environment_web_dirs` para resolver `.cs` gerado e bloqueia quando o mapeamento não cobre o environment; `scripts/Test-ResolveGeneXusGeneratedCsPathSelfTest.ps1` cobre esse resolvedor (sentinela `RESOLVE_GENEXUS_GENERATED_CS_PATH_SELFTEST_OK`). Inventario validado emite `KB_ENVIRONMENT_INVENTORY_OK`; `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` bloqueiam (exit 46, causa `environment-validacao-indefinido`) quando KB multi-environment sem environment de validação resolvido; JSON inclui `deploymentEnvironmentContext` e warning se `ActiveEnvironment` divergir do environment de validação.
- `Evidência direta`: `scripts/Test-XpzKbMetadataWrapper.ps1` compara o output do wrapper local `Test-*KbMetadataWrapper.ps1` (em `xpz-kb-parallel-setup`) com `kb-source-metadata.md`; valida campos obrigatórios (`last_xpz_materialization_run_at`, `kb_name`, `source_guid`) e campos opcionais de environment/deploy/output (`deployment_environment_name`, `deployment_hosting_kind`, `kb_environment_count`, `kb_environment_names`, `kb_environment_output_dirs`, `kb_environment_web_dirs`) quando presentes no metadata; classifica `OK`, `PENDENTE_DE_DADOS`, `PENDENTE` ou `BLOCK`, consumido por `scripts/Test-XpzSetupAudit.ps1` para alimentar as linhas `metadata wrapper:` e `metadata/deploy:` do relatório de auditoria.
- `Evidência direta`: `scripts/GeneXusKbDeployBinSupport.ps1` e `scripts/Test-GeneXusDeployBinFreshness.ps1` checam publicacao no `web\bin` resolvido por `kb_environment_web_dirs` para o environment de deploy pos-build (max DLL de objeto excluindo runtime GeneXus/System/Microsoft, ou `*.config`; `GxNetCoreStartup.dll` só complementar em Core); a decisão de rodar o gate vem de **sucesso operacional factual** (`-BuildOperationallySucceeded`: MSBuild exit 0 + marcador de conclusão do build), **não** da string de status, de modo que rebaixamento benigno (evento pós-build, ruído em stderr) não suprime `-PostImportDeployValidation`; `Test-GeneXusDeployBinFreshness.ps1` aceita `-BuildResultJsonPath` para derivar a linha de corte de `timing.msbuildStart` do build (`-BuildStartedAt` opcional, explícito prevalece; `buildStartedAtSource` `parameter`|`build-json` no resultado). `-PostImportDeployValidation` / `-StrictDeployBinCheck` ativam gate (exit **49**); status `compilou-mas-dll-destino-desatualizada`; campos `deployBinFreshness`, `deployBinCheck`, `publicationFreshSinceBuild`, `objectDllMaxWriteTime` e `configMaxWriteTime` no JSON dos wrappers de build. Self-tests: `scripts/Test-GeneXusDeployBinFreshnessSelfTest.ps1` (resolução de `web\bin` por metadata; sentinela `GENEXUS_DEPLOY_BIN_FRESHNESS_SELFTEST_OK`), `scripts/Test-GeneXusDeployBinPolicySelfTest.ps1` (decisão do gate por sucesso operacional; sentinela `GENEXUS_DEPLOY_BIN_POLICY_SELFTEST_OK`) e `scripts/Test-GeneXusDeployBinFreshnessBuildStartedAtSelfTest.ps1` (resolução de `-BuildStartedAt`; sentinela `GENEXUS_DEPLOY_BIN_FRESHNESS_BUILDSTARTEDAT_SELFTEST_OK`).
- `Evidência direta`: `scripts/GeneXusMsBuildWatcherSupport.ps1` centraliza o contrato comum de watcher dos wrappers MSBuild (`-StartWatcher`, `-MonitorLogPath`, `watcherContext` e `timing.phases`), e os wrappers de build, specify/generate, preview/import e export passam a compartilhar essa base.
- `Evidência direta`: `scripts/Start-GeneXusKbBuildDetached.ps1` (skill `xpz-msbuild-build`) é o orquestrador **opt-in** do modo desacoplado de build longo: registra uma Tarefa Agendada one-shot (console **oculto**, `-WindowStyle Hidden`) que executa `Invoke-GeneXusKbBuildAll.ps1` fora da sessão do agente (sob `svchost` do Scheduler — sobrevive a fechar janela/app, validado empiricamente na FabricaBrasil18) e sinaliza a conclusão por arquivo-sentinela (`{ done, exitCode, logPath, logExists, error, stdoutPath, stderrPath, finishedAt }`, escrita atômica `.tmp`+rename; `logExists`/`error` distinguem conclusão do wrapper de falha antes de escrever o log). Repassa os parâmetros ao wrapper por **hashtable splatting** (array splatting desalinha o binding). Não altera o wrapper de build (apenas o invoca) e é transporte, não autoridade de política — os gates de reorg/rebuild/opções caras permanecem no wrapper; modo desacoplado v1 não usa watcher (`timing.phases` vazio). Self-test: `scripts/Test-StartGeneXusKbBuildDetachedContract.ps1`. Contrato e fluxo em `xpz-msbuild-build/SKILL.md`; exit codes próprios (0, 46, 90) em `scripts/msbuild-exit-codes.catalog.json`.
- `Evidência direta`: wrappers MSBuild headless passaram a separar causas acionaveis em `blockingReasons` da evidencia bruta de execução em `executionEvidence`; `msBuildExitCode` top-level, quando mantido, é compatibilidade transitoria e deve duplicar `executionEvidence.msBuildExitCode`. Escopo inclui as famílias `xpz-msbuild-build` e `xpz-msbuild-import-export`, `scripts/Open-GeneXusKbHeadless.ps1`, `scripts/Get-GeneXusKbProperty.ps1` e também `scripts/Test-GeneXusKbConsistency.ps1`, que emite `executionEvidence` via `New-ExecutionEvidence`.
- `Evidência direta`: `scripts/Invoke-GeneXusXpzExport.ps1` pode emitir `postProcessingFailed` / `postProcessingError` quando a exportação MSBuild concluiu e a evidência primária do log bruto aponta XPZ gerado, mas o pós-processamento local do wrapper falhou ao montar ou serializar o diagnóstico; nesse caso, a rodada não deve ser reclassificada automaticamente como falha operacional.
- `Evidência direta`: `scripts/Invoke-GeneXusXpzImport.ps1` e `scripts/Test-GeneXusXpzImportPreview.ps1` passaram a emitir `diagnosticDegraded` (booleano) e `diagnosticDegradedReason` (string) no diagnóstico JSON quando o pós-processamento local do wrapper ficou parcial ou falhou após o MSBuild concluir. O campo **não** reclassifica a task MSBuild; a evidência primária permanece em `executionEvidence` e nos marcadores do log bruto. Contrato completo em `xpz-msbuild-import-export/SKILL.md`; definição operacional em `10-base-operacional-msbuild-headless.md`.
- `Regra operacional`: contrato **Decisão pós-gates** em `xpz-msbuild-import-export/SKILL.md` (espelhado em `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md` e `10-base-operacional-msbuild-headless.md`): com importação real já autorizada na sessão, `Test-GeneXusImportFileEnvelope.ps1` → `apto para prosseguir` e inventário do pacote (passo 6c da skill) sem bloqueio de extras, o agente deve executar `Invoke-GeneXusXpzImport.ps1` na mesma rodada com `-StartWatcher` e `-MonitorLogPath`; `Test-GeneXusXpzImportPreview.ps1` não é obrigatório nesse caminho — preview permanece para rodada exploratória ou quando import real ainda não foi autorizado. Autorização de import na sessão não cobre extras não conciliados, módulos/ExternalObjects de plataforma não pedidos nem `attributesTopLevelUnreconciled` em pacote cirúrgico (**ABORT** e listar pacote completo ao usuário); **`exitCode=48`** (Categoria B: rejeição MSBuild no log de export/import/preview upstream) **bloqueia** import real na mesma rodada, mesmo com autorização de import na sessão; anti-padrões nomeados na skill: **parada após envelope apto** e **reempacotar lixo de export**.
- `Inferência forte`: as baterias `KB_Teste_*` documentadas abaixo validaram o mecanismo experimental export → preview → import real dos wrappers; essa sequência não substitui a orquestração por sessão da **Decisão pós-gates** quando o usuário já autorizou import real e os gates de envelope/inventário passaram sem bloqueio.
- `Evidência direta`: `Open-GeneXusKbHeadless.ps1` foi validado com uma KB de teste sanitizada (`KB_Teste_A`), com `EnvironmentName=NETSQLServer`.
- `Evidência direta`: `Test-GeneXusXpzImportPreview.ps1` foi validado com um `XPZ` full exportado nessa mesma KB sanitizada.
- `Evidência direta`: o `PreviewMode` executado nessa validação não alterou a KB.
- `Evidência direta`: `Invoke-GeneXusXpzImport.ps1` foi validado com o `XPZ` exportado nesta frente e concluiu com sucesso operacional, embora tenha produzido mensagens de stderr no log.
- `Evidência direta`: uma nova rodada de importação real com a KB fechada manteve o mesmo padrão de `stderr`, incluindo as mensagens de `mismatched input ']' expecting 'default'` e o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json`, sem impedir `exitCode = 0`.
- `Evidência direta`: na instalacao validada nesta conversa, `IncludeItems` e `ExcludeItems` funcionaram em `PreviewMode`, enquanto `UpdateFile` e `ImportKBInformation` ficaram bloqueados por ausencia de propriedade publica correspondente na task `Import` carregada.
- `Evidência direta`: os wrappers de preview e importação real passaram a normalizar recortes múltiplos de `IncludeItems` e `ExcludeItems`, com serializacao em formato de lista aceito operacionalmente pela task carregada.
- `Evidência direta`: depois dessa normalizacao, recortes combinados passaram a funcionar de forma confiavel e permitiram reduzir o ruido lateral sem alterar o `exitCode = 0` da importação real.
- `Evidência direta`: na bateria de recortes desta frente, o acesso negado a `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json` deixou de ficar restrito a um conjunto pequeno de objetos da `KB_Teste_A` e reapareceu também em `Procedure:procExtraiTextoDoPdf`, `Procedure:procGeraPdfDoDANFCE` e `Procedure:procCarregaSDTsDaNFe`.
- `Evidência direta`: no recorte mais reduzido desta bateria, a importação real manteve `exitCode = 0`, mas o log passou a destacar `src0246` em `Procedure:procCarregaSDTsDaNFe`, com referencia a objeto não definido `procStrZERO`.
- `Evidência direta`: na inspecao do XML extraido do `XPZ` exportado com `ExportAll=true`, `procStrZERO` apareceu no bloco `Source`, mas não apareceu como objeto exportado nem como referencia declarada do pacote.
- `Evidência direta`: um teste controlado derivando o `XPZ` exportado via headless e preenchendo o `Source` global com os valores do pacote full não alterou o padrão principal da importação real; `CssProperties.json`, `mismatched input ']' expecting 'default'`, `src0246` e `procStrZERO` permaneceram no mesmo comportamento observado antes.
- `Evidência direta`: um segundo teste controlado derivando o mesmo `XPZ` exportado via headless e trocando apenas as duas ocorrências de `Pattern Settings` de `Padrões GeneXus` para `GeneXus Patterns` também não alterou o padrão principal da importação real.
- `Inferência forte`: com esses dois testes, as duas diferencas remanescentes identificadas entre o pacote full e o export headless deixaram de ser suspeitas fortes para o ruido principal desta frente.
- `Evidência direta`: em uma segunda KB de teste sanitizada (`KB_Teste_B`), a exportação full headless com `ExportAll=true` concluiu com sucesso operacional, `exitCode = 0` e sem `stderr`.
- `Evidência direta`: na mesma `KB_Teste_B`, o `PreviewMode` de importação do pacote full exportado headless concluiu com `exitCode = 0` e sem `stderr`.
- `Evidência direta`: na mesma `KB_Teste_B`, a importação real do pacote full exportado headless concluiu com `exitCode = 0`; o `stderr` residual observado ficou restrito ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`, sem reaparecimento do bloqueio de conteúdo específico da `KB_Teste_A`.
- `Inferência forte`: a bateria em `KB_Teste_B` reforca que a trilha headless de exportação, preview e importação via `MSBuild` funciona em outra KB e que o caso `procCarregaSDTsDaNFe`/`procStrZERO` pertence ao conteúdo da `KB_Teste_A`, não ao mecanismo central da skill.
- `Evidência direta`: em uma terceira KB de teste sanitizada (`KB_Teste_C`), a bateria de exportação full headless, preview de importação e importação real do pacote exportado também concluiu com sucesso operacional.
- `Evidência direta`: na primeira tentativa de `preview` e importação de `KB_Teste_C`, o erro foi apenas de orquestracao local (`XpzPath inválido` antes de o arquivo existir), por disparo concorrente antes do fim do export; repetida a rodada em sequência correta, o fluxo passou sem bloqueio funcional novo.
- `Evidência direta`: na mesma `KB_Teste_C`, o `stderr` residual da importação real voltou a ficar limitado ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`, sem reaparecimento do bloqueio de conteúdo observado na `KB_Teste_A`.
- `Evidência direta`: em uma quarta KB de teste sanitizada (`KB_Teste_D`), a abertura headless confirmou um `Environment` coerente, e a bateria de exportação full headless, preview de importação e importação real do pacote exportado também concluiu com sucesso operacional.
- `Evidência direta`: na `KB_Teste_D`, o `stderr` residual da importação real permaneceu restrito ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`, sem bloqueio de conteúdo equivalente ao caso `procCarregaSDTsDaNFe`/`procStrZERO`.
- `Evidência direta`: em uma quinta KB de teste sanitizada (`KB_Teste_E`), a abertura headless confirmou um contexto ativo coerente, e a bateria de exportação full headless, preview de importação e importação real do pacote exportado também concluiu com `exitCode = 0`.
- `Evidência direta`: na `KB_Teste_E`, o `PreviewMode` registrou no `stdout` mensagens de contato com `GeneXus Server` em `http://sandbox.genexusserver.com/v18`, exigencia de credenciais e ausencia de licenca `GXtest` valida, mesmo mantendo `exitCode = 0`.
- `Evidência direta`: na mesma `KB_Teste_E`, `importedItems` veio vazio tanto no preview quanto na importação real, o que impede tratar essa rodada como evidência de sucesso funcional equivalente às KBs `KB_Teste_B`, `KB_Teste_C` e `KB_Teste_D`.
- `Evidência direta`: em `KB_Teste_F`, a bateria completa de exportação full headless, preview de importação e importação real concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importação real, e o `stderr` residual ficou restrito ao mesmo padrão lateral de `mismatched input ']' expecting 'default'`.
- `Evidência direta`: em `KB_Teste_G`, a bateria completa de exportação full headless, preview de importação e importação real também concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importação real, com o mesmo `stderr` lateral observado nas KBs favoraveis anteriores.
- `Evidência direta`: em `KB_Teste_H`, a bateria completa de exportação full headless, preview de importação e importação real também concluiu com sucesso operacional; `importedItems` veio preenchido no preview e na importação real, com o mesmo `stderr` lateral de `mismatched input ']' expecting 'default'`.
- `Evidência direta`: em `KB_Teste_Grande_A`, a abertura headless, o export full headless e o preview de importação concluiram com sucesso operacional; o preview trouxe `importedItems` preenchido mesmo em uma KB de grande porte.
- `Evidência direta`: na mesma `KB_Teste_Grande_A`, a abertura, o export e o preview reportaram warning recorrente sobre item desconhecido `WebPanelDesigner`, fornecido por extensao ausente `K2B Object Designer`, com alerta de risco de perda de informação relacionada a esses itens.
- `Evidência direta`: na importação real da `KB_Teste_Grande_A`, o wrapper inicial bateu timeout por duracao extrema, mas o processo `MSBuild` continuou em execução; o monitoramento posterior confirmou progresso continuo, inclusive em geração de padrões `WorkWith`, ate o `stdout` terminar com `Close Knowledge Base Task Sucesso`.
- `Inferência forte`: a `KB_Teste_Grande_A` demonstrou que a skill consegue concluir também em KB de grande porte, mas com janela de execução muito superior a das KBs medias; para esse perfil, timeout curto do wrapper não deve ser confundido com falha da operacao.
- `Inferência forte`: com evidência operacional repetida em `KB_Teste_A`, `KB_Teste_B`, `KB_Teste_C`, `KB_Teste_D`, `KB_Teste_F`, `KB_Teste_G`, `KB_Teste_H`, `KB_Teste_Grande_A` e agora `KB_Teste_E`, a trilha central de exportação, preview e importação via `MSBuild` permanece validada como mecanismo experimental; ao mesmo tempo, ficou demonstrado que `exitCode = 0` isolado não basta para validar sucesso funcional quando a KB aciona dependencia externa de `GeneXus Server` ou restrição de licenca, e que KBs muito grandes exigem janela de execução compativel com a escala.
- `Inferência forte`: para o estado atual desta frente, o bloqueio remanescente mais importante deixou de ser do wrapper e passou a apontar para conteúdo da KB/`XPZ`, por referencia quebrada em `Source` durante a importação.
- `Evidência direta`: os scripts previstos para exportação efetiva e importação efetiva agora estao materializados nesta fase.
- `Regra editorial`: a existência dessa skill não promove a trilha `MSBuild` a fluxo oficial da base nem altera automaticamente o comportamento das skills `xpz-*` existentes.

## Fontes consolidadas
- 00-inventario-da-base-documental.md
- 30-inventario-bruto-kb.md
- 98-mapeamento-para-consolidacao-em-10-arquivos.md
- 99-resumo-da-consolidacao.md

## Origem incorporada - 00-inventario-da-base-documental.md

## Papel do documento
índice

## Nível de confiança predominante
alto

## Depende de
nenhum; este inventario reconstrói o estado da base antes da consolidacao final

## Usado por
00-indice-da-base-genexus-xpz-xml.md, 04-genexus-open-points.md, 99-resumo-da-consolidacao.md

## Objetivo
Mapear os arquivos Markdown encontrados, identificar sobreposições e registrar a lógica de consolidação adotada.
Servir como trilha de auditoria da reorganização da base documental.

## Arquivos encontrados antes da consolidacao

### Raiz

- `README-DevKnowledgeGenexus.md`
- `genexus-xpz-research.md`
- `genexus-xpz-generation-rules.md`
- `genexus-object-design-patterns.md`
- `genexus-open-points.md`

### Subpasta `docs-kb-md`

- `00-inventario-bruto.md`
- `10-matriz-part-types-por-tipo.md`
- `11-campos-estaveis-vs-variaveis.md`
- `12-diffs-estruturais-por-tipo.md`
- `13-guia-de-clonagem-segura.md`
- `14-indicios-de-obrigatoriedade.md`
- `15-tipos-prontos-para-geracao-conservadora.md`
- `16-mapa-de-risco-por-tipo.md`
- `17-resumo-operacional-para-gerador-xpz.md`
- `18-checklist-para-novos-templates.md`

## Classificação por papel

### Conceituais

- `README-DevKnowledgeGenexus.md`
- `genexus-xpz-research.md`
- `genexus-xpz-generation-rules.md`
- `genexus-object-design-patterns.md`
- `genexus-open-points.md`

### Empiricos

- `docs-kb-md/00-inventario-bruto.md`
- `docs-kb-md/10-matriz-part-types-por-tipo.md`
- `docs-kb-md/11-campos-estaveis-vs-variaveis.md`
- `docs-kb-md/12-diffs-estruturais-por-tipo.md`
- `docs-kb-md/14-indicios-de-obrigatoriedade.md`

### Operacionais

- `docs-kb-md/13-guia-de-clonagem-segura.md`
- `docs-kb-md/15-tipos-prontos-para-geracao-conservadora.md`
- `docs-kb-md/16-mapa-de-risco-por-tipo.md`
- `docs-kb-md/17-resumo-operacional-para-gerador-xpz.md`
- `docs-kb-md/18-checklist-para-novos-templates.md`

## Sobreposicoes e duplicidades

- `Evidência direta`: os cinco arquivos da raiz antiga cobrem a camada conceitual e resumem resultados da varredura XML.
- `Evidência direta`: os dez arquivos em `docs-kb-md` aprofundam a camada empírica e operacional.
- `Evidência direta`: havia dependência indireta da subpasta `docs-kb-md` para leitura operacional da base.
- `Inferência forte`: a principal sobreposição estava entre resumos conceituais da raiz e recomendações operacionais da subpasta.
- `Inferência forte`: a consolidação correta exigia manter a raiz como ponto de leitura principal e tratar `docs-kb-md` como staging/histórico, não como destino final.

## Conflitos identificados

- `Evidência direta`: o prompt-alvo pede um `00-readme-genexus-xpz-xml.md` e também um `00-inventario-da-base-documental.md`.
- `Inferência forte`: isso cria uma colisao de prefixo, mas não inviabiliza a ordem de leitura porque os nomes continuam distintos.
- `Evidência direta`: arquivos heurísticos da subpasta (`15`, `16`, `17`) já tinham sido endurecidos para evitar promessas de importação.
- `Inferência forte`: qualquer consolidação precisava preservar essa versão mais conservadora como fonte principal.

## Decisão de consolidacao

- `Evidência direta`: a base final foi reorganizada na raiz com numeração global.
- `Evidência direta`: os documentos finais passaram a existir na raiz sob os nomes `00`, `01`, `02`, `03`, `04`, `10`, `11`, `12`, `20` a `26`, `30` e `99`.
- `Inferência forte`: a subpasta `docs-kb-md` deve ser tratada como arquivo histórico de trabalho, não como referência operacional primária.


## Origem incorporada - 30-inventario-bruto-kb.md

## Papel do documento
empirico

## Nível de confianca predominante
alto

## Depende de
nenhum; esta versão substitui o dump bruto nominal para publicacao

## Usado por
01-base-empirica-geral.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 00-indice-da-base-genexus-xpz-xml.md

## Objetivo
Preservar os fatos agregados da varredura XML sem expor nomes reais de objeto, módulos, pais, caminhos ou descricoes de negocio da KB de origem.
Servir como base factual publica para verificacao posterior.

- Fonte sanitizada: `C:\SANITIZED\ObjetosDaKbEmXml`
- Escopo analisado: `7416` arquivos XML
- Total de registros de objetos lidos: `7416`
- Total de arquivos problematicos: `0`
- Tipos de objeto observados: `API`, `ColorPalette`, `Dashboard`, `DataProvider`, `DesignSystem`, `Domain`, `Index`, `Module`, `PackagedModule`, `Panel`, `Procedure`, `SDT`, `SubTypeGroup`, `Theme`, `ThemeClass`, `Transaction`, `UserControl`, `WebPanel`, `WorkWithForWeb`

## Contagem por pasta

| FolderType | FileCount |
| --- | ---: |
| API | 1 |
| ColorPalette | 1 |
| Dashboard | 1 |
| DataProvider | 24 |
| DesignSystem | 2 |
| Domain | 137 |
| Index | 228 |
| Module | 27 |
| PackagedModule | 3 |
| Panel | 3 |
| Procedure | 3847 |
| SDT | 181 |
| SubTypeGroup | 709 |
| Theme | 6 |
| ThemeClass | 677 |
| Transaction | 183 |
| UserControl | 7 |
| WebPanel | 1196 |
| WorkWithForWeb | 183 |

## Politica de redacao desta versão publica

- nomes reais de objeto foram removidos desta versão
- caminhos reais da KB foram substituidos por caminho sanitizado
- a utilidade operacional permanece nos documentos `10`, `11`, `12`, `27` e `28`, que preservam contagens, GUIDs e familias estruturais
- para materialização real de XML ou XPZ, a fonte continua sendo XML bruto privado comparavel, exceto nos casos em que a própria base publica já publicar bloco `molde pronto` suficiente para materialização controlada

## Observação

- Hipotese: o dump nominal completo deve permanecer apenas em acervo privado controlado.
- Inferencia forte: para uso publico, esta versão agregada cobre os fatos necessários sem expor a KB original.


## Origem incorporada - 98-mapeamento-para-consolidacao-em-10-arquivos.md

## Papel do documento
índice e operacional

## Nível de confianca predominante
alto

## Depende de
00-readme-genexus-xpz-xml.md, 00-inventario-da-base-documental.md, 99-resumo-da-consolidacao.md

## Usado por
futura consolidacao da base em serie documental mais enxuta e roteavel

## Objetivo
Mapear a base atual para a estrutura consolidada proposta, incluindo a serie `01` desdobrada.
Preservar todo o conteúdo existente, definindo destino e critério de incorporacao antes de qualquer fusao.

## Estrutura alvo

1. `00-indice-da-base-genexus-xpz-xml.md`
2. `01-base-empirica-geral.md`
3. `02-regras-operacionais-e-runtime.md`
4. `03-risco-e-decisao-por-tipo.md`
5. `04-webpanel-familias-e-templates.md`
6. `05-transaction-familias-e-templates.md`
7. `06-padroes-de-objeto-e-nomenclatura.md`
8. `07-open-points-e-checklist.md`
9. `08-guia-para-agente-gpt.md`
10. `09-inventario-e-rastreabilidade-publica.md`

## Regra de consolidacao

- não apagar conteúdo
- não promover inferencia para evidencia
- manter `Evidência direta`, `Inferência forte` e `Hipótese`
- mover ou fundir por função documental, não por ordem histórica de criacao
- quando houver sobreposicao, manter a versão mais clara e mais conservadora

## Mapeamento arquivo a arquivo

### 00-indice-da-base-genexus-xpz-xml.md

- Destino principal: `00-indice-da-base-genexus-xpz-xml.md`
- Manter:
  - objetivo da base
  - escopo
  - ordem de leitura
  - limites metodologicos
- Incorporar também:
  - resumo do fluxo de consulta hoje espalhado em `26-guia-para-agente-gpt.md`

### 00-inventario-da-base-documental.md

- Destino principal: `09-inventario-e-rastreabilidade-publica.md`
- Manter:
  - inventario dos documentos
  - diagnostico de duplicidade/sobreposicao
  - observacoes sobre reorganizacao da base

### 01-base-empirica-geral.md

- Destino principal: `01-base-empirica-geral.md`
- Manter:
  - índice mestre da serie `01`
  - premissas empiricas gerais sobre XML/XPZ
  - observacoes gerais de estrutura
  - limites do que foi de fato observado

### 02-genexus-xpz-generation-rules.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - regras gerais de geração
  - postura conservadora de montagem
  - restrições de fonte e materialização
- Integrar sem duplicar trechos que hoje já estao mais fortes em `02-regras-operacionais-e-runtime.md`

### 03-genexus-object-design-patterns.md

- Destino principal: `06-padroes-de-objeto-e-nomenclatura.md`
- Manter:
  - padrões de nomenclatura
  - padrões de relacionamento aparente
  - leitura conceitual do acervo

### 04-genexus-open-points.md

- Destino principal: `07-open-points-e-checklist.md`
- Manter:
  - conflitos
  - lacunas
  - questoes ainda não fechadas
  - decisoes operacionais provisórias

### 10-matriz-part-types-por-tipo.md

- Destino principal: `01b-matriz-part-types-por-tipo.md`
- Manter:
  - tabela de `PartType`
  - frequencias por tipo
  - classificação preliminar
- Consolidar como arquivo filho da serie `01`

### 11-campos-estaveis-vs-variaveis.md

- Destino principal: `01c-campos-estaveis-vs-variaveis.md`
- Manter:
  - atributos recorrentes do no `<Object>`
  - campos estaveis, variáveis e contextuais
- Consolidar como arquivo filho da serie `01`

### 12-diffs-estruturais-por-tipo.md

- Destino principal: `01d-diffs-estruturais-por-tipo.md`
- Manter:
  - comparacoes simples vs complexas
  - diferencas por tipo
- Consolidar como arquivo filho da serie `01`

### 02-regras-operacionais-e-runtime.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - critérios de escolha de template
  - o que preservar
  - o que pode ser alterado com mais cautela
- Consolidar como seção:
  - `Clonagem conservadora`

### 03-risco-e-decisao-por-tipo.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - leitura heuristica de obrigatoriedade
  - opcionalidade
  - ausencia de evidencia suficiente
- Consolidar como seção:
  - `Obrigatoriedade heuristica`

### 22-tipos-prontos-para-geracao-conservadora.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - classificação por prontidao relativa
  - decisão operacional atual de `Transaction` e `WebPanel`
- Consolidar como seção:
  - `Prontidao por tipo`

### 03-risco-e-decisao-por-tipo.md

- Destino principal: `03-risco-e-decisao-por-tipo.md`
- Manter:
  - mapa resumido de risco
  - recomendacao prática por tipo
- Consolidar como seção:
  - `Mapa de risco`

### 02-regras-operacionais-e-runtime.md

- Destino principal: `02-regras-operacionais-e-runtime.md`
- Manter:
  - algoritmo de geração
  - regras de materialização
  - regras de serializacao XPZ
  - regras de fonte
  - validacoes minimas
- Consolidar como seção central:
  - `Especificacao executavel`

### 25-checklist-para-novos-templates.md

- Destino principal: `07-open-points-e-checklist.md`
- Manter:
  - checklist de coleta futura
  - critérios de template adicional
- Consolidar como seção:
  - `Checklist de templates`

### 26-guia-para-agente-gpt.md

- Destino principal: `08-guia-para-agente-gpt.md`
- Manter:
  - ordem de consulta
  - critérios de resposta
  - quando gerar, recusar ou abortar
  - regras de materialização, serializacao e fonte do ponto de vista do agente
- Incorporar trechos introdutorios mais curtos também em `00-indice-da-base-genexus-xpz-xml.md`

### 04-webpanel-familias-e-templates.md

- Destino principal: `04-webpanel-familias-e-templates.md`
- Manter:
  - familias estruturais
  - templates representativos
  - regras específicas
  - anexos sanitizados
- Estrutura interna sugerida:
  - visao geral
  - familias
  - regras operacionais
  - anexos sanitizados

### 05-transaction-familias-e-templates.md

- Destino principal: `05-transaction-familias-e-templates.md`
- Manter:
  - familias estruturais
  - regras por familia
  - validacoes de consistencia interna
- Estrutura interna sugerida:
  - visao geral
  - familias
  - regras operacionais
  - validacoes

### 30-inventario-bruto-kb.md

- Destino principal: `09-inventario-e-rastreabilidade-publica.md`
- Manter:
  - contagens agregadas
  - escopo da varredura
  - politica de versão publica sanitizada
- Não reincorporar:
  - dump nominal privado antigo

### 99-resumo-da-consolidacao.md

- Destino principal: `09-inventario-e-rastreabilidade-publica.md`
- Manter:
  - histórico da consolidacao
  - decisoes tomadas
  - renomeacoes
  - conflitos resolvidos

## Mapeamento por seção alvo

### 00-indice-da-base-genexus-xpz-xml.md

- de `00-indice-da-base-genexus-xpz-xml.md`
- de `26-guia-para-agente-gpt.md`: ordem de consulta resumida e limites de uso

### 01-base-empirica-geral.md

- de `01-base-empirica-geral.md`
- de `10-matriz-part-types-por-tipo.md`
- de `11-campos-estaveis-vs-variaveis.md`
- de `12-diffs-estruturais-por-tipo.md`
- reorganizado depois como serie `01` com índice mestre em `01-base-empirica-geral.md` e arquivos filhos `01a` a `01h`

### 02-regras-operacionais-e-runtime.md

- de `02-genexus-xpz-generation-rules.md`
- de `02-regras-operacionais-e-runtime.md`
- de `02-regras-operacionais-e-runtime.md`

### 03-risco-e-decisao-por-tipo.md

- de `03-risco-e-decisao-por-tipo.md`
- de `22-tipos-prontos-para-geracao-conservadora.md`
- de `03-risco-e-decisao-por-tipo.md`

### 04-webpanel-familias-e-templates.md

- de `04-webpanel-familias-e-templates.md`

### 05-transaction-familias-e-templates.md

- de `05-transaction-familias-e-templates.md`

### 06-padroes-de-objeto-e-nomenclatura.md

- de `03-genexus-object-design-patterns.md`

### 07-open-points-e-checklist.md

- de `04-genexus-open-points.md`
- de `25-checklist-para-novos-templates.md`

### 08-guia-para-agente-gpt.md

- de `26-guia-para-agente-gpt.md`

### 09-inventario-e-rastreabilidade-publica.md

- de `00-inventario-da-base-documental.md`
- de `30-inventario-bruto-kb.md`
- de `99-resumo-da-consolidacao.md`

## Regras de fusao

- preservar o conteúdo integral, movendo para seções mais amplas
- quando duas seções disserem quase a mesma coisa, manter a versão mais conservadora e citar a complementar
- tabelas muito grandes devem aparecer uma vez só
- templates sanitizados devem permanecer apenas nos arquivos de tipo, não em documentos gerais
- histórico e inventario devem ficar separados das regras executaveis

## Ordem recomendada de execução da consolidacao

1. consolidar `09-inventario-e-rastreabilidade-publica.md`
2. consolidar `01-base-empirica-geral.md`
3. consolidar `02-regras-operacionais-e-runtime.md`
4. consolidar `03-risco-e-decisao-por-tipo.md`
5. manter `04` e `05` como arquivos especializados
6. consolidar `06`, `07` e `08`
7. revisar `00-indice-da-base-genexus-xpz-xml.md` por fim, apontando para a nova estrutura

## Observação final

- Inferencia forte: essa consolidacao reduz bem a fragmentacao sem sacrificar navegabilidade para GPT.
- Hipotese: depois da fusao, a base ficara mais fácil de usar do que hoje, desde que os novos arquivos tenham sumario interno e seções bem delimitadas.


## Origem incorporada - 99-resumo-da-consolidacao.md

## Papel do documento
índice

## Nível de confiança predominante
alto

## Depende de
00-inventario-da-base-documental.md

## Usado por
manutencao futura da base e auditoria de consolidacao

## Objetivo
Registrar o que foi lido, renomeado, consolidado e mantido em aberto durante a reorganização da base documental.

## Arquivos lidos

- os 5 arquivos Markdown legados da raiz
- os 10 arquivos Markdown da subpasta `docs-kb-md`

## Arquivos renomeados/consolidados para a raiz

- `genexus-xpz-research.md` -> `01-base-empirica-geral.md`
- `genexus-xpz-generation-rules.md` -> `02-genexus-xpz-generation-rules.md`
- `genexus-object-design-patterns.md` -> `03-genexus-object-design-patterns.md`
- `genexus-open-points.md` -> `04-genexus-open-points.md`
- `docs-kb-md/10-matriz-part-types-por-tipo.md` -> `10-matriz-part-types-por-tipo.md`
- `docs-kb-md/11-campos-estaveis-vs-variaveis.md` -> `11-campos-estaveis-vs-variaveis.md`
- `docs-kb-md/12-diffs-estruturais-por-tipo.md` -> `12-diffs-estruturais-por-tipo.md`
- `docs-kb-md/13-guia-de-clonagem-segura.md` -> `02-regras-operacionais-e-runtime.md`
- `docs-kb-md/14-indicios-de-obrigatoriedade.md` -> `03-risco-e-decisao-por-tipo.md`
- `docs-kb-md/15-tipos-prontos-para-geracao-conservadora.md` -> `22-tipos-prontos-para-geracao-conservadora.md`
- `docs-kb-md/16-mapa-de-risco-por-tipo.md` -> `03-risco-e-decisao-por-tipo.md`
- `docs-kb-md/17-resumo-operacional-para-gerador-xpz.md` -> `02-regras-operacionais-e-runtime.md`
- `docs-kb-md/18-checklist-para-novos-templates.md` -> `25-checklist-para-novos-templates.md`
- `docs-kb-md/00-inventario-bruto.md` -> `30-inventario-bruto-kb.md`

## Arquivos criados na consolidacao

- `00-inventario-da-base-documental.md`
- `00-readme-genexus-xpz-xml.md`
- `26-guia-para-agente-gpt.md`
- `99-resumo-da-consolidacao.md`

## Decisoes tomadas

- manter a versão mais conservadora sempre que havia choque entre resumo e heurística operacional
- deixar a raiz como ponto de leitura principal
- tratar `docs-kb-md` como staging/histórico e não como fonte operacional primária
- preservar o caráter heurístico dos antigos `14`, `15`, `16` e `17`, agora `21`, `22`, `23` e `24`
- atualizar a politica para `Transaction` e `WebPanel` de bloqueio por prudencia para execução controlada com base interna

## Conflitos encontrados

- conflito de prefixo entre `00-readme-genexus-xpz-xml.md` e `00-inventario-da-base-documental.md`
- houve coexistência temporária entre arquivos legados e arquivos consolidados durante a consolidação
- risco de leitura duplicada entre raiz e `docs-kb-md` se não houver orientação clara

## O que permaneceu em aberto

- semântica exata dos GUIDs de `Part type`
- obrigatoriedade real validada por importação
- estabilidade dos padrões fora desta KB
- diferença funcional precisa entre `Module` e `PackagedModule`

## Atualizacao de politica posterior

- `Evidência direta`: a base passou a reconhecer 183 `Transaction` e 1196 `WebPanel` como massa amostral suficiente para execução controlada.
- `Inferência forte`: a mudanca prática foi de bloqueio por prudencia para tentativa controlada com template interno da própria base.
- `Evidência direta`: um teste controlado de importação de `.xpz` mínimo de `Procedure` foi bem-sucedido nesta trilha e confirmou o envelope normal sem `KnowledgeBase`.
- `Evidência direta`: o mesmo teste mostrou que `Source/@kb` e `Source/Version/@guid` não podem ficar como placeholders textuais; precisam ser GUIDs sintaticamente validos.
- `Hipótese`: os erros adicionais de importação que aparecerem devem continuar sendo incorporados ao refinamento desta mesma documentação.

## Aliases publicos de Procedure de relatório

Estes aliases foram criados em 2026-04-25 a partir da análise estrutural de 77 XMLs de `Procedure` de relatório no acervo privado. Cada alias representa o menor XML observado dentro da respectiva familia estrutural definida em `05b-procedure-relatorio-familias-e-templates.md`.

| Alias publico | Familia | Critério estrutural |
|---|---|---|
| `PRCRelatorioExemploF1` | F1 — Embriao sem layout ativo | FE=0, sem Header, sem Footer; menor XML da faixa |
| `PRCRelatorioExemploF2` | F2 — Molde base com cabecalho de pagina | FE=0, com Header e/ou Footer; menor XML da faixa |
| `PRCRelatorioExemploF3` | F3 — Listagem linear simples | FE=1-2; menor XML da faixa |
| `PRCRelatorioExemploF4` | F4 — Relatório com agrupamento e totalizacao | FE=3-6, PB<=24; menor XML da faixa |
| `PRCRelatorioExemploF5` | F5 — Relatório complexo de alto volume | FE>=7 ou PB>=25; menor XML com FE>=10 e PB>=20 simultaneamente |

- Rastreabilidade privada: os nomes reais dos representantes estao registrados em `GeneXus-XPZ-PrivateMap/maps/object-alias-map.csv`.
- Uso previsto: esses aliases servem como referencia estrutural para `xpz-reader`, `xpz-builder` e `xpz-doc-builder` ao trabalhar com `Procedure` de relatório.
- Regra editorial: nunca usar o alias como única fonte para materialização.
- Regra editorial: quando `05b-procedure-relatorio-familias-e-templates.md` oferecer `molde pronto` suficiente para a familia simples coberta, o alias pode servir apenas como referencia de classificação para chegar a esse molde sanitizado.
- Regra editorial: fora dessa cobertura simples, ou depois de tentativa inicial mais um único corretivo curto sem sucesso, o próximo passo obrigatório volta a ser XML real comparavel.
