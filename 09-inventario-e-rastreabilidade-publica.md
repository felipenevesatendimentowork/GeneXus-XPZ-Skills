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
- `scripts/Sync-GeneXusXpzToXml.ps1` (motor) — materializa XMLs de pacote XPZ e reconcilia o acervo; em `-FullSnapshot` reconcilia rename por `guid` (Move-Item, fail-closed em colisão); `-KbMetadataPath` persiste metadados da KB via `scripts/XpzKbSourceMetadataEditSupport.ps1`; pré-varredura de catálogo (`-ParallelKbRoot`/`-CatalogOverridePath`/`-DiscoveryReportPath`). Dono: xpz-sync/SKILL.md; também 02-regras-operacionais-e-runtime.md. Validação: Test-XpzSyncGuidRenameSelfTest.ps1. Tokens: `OK: Test-XpzSyncGuidRenameSelfTest.ps1`.
- `scripts/gx-object-type-catalog.json` (catálogo) — GUIDs de tipos de objeto (ex.: `DataView`, `SmartDevicesApplication`, `SmartDevicesPlus`) e `exportTaskLabel` quando o rótulo da task Export diverge do tipo. Dono: 01a-catalogo-e-padroes-empiricos.md; também 10a-gx-export-task-labels.md. Validação: via GeneXusObjectTypeCatalogSupport.ps1 e Build-KbIntelligenceIndex.py.
- `scripts-maintenance/GeneXusExportTaskLabelSupport.ps1`, `Build-ExportTaskLabelCoverageMap.ps1`, `Run-ExportTaskLabelMatrix.ps1`, `Invoke-ExportTaskLabelCampaign.ps1`, `Merge-ExportTaskLabelCampaignResults.ps1` (manutenção) — campanha da matriz `exportTaskLabel` (cobertura, execução MSBuild por tipo, consolidação, `-ApplyCatalog`); não-runtime das skills. Dono: 10a-gx-export-task-labels.md; rodada em `historico/export-task-label-matrix-20260530/`.
- `scripts/Get-GeneXusImportPackageObjectInventory.ps1` (motor) — inventaria `import_file.xml`/`<ExportFile>`/`.xpz`, agrega `objectsByType`, detecta plataforma/SDK e confronta delta declarado (`-DeclaredDeltaPath`/`-DeclaredDeltaItems`); `-FailOnUnknownTypes` (exit 3). Dono: xpz-msbuild-import-export/SKILL.md; também xpz-builder/SKILL.md. Validação: Test-GeneXusImportPackageObjectInventorySelfTest.ps1. Tokens: `INVENTORY_OK`, `GENEXUS_PKG_INVENTORY_SELFTEST_OK`. Exit: 3.
- `scripts/GeneXusObjectListIdentityPreflight.ps1` (motor) — valida identidade `Tipo:Nome` contra KbIntelligence antes de export/import seletivo MSBuild (consumido por Invoke-GeneXusXpzExport/Import e Test-GeneXusXpzImportPreview); homônimo ou índice ausente → exit 35, `not_in_index` apenas avisa. Dono: xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusObjectListIdentityPreflightSelfTest.ps1. Exit: 35.
- `Evidência direta`: `scripts/Invoke-GeneXusXpzExport.ps1` após exportação com XPZ gerado preenche `packageInventory` resumido no diagnostico JSON via `scripts/GeneXusPackageInventorySupport.ps1` (carregado por `scripts/GeneXusXpzExportInventoryGovernance.ps1`), grava `package-inventory.json` completo no diretório de artefatos, expoe `nominalInventoryAt` apontando para o sidecar quando gravado (lista nominal completa); em confronto seletivo com delta, `extrasFullListAt` repete o mesmo caminho do sidecar para a lista completa de extras de `<Objects>`; `extrasSample`/`extrasSampleTruncated` para extras de `<Objects>` no resumo, classifica `operationalSubState` no módulo de governanca de export e marca `inventoryDegraded=true` sem rebaixar o exit code da task MSBuild quando o inventario falha.
- `scripts/GeneXusXpzExportInventoryGovernance.ps1` (motor) — classifica `operationalSubState` de export (precedência: exportErrors > inventário degradado > sub-estado do inventário). Dono: xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusXpzExportSubStateClassifierSelfTest.ps1. Tokens: `EXPORT_SUBSTATE_CLASSIFIER_SELFTEST_OK`.
- `scripts/msbuild-exit-codes.catalog.json` (catálogo) — índice versionado de `exitCode` dos wrappers MSBuild. Dono: o próprio JSON; também 10-base-operacional-msbuild-headless.md. Validação: Test-MsBuildExitCodesCatalog.ps1. Tokens: `MSBUILD_EXIT_CODES_CATALOG_OK`. Exit: 10-16/31-35/40-50/90.
- `scripts/GeneXusMsBuildLogPathSupport.ps1` (motor) — gate fail-fast: rejeita `-LogPath` que aponta para diretório existente (exit 50), nos 10 wrappers MSBuild que recebem `-LogPath`. Dono: cabeçalho do script; também msbuild-exit-codes.catalog.json. Validação: Test-GeneXusMsBuildLogPathSupportSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_LOGPATH_SUPPORT_SELFTEST_OK`. Exit: 50.
- `scripts/GeneXusMsBuildConcurrencySupport.ps1`, `scripts/Test-GeneXusMsBuildKbConcurrency.ps1` (motor) — bloqueio preventivo de `MSBuild.exe` concorrente na mesma KB (exit 46); processo sem `.msbuild`/`KBPath` reconciliável apenas avisa; a trilha não enfileira nem retenta. Dono: xpz-msbuild-build/SKILL.md; também xpz-msbuild-import-export/SKILL.md, msbuild-exit-codes.catalog.json. Validação: Test-GeneXusMsBuildConcurrencySupportSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_CONCURRENCY_SUPPORT_SELFTEST_OK`. Exit: 46.
- `Evidência direta`: `scripts/Invoke-GeneXusKbBuildAll.ps1` bloqueia `CompileMains=true` e `DetailedNavigation=true` sem `-AllowCostlyBuildOptions`; `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1` bloqueia `DetailedNavigation=true` sem `-AllowCostlyBuildOptions`; ambos registram `AllowCostlyBuildOptionsRequested`, `AllowCostlyBuildOptionsConfirmed` e `ConfirmCostlyBuildOptionsMode` no JSON e exigem a frase exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar` para execução interativa; `scripts/Invoke-GeneXusXpzImportThenBuild.ps1` propaga `-AllowCostlyBuildOptions` e `-ConfirmCostlyBuildOptions` para o build pos-import.
- `scripts/Invoke-GeneXusXpzImportThenBuild.ps1` (motor) — wrapper integrador import→build (filhos em `pwsh -File`); só chama `BuildAll` quando `importReadyForBuild.ready=true`; senão `roundtripStatus='import-blocked-or-failed'`, `buildJson=null`. Dono: xpz-msbuild-import-export/SKILL.md; também xpz-msbuild-build/SKILL.md. Validação: via orquestrador. Exit: 46.
- `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1`, `scripts/Register-GeneXusKbPostBuildEvents.ps1` (motor) — extrai e classifica eventos pós-build do stdout MSBuild (esperado/inesperado/inerte/benigno, `shouldDowngrade`); registro de fingerprints por environment (`kb_environment_post_build_event_hashes`). Dono: xpz-msbuild-build/SKILL.md; registro sob xpz-kb-parallel-setup/SKILL.md. Validação: Test-GeneXusMsBuildPostBuildEventsSupportSelfTest.ps1, Test-GeneXusPostBuildEventClassificationSelfTest.ps1, Test-GeneXusKbPostBuildEventsRegistrationSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_POST_BUILD_EVENTS_SUPPORT_SELFTEST_OK`, `GENEXUS_POST_BUILD_EVENT_CLASSIFICATION_SELFTEST_OK`, `GENEXUS_KB_POST_BUILD_EVENTS_REGISTRATION_SELFTEST_OK`.
- `scripts/GeneXusMsBuildGamPlatformsSupport.ps1` (motor) — filtra ruído GAM/NetCore no stdout (`MSB3491`/`NuGet.targets` acesso negado sob `\Library\GAM\Platforms\`) e sugere `icacls` (não executa concessão NTFS); pós-processamento resiliente, não rebaixa MSBuild limpo para exit 90. Dono: xpz-msbuild-build/SKILL.md. Validação: Test-GeneXusMsBuildGamPlatformsSupportSelfTest.ps1. Tokens: `GENEXUS_MSBUILD_GAM_PLATFORMS_SUPPORT_SELFTEST_OK`.
- `scripts/Read-MsBuildImportSignals.ps1`, `scripts/GeneXusMsBuildCategoryBSupport.ps1` (motor) — classifica linhas `error :` do log MSBuild por estágio e rebaixa para Categoria B (exit 48) quando `executionEvidence.msBuildExitCode=0` mas há rejeição no log; `operationalSubState` por trilha. Dono: xpz-msbuild-import-export/SKILL.md; também 10-base-operacional-msbuild-headless.md, msbuild-exit-codes.catalog.json. Validação: Test-GeneXusMsBuildCategoryBSupportSelfTest.ps1, Test-GeneXusXpzExportErrorBarringSelfTest.ps1. Tokens: `MSBUILD_CATEGORY_B_SUPPORT_SELFTEST_OK`, `EXPORT_ERROR_BARRING_SELFTEST_OK`. Exit: 48.
- `scripts/gx-platform-objects.json`, `scripts/GeneXusPlatformObjectsCatalogSupport.ps1` (catálogo) — objetos de plataforma/SDK (`kind` packagedModule|externalObject). Dono: xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusPlatformObjectsCatalogSelfTest.ps1. Tokens: `GENEXUS_PLATFORM_OBJECTS_CATALOG_SELFTEST_OK`.
- `Evidência direta`: `scripts/Test-GeneXusImportPackageObjectInventorySelfTest.ps1` valida o motor `scripts/Get-GeneXusImportPackageObjectInventory.ps1` em XML e `.xpz` sintetico (delta seletivo, `PackagedModule` e `ExternalObject` de plataforma, sinal de atributos top-level sem `Transaction` na lista e controle negativo com `Transaction`); sentinela `GENEXUS_PKG_INVENTORY_SELFTEST_OK`.
- `scripts/Test-XpzParameterNamingContract.ps1` (motor) — trava por metadados (`Get-Command`) a nomenclatura/aliases de parâmetros das skills XPZ (`-ObjectList`/`-ObjectNames`, `-InputPath`/`-Path`, `-XpzPath`; e a trava negativa do `-AsJson` em Test-GeneXusSourceSanity). Dono: 02-regras-operacionais-e-runtime.md. Validação: gate próprio. Tokens: `XPZ_PARAMETER_NAMING_CONTRACT_OK`.
- `scripts/GeneXusObjectTypeCatalogSupport.ps1` (support-library) — mescla `gx-object-type-catalog.json` + override local (`gx-object-type-catalog.override.json`), agrega tipos desconhecidos e formata triagem. Dono: 01a-catalogo-e-padroes-empiricos.md. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1.
- `scripts/Register-GeneXusObjectTypeCatalogOverride.ps1` (motor) — grava override paliativo com `-UserApproved` e `upstreamPending=true`. Dono: 01a-catalogo-e-padroes-empiricos.md; também README.md. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1.
- `scripts/Test-XpzCatalogOverrideSessionReminder.ps1` (motor) — lembrete de sessão quando o override local de catálogo exige alinhamento upstream (exit 2 em `reminderRequired`). Dono: cabeçalho do script; também xpz-kb-parallel-setup/SKILL.md. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1. Exit: 2.
- `scripts/New-GeneXusUnknownTypeMaintainerPrompt.ps1` (motor) — gera prompt copiável para o mantenedor registrar tipo no catálogo compartilhado. Dono: cabeçalho do script. Validação: via Test-GeneXusUnknownTypeDiscoverySelfTest.ps1.
- `scripts/Test-GeneXusUnknownTypeDiscoverySelfTest.ps1` (motor) — self-test de descoberta de tipo desconhecido (agregação GUID, override, lembrete, inventário pós-merge). Dono: 01a-catalogo-e-padroes-empiricos.md. Validação: self-test. Tokens: `OK: Test-GeneXusUnknownTypeDiscoverySelfTest.ps1`.
- `scripts/Test-XpzObjetosDaKbNaming.ps1` (motor) — auditoria de naming em `ObjetosDaKbEmXml` usando o catálogo efetivo (base + override). Dono: cabeçalho do script; também 08-guia-para-agente-gpt.md. Validação: nenhum self-test próprio.
- `scripts/GeneXusPackageInventorySupport.ps1` (support-library) — motor de resumo `packageInventory` compartilhado (import e export). Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-GeneXusPackageInventorySupportSelfTest.ps1, Test-XpzBuilderPackageInventorySelfTest.ps1. Tokens: `XPZ_BUILDER_PACKAGE_INVENTORY_SELFTEST_OK`, `GENEXUS_PACKAGE_INVENTORY_SUPPORT_SELFTEST_OK`.
- `Inferência forte`: esse inventario complementa a validação de envelope; ele não transforma a pasta `scripts/` em fonte normativa, mas registra motor compartilhado relevante para rastreabilidade operacional.
- `scripts/Test-GeneXusImportFileEnvelope.ps1` (motor) — validação estática de `import_file.xml`; p/ Panel aceita `-PanelReferencePath` e registra panel-level-layout-{confirmed|unverified|suspicious}. Dono: xpz-builder/SKILL.md; também responsibilities-by-type/panel.md. Validação: via fluxo do envelope.
- `scripts/Get-GeneXusObjectSummary.ps1`, `scripts/Compare-GeneXusPanelShape.ps1` (motor) — diagnóstico compacto de Panel SD e WebPanel clássico (tables Flex/Responsive, buttons `<action>`/`<ucw>`, eventos, `coverage`/`unknownUcwControlTypes`) sem despejar CDATA; `gxControlType` via catálogo. Dono: 08-guia-para-agente-gpt.md e 02-regras-operacionais-e-runtime.md; também responsibilities-by-type/panel.md e webpanel.md, 04b-ucw-gxcontroltype-reference.md. Validação: Test-GeneXusWebPanelShapeContract.ps1.
- `scripts/gx-ucw-gxcontroltype-catalog.json` (catálogo) — `gxControlType` de User Controls em `GxMultiForm`. Dono: 04b-ucw-gxcontroltype-reference.md. Validação: via Test-GeneXusWebPanelShapeContract.ps1.
- `scripts/Add-GeneXusButton.ps1` (motor) — insere botão em WebPanel cirurgicamente (`<cell>` `<action>`/`<ucw>` em tabela Flex, `-BeforeControlName`/`-AfterControlName`), reusa GeneXusXmlSurgicalEditSupport.ps1 (não re-serializa CDATA); aborta fail-closed `RESPONSIVE_UNSAFE` em Responsive. Dono: 08-guia-para-agente-gpt.md; também responsibilities-by-type/webpanel.md. Validação: Test-GeneXusAddButtonContract.ps1.
- `scripts/Test-GeneXusTransactionCoherence.ps1` (motor) — gate 9-TWS de coerência de Transaction; finding `wwp-screen-code-on-non-generated-transaction` (fail): Transaction `GenerateObject=False` com código de tela WorkWithPlus órfão. Dono: xpz-builder/SKILL.md, wwp-packaging.md, responsibilities-by-type/transaction.md. Validação: Test-GeneXusTransactionCoherenceSelfTest.ps1. Tokens: `OK: Test-GeneXusTransactionCoherenceSelfTest.ps1`.
- `scripts/Search-GeneXusXmlSourceBlock.ps1` (motor) — busca textual em `<Source>` separando events/layout/code/serialized (evita falso code-behind de `GxMultiForm`); compacto ou `-AsJson`. Dono: 02-regras-operacionais-e-runtime.md e 08-guia-para-agente-gpt.md. Validação: Test-SearchGeneXusXmlSourceBlockSelfTest.ps1. Tokens: `SEARCH_GENEXUS_XML_SOURCE_BLOCK_SELFTEST_OK`.
- `scripts/Resolve-GeneXusKbIdentity.ps1` (motor) — resolve (read-only) identidade estável da KB nativa local (`model.ini`, `knowledgebase.connection`, banco interno). Dono: 02-regras-operacionais-e-runtime.md; também 08-guia-para-agente-gpt.md, README.md, xpz-kb-parallel-setup/SKILL.md. Validação: nenhum self-test próprio.
- `scripts/Update-XpzKbSourceMetadataIdentity.ps1` (motor) — escrita localizada de identidade estável em `kb-source-metadata.md` (preenche ausentes, bloqueia divergência não vazia salvo aprovação; preserva EOL via XpzTextFileEolSupport.ps1). Dono: 02-regras-operacionais-e-runtime.md; também 08, xpz-kb-parallel-setup/SKILL.md, README.md. Validação: nenhum self-test próprio.
- `scripts/Test-XpzWrapperInventory.ps1` (motor) — auditoria de wrappers locais: scripts legados (`INVENTORY_LEGACY_ORPHANS`), finos recomendados ausentes (`INVENTORY_RECOMMENDED_MISSING`) e wrapper customizado (`INVENTORY_CUSTOMIZED`, inclui K8/K9 sem repasse de `-AsJson` via `missing_AsJson_passthrough`). Dono: xpz-kb-parallel-setup/SKILL.md. Validação: Test-XpzWrapperInventorySelfTest.ps1. Tokens: `INVENTORY_LEGACY_ORPHANS`, `INVENTORY_RECOMMENDED_MISSING`, `INVENTORY_CUSTOMIZED`.
- `scripts/Test-XpzKbDeploymentMetadata.ps1` (motor) — valida plausibilidade de environment/deploy/output em `kb-source-metadata.md`; dimensão `metadata/deploy` de Test-XpzSetupAudit. Dono: xpz-kb-parallel-setup/SKILL.md. Validação: via Test-XpzSetupAudit / self-tests de setup.
- `scripts/Test-XpzWrapperInventorySelfTest.ps1` (motor) — bateria do inventário de wrappers (`INVENTORY_CUSTOMIZED`/`INVENTORY_LEGACY_ORPHANS`/`INVENTORY_RECOMMENDED_MISSING`, incl. `missing_AsJson_passthrough` K8/K9). Dono: xpz-kb-parallel-setup/SKILL.md. Validação: self-test. Tokens: `INVENTORY_CUSTOMIZED`, `INVENTORY_LEGACY_ORPHANS`, `INVENTORY_RECOMMENDED_MISSING`.
- `scripts/Build-GeneXusImportFileEnvelope.ps1` (motor) — monta `import_file.xml` com gate de colisão embutido + gate mecânico de `lastUpdate` (`-AcervoPath` obrigatório; `-ModifiedObjectNames`/`-ModifiedObjectGuids`); Panel via `-TemplatePackagePath`→`-PanelReferencePath`. Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-BuildGeneXusImportFileEnvelopeSelfTest.ps1. Tokens: `BUILD_GENEXUS_IMPORT_FILE_ENVELOPE_SELFTEST_OK`.
- `scripts/New-XpzImportPackage.ps1` (motor; delega ao Python `scripts/New-XpzImportPackage.py`) — empacotamento por frente: lê metadata, classifica raízes Object/Attribute, gate de colisão + gate 9-FD fail-closed; JSON no stdout, `acervoResolvedBy`. Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-NewXpzImportPackage.py, Test-NewXpzImportPackageDriftSelfTest.ps1. Exit: 20.
- `scripts/Test-XpzPackageCollision.ps1` (motor) — gate de colisão de rodada de pacote (consumido pelo envelope e wrappers Test-*KbPackageCollision), `-PackagePath`/`-FrontPrefix`; JSON no stdout. Dono: xpz-builder/SKILL.md; também xpz-msbuild-import-export/SKILL.md. Validação: Test-XpzPackageCollisionSelfTest.ps1. Tokens: `OK: Test-XpzPackageCollisionSelfTest.ps1`. Exit: 0/20.
- `scripts/Test-GeneXusSourceSanity.ps1` (motor) — gate de sanidade mínima de `Source` (`xmlWellFormed`/`sourceSanityStatus`/`probablyImportable`); finding type-aware `procedural-in-conditions` (fail: Procedure com `Conditions` não-vazia → `src0055`). Dono: xpz-builder/SKILL.md; também 08-guia-para-agente-gpt.md, 02. Validação: Test-GeneXusSourceSanitySelfTest.ps1. Tokens: `OK: Test-GeneXusSourceSanitySelfTest.ps1`.
- `scripts/Test-GeneXusFrontAcervoDrift.ps1` (motor) — gate 9-FD drift frente-vs-acervo por `lastUpdate` (`front-older-than-acervo`=fail bloqueia, equals/unparseable=warn, newer/new-object=info); opera sobre frente existente. Dono: xpz-builder/SKILL.md. Validação: via fluxo do empacotamento.
- `scripts/Copy-GeneXusAcervoToFront.ps1` (motor) — resolve drift / seed da frente: copia acervo→frente com bump de `lastUpdate`, `-ObjectList`/`-ObjectNames`/`-ObjectGuids`, `-DryRun`; JSON no stdout. Dono: xpz-builder/SKILL.md; também 02-regras-operacionais-e-runtime.md. Validação: Test-CopyGeneXusAcervoToFrontSelfTest.ps1.
- `Evidência direta`: a frente de geração e empacotamento local passou a registrar a fidelidade textual do delta como verificacao previa ao pacote: copias alteradas em `ObjetosGeradosParaImportacaoNaKbNoGenexus` devem preservar comentarios, `CDATA`, indentacao, linhas em branco, ordem de nos, quebras de linha e whitespace herdado fora do delta aprovado; ruido de reserializacao ou whitespace fora do delta deve bloquear a entrega ate correcao cirurgica ou aprovacao explicita.
- `scripts/Get-GeneXusXpzLastUpdate.ps1` (motor) — timestamp canônico `max(UtcNow+60s, baseline+60s)` com `-BaselineXmlPath`. Dono: xpz-builder/SKILL.md. Validação: via consumidores (Edit-/Set-lastUpdate self-tests).
- `scripts/Edit-GeneXusXmlSurgical.ps1` (motor; usa support-library `scripts/GeneXusXmlSurgicalEditSupport.ps1`) — edição cirúrgica raw de XML (`Replace`/`InsertAfter`, âncora literal, bump `lastUpdate`, backup, restaura em `XML_NOT_WELLFORMED_AFTER`). Dono: xpz-builder/SKILL.md (+ examples/Edit-GeneXusXmlSurgical.example.ps1). Validação: Test-EditGeneXusXmlSurgicalContract.ps1. Tokens: `EDIT_GENEXUS_XML_SURGICAL_CONTRACT_OK`.
- `scripts/Set-GeneXusXmlLastUpdate.ps1` (motor) — re-carimbo in-place do `lastUpdate` (reusa Get-GeneXusXpzLastUpdate + GeneXusXmlSurgicalEditSupport), `-BaselineXmlPath` opcional, `-DryRun`/`-AsJson`. Dono: 08-guia-para-agente-gpt.md; também 02, xpz-builder/SKILL.md, quality-checklist.md. Validação: Test-SetGeneXusXmlLastUpdateSelfTest.ps1.
- `scripts/Test-GeneXusObjectVariableDelta.ps1` (motor) — diagnóstico de variáveis; modo delta por `-VariableName` (fail) e consultivo (varre legado), `-AllowShapeOnlyType`. Dono: xpz-builder/SKILL.md + quality-checklist.md; também 02, 08. Validação: nenhum self-test próprio.
- `scripts/Find-CsAttributeAssignments.ps1` (motor; usa support-library `scripts/GeneXusCsAttributeAssignmentSupport.ps1`) — mapeia atribuições de atributo Transaction no `.cs` web gerado (`AssignAttri`, triplet do Specifier). Dono: responsibilities-by-type/transaction.md; também xpz-msbuild-build/SKILL.md. Validação: Test-FindCsAttributeAssignmentsContract.ps1. Tokens: `FIND_CS_ATTRIBUTE_ASSIGNMENTS_CONTRACT_OK`.
- `Evidência direta`: a base passou a registrar catalogo consultavel de clausulas `on <evento>` e restrições de `Events` em `Transaction` (rejeicoes `src0056`/`spc0150` na trilha XPZ), anti-padroes nomeados em `02-regras-operacionais-e-runtime.md`, rotulos de evidencia para geração XPZ e encaminhamento em `xpz-msbuild-import-export/SKILL.md`, `xpz-msbuild-build/SKILL.md` e `08-guia-para-agente-gpt.md`; fonte canonica do catalogo: `xpz-builder/responsibilities-by-type/transaction.md`; uso correto de linguagem GeneXus permanece em skill **nexa** e documentação de produto.
- `scripts/New-GeneXusXpzFront.ps1` (motor) — abre/reutiliza frente `NomeCurto_GUID_YYYYMMDD` em ObjetosGeradosParaImportacaoNaKbNoGenexus (chamada atômica, devolve GUIDs extras). Dono: xpz-builder/SKILL.md. Validação: nenhum self-test próprio.
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
- `Evidência direta`: a skill `xpz-llm-delegate` incorporou cinco scripts em `scripts/`: `Invoke-OpenCode.ps1` (chamada sincrona ao opencode), `Start-OpenCodeJob.ps1` (disparo assincrono nao-bloqueante) e `Watch-OpenCodeJob.ps1` (monitor incremental do job) como backend opencode; e os de nucleo backend-agnostico `Resolve-OpenCodeModelLocality.ps1` (classifica `local`/`external`/`unknown` pelo `baseURL` do provider na config do opencode, com provedores cloud conhecidos `ollama-cloud/*` e `opencode-go/*` tratados como externos mesmo sem config legivel) e `Resolve-LlmDelegateAuthorization.ps1` (gate de confidencialidade `allow`/`ask`/`deny` combinando `payloadSensitivity` `kb-sensitive`/`public`, localidade e politica por-KB `opencode-delegation-policy.json`). Contrato em `xpz-llm-delegate/SKILL.md`; acionamento sempre humano; juizo estrutural GeneXus nunca e delegado.
- `Evidência direta`: o parsing do stream do opencode foi extraido para o motor compartilhado `scripts/OpenCodeStreamSupport.ps1` (`ConvertFrom-OpenCodeStreamLines`, `Get-OpenCodeStreamErrorMessage`, `Get-OpenCodeTextParts`, `Get-OpenCodeFinalText`, `Get-OpenCodeAllText`), consumido por `Invoke-OpenCode.ps1` e `Watch-OpenCodeJob.ps1` (resposta final = concatenacao das partes da última mensagem; surfacing de erro do stream como BLOCK/`status:error`). Self-tests deterministicos (sem opencode/rede): `scripts/Test-OpenCodeStreamSupportSelfTest.ps1` (sentinela `OK: Test-OpenCodeStreamSupportSelfTest.ps1`), `scripts/Test-OpenCodeModelLocalitySelfTest.ps1` (sentinela `OK: Test-OpenCodeModelLocalitySelfTest.ps1`) e `scripts/Test-LlmDelegateAuthorizationSelfTest.ps1` (sentinela `OK: Test-LlmDelegateAuthorizationSelfTest.ps1`).
- `Evidência direta`: a skill `xpz-llm-delegate` ganhou o backend Codex (#2, `codex exec`, sandbox `read-only` fixo, usando o default da própria ferramenta/config quando `-Model` é omitido) com quatro scripts em `scripts/`: `Invoke-Codex.ps1` (sincrono, prompt via stdin, resposta pelo `output-last-message`), `Start-CodexJob.ps1` (disparo assincrono nao-bloqueante), `Watch-CodexJob.ps1` (monitor incremental do stream `codex exec --json`) e `CodexCliSupport.ps1` (descoberta **fail-closed** do `codex.exe` da app desktop sob `%LOCALAPPDATA%\OpenAI\Codex\bin` pela maior versao, ignorando o shim npm do PATH rejeitado para GPT-5.5; mais a extracao de erro `ERROR: {json}` do stream). O resolvedor de localidade do backend e `scripts/Resolve-CodexModelLocality.ps1` (classifica `local`/`external`/`unknown` pela `config.toml` do Codex — `model`, `model_providers`/`profiles`/`base_url` — ou pelas flags `--oss`/`--local-provider`, e emite `canonicalModel`, a chave de DESTINO ex. `openai/gpt-5.5`). O gate `scripts/Resolve-LlmDelegateAuthorization.ps1` ganhou `-Backend opencode|codex` (default `opencode`, retrocompativel): seleciona o resolvedor e casa a politica por-KB pela **chave de destino** (`canonicalModel`), nunca pelo adapter — logo o Codex com modelo OpenAI explícito ou default da config é governado pelas mesmas entradas `openai/*` do opencode (sem prefixo `codex/`). Self-tests deterministicos novos: `scripts/Test-CodexModelLocalitySelfTest.ps1` (sentinela `OK: Test-CodexModelLocalitySelfTest.ps1`) e `scripts/Test-CodexCliSupportSelfTest.ps1` (sentinela `OK: Test-CodexCliSupportSelfTest.ps1`); o `Test-LlmDelegateAuthorizationSelfTest.ps1` foi estendido com casos `-Backend codex` que provam a unificacao por destino.
- `Evidência direta`: a skill `xpz-llm-delegate` ganhou o backend Claude Code (#3, `claude -p`, consulta curta restrita: prompt por stdin, sem persistência de sessão, `--permission-mode plan`, ferramentas somente leitura `Read,Glob,Grep`, `--max-turns 1` quando o CLI expõe a flag, `bypassPermissions` recusado) com quatro scripts em `scripts/`: `Invoke-ClaudeCode.ps1` (síncrono, `--output-format text`), `Start-ClaudeCodeJob.ps1` (disparo assíncrono não-bloqueante, `--output-format stream-json`, janela oculta + watcher), `Watch-ClaudeCodeJob.ps1` (monitor incremental do stream com gravação de `result.json`) e `ClaudeCodeCliSupport.ps1` (resolve o `claude.exe` do PATH, versão mínima `2.1.118`, valida o contrato de flags exigidas pelo adapter e classifica o status final do job). O resolvedor de localidade do backend é `scripts/Resolve-ClaudeCodeModelLocality.ps1` (destino **Anthropic** sempre `external`; emite a chave de DESTINO `anthropic/<modelo>`, default `claude-opus-4-8`, alias `opus` normalizado, demais aliases nus ficam `unknown`). O gate `scripts/Resolve-LlmDelegateAuthorization.ps1` ganhou `-Backend claude-code`, casando a política por-KB pela chave de destino `anthropic/*`, nunca pelo adapter. Self-tests determinísticos novos: `scripts/Test-ClaudeCodeModelLocalitySelfTest.ps1` (sentinela `OK: Test-ClaudeCodeModelLocalitySelfTest.ps1`) e `scripts/Test-ClaudeCodeCliSupportSelfTest.ps1` (sentinela `OK: Test-ClaudeCodeCliSupportSelfTest.ps1`); o `Test-LlmDelegateAuthorizationSelfTest.ps1` foi estendido com casos `-Backend claude-code`.
- `Evidência direta`: a skill `xpz-llm-delegate` ganhou o backend GitHub Copilot CLI (#4, `copilot -p` em JSONL, síncrono e consultivo) com dois scripts em `scripts/`: `Invoke-Copilot.ps1` (`--output-format json --stream off`, `--no-custom-instructions`, `--disable-builtin-mcps`, conjunto de ferramentas vazio `--available-tools=` com `--allow-all-tools` inócuo; resposta do evento `assistant.message`) e `CopilotCliSupport.ps1` (resolve o comando `copilot` do PATH, versão mínima `1.0.12`, valida o contrato de flags e lê o stream JSONL — `Get-CopilotJsonlFinalText`/`Get-CopilotJsonlExitCode`). O resolvedor de localidade do backend é `scripts/Resolve-CopilotModelLocality.ps1` (sempre `external`; emite a chave de DESTINO `github-copilot/<modelo>`, default `gpt-5-mini`, conscientemente **não** `openai/<modelo>` porque o destino operacional é o serviço do GitHub Copilot). O gate `scripts/Resolve-LlmDelegateAuthorization.ps1` ganhou `-Backend copilot`, casando a política por-KB pela chave `github-copilot/*`. Self-tests determinísticos novos: `scripts/Test-CopilotModelLocalitySelfTest.ps1` (sentinela `OK: Test-CopilotModelLocalitySelfTest.ps1`) e `scripts/Test-CopilotCliSupportSelfTest.ps1` (sentinela `OK: Test-CopilotCliSupportSelfTest.ps1`; cobre o parse do stream JSONL `Get-CopilotJsonlFinalText`/`Get-CopilotJsonlExitCode`, contrato de help e extração de erro); o `Test-LlmDelegateAuthorizationSelfTest.ps1` foi estendido com casos `-Backend copilot`.
- `Evidência direta`: a skill `xpz-llm-delegate` ganhou o backend Gemini CLI (#5, `gemini -p`, síncrono e consultivo) com dois scripts em `scripts/`: `Invoke-Gemini.ps1` (`--approval-mode plan` — somente `plan` aceito —, `--output-format json`, resposta no campo `.response` do JSON) e `GeminiCliSupport.ps1` (resolve o comando `gemini` do PATH, versão mínima `0.35.3`, valida o contrato de flags). O resolvedor de localidade do backend é `scripts/Resolve-GeminiModelLocality.ps1` (sempre `external`; emite a chave de DESTINO `google/<modelo>`, default `gemini-3-flash-preview`). O gate `scripts/Resolve-LlmDelegateAuthorization.ps1` ganhou `-Backend gemini`, casando a política por-KB pela chave `google/*`. Self-tests determinísticos novos: `scripts/Test-GeminiModelLocalitySelfTest.ps1` (sentinela `OK: Test-GeminiModelLocalitySelfTest.ps1`) e `scripts/Test-GeminiCliSupportSelfTest.ps1` (sentinela `OK: Test-GeminiCliSupportSelfTest.ps1`; cobre parse de versão, contrato de help e extração de erro); o `Test-LlmDelegateAuthorizationSelfTest.ps1` foi estendido com casos `-Backend gemini`.
- `Evidência direta`: o arquivo de política de delegação ganhou nome canônico `llm-delegation-policy.json` com fallback ao legado `opencode-delegation-policy.json` (aceito indefinidamente; o arquivo governa os cinco backends por chave de destino, então o nome de um backend era apenas histórico). Novo resolvedor `scripts/Resolve-LlmDelegationPolicyPath.ps1` (recebe `-ParallelKbRoot`; devolve o caminho efetivo — canônico com fallback ao legado —, `status` `new|legacy|both|none`, `deprecatedNameInUse` e `exists`; só resolve caminho, não lê nem grava). O gate `scripts/Resolve-LlmDelegateAuthorization.ps1` ganhou `-ParallelKbRoot` (aditivo): com `-PolicyPath` omitido, descobre a política via esse resolvedor e expõe `policyFileName`/`policyNameStatus`; `-PolicyPath` explícito prevalece (retrocompatível). O `xpz-kb-parallel-setup` grava com o nome canônico e oferece renomear o legado quando presente. Self-test determinístico novo: `scripts/Test-LlmDelegationPolicyPathSelfTest.ps1` (sentinela `OK: Test-LlmDelegationPolicyPathSelfTest.ps1`; cobre `new`/`legacy`/`both`/`none`); o `Test-LlmDelegateAuthorizationSelfTest.ps1` foi estendido com casos `-ParallelKbRoot`.
- `Evidência direta`: os adapters **argument-based** da `xpz-llm-delegate` (`Invoke-OpenCode.ps1`, `Start-OpenCodeJob.ps1`, `Invoke-Gemini.ps1`, `Invoke-Copilot.ps1`) passaram a **fechar o stdin do CLI** no runner temporário (`$null | & ([string]$req.exe) @args`, `$null` = EOF puro): sem isso, chamados de uma shell headless sem TTY (a ferramenta de um agente), o CLI agêntico travava lendo o stdin herdado — medido: o opencode pendurava por minutos; com o stdin fechado completa em ~8s (síncrono e assíncrono provados). Os adapters **stdin-based** (`Invoke-Codex`/`Start-CodexJob`, `Invoke-ClaudeCode`/`Start-ClaudeCodeJob`) **não** fecham o stdin — entregam o prompt via `Start-Process -RedirectStandardInput`. As sondas `--version`/`--help` dos `*CliSupport` foram **medidas** em headless (`gemini --version` ~7.5s, `copilot --version` ~3.4s) e **não** penduram (não leem stdin), portanto **não** alteradas. O mecanismo depende do runner ser `pwsh -File`. Self-test determinístico novo `scripts/Test-LlmDelegateStdinHandlingSelfTest.ps1` (sentinela `OK: Test-LlmDelegateStdinHandlingSelfTest.ps1`): prova comportamental (fake-exe que bloqueia em stdin aberto e sai 7 ao receber EOF, com limpeza de árvore de processo) + guard estático (argument-based fecham o stdin; stdin-based usam `-RedirectStandardInput`). Contrato em `xpz-llm-delegate/SKILL.md` (`## LIMITE CONHECIDO — STDIN FECHADO NOS ADAPTERS ARGUMENT-BASED (HEADLESS)`).

- `Evidência direta`: a skill `xpz-skills-setup` incorporou scripts de setup e auditoria em `scripts/`. Bootstrap de repositório: `Initialize-XpzSkillsRepoGit.ps1` liga pasta baixada como ZIP ao remoto oficial (`git init` + `remote` + `fetch` + `reset --mixed origin/main`), instala Git por `winget` quando ausente e tem gate anti-destrutivo (`GIT_LINKED_WITH_DRIFT` só alinha o working tree via `-AlignToOfficial`); self-test `Test-XpzSkillsRepoGitSelfTest.ps1`. Auditoria de registro: `Test-XpzSkillsRegistration.ps1` (somente leitura) classifica cada skill x ferramenta em `OK`/`coberta_por_compatibilidade`/`ausente`/`orfa`/`quebrada`, detecta orfas e o freshness do MCP global do Cursor por hash (`MCP_OK`/`MCP_SERVER_STALE`/`MCP_CONFIG_INVALID`/`MCP_NOT_INSTALLED`); `overall` `REGISTRATION_OK`/`REGISTRATION_GAPS`; self-test `Test-XpzSkillsRegistrationSelfTest.ps1`. Auditoria de instrucionais globais: `Test-XpzGlobalInstructions.ps1` + contrato `xpz-global-instructions-topics.psd1` resolve a fonte efetiva por ferramenta (segue `@<caminho>`, `instructions[]` do OpenCode e o `agentsPath` do MCP do Cursor) e sinaliza a cobertura dos topicos minimos de forma conservadora (`presente`/`nao_detectado`); `overall` `GLOBAL_INSTRUCTIONS_OK`/`GLOBAL_INSTRUCTIONS_REVIEW`; self-test `Test-XpzGlobalInstructionsSelfTest.ps1` cobre deteccao e paridade contrato↔`SKILL.md`. Instalador do MCP global do Cursor (frente anterior da mesma skill): `Install-CursorGlobalInstructionsMcp.ps1` + `cursor-global-instructions-mcp/server.py` (servidor MCP stdio que serve o `AGENTS.md` efetivo ao Cursor, com merge em `mcp.json` preservando outros servidores). Skill externa gerenciada (`nexa`): `Initialize-NexaRepoGit.ps1` faz o bootstrap do repositório que hospeda a `nexa` (`genexuslabs/genexus-skills`), com deteccao do clone existente via vinculo global, clone quando ausente (capacidade que o bootstrap XPZ proibe de proposito), origin oficial tolerando remotos extras (ex.: `fork`) e gate `NEXA_DIR_NOT_REPO` anti-sobrescrita (labels `NEXA_ALREADY_LINKED`/`NEXA_ORIGIN_ADDED`/`NEXA_REPO_CLONED`/`NEXA_REMOTE_MISMATCH`); self-test `Test-NexaRepoGitSelfTest.ps1`. O motor `Test-XpzSkillsRegistration.ps1` foi estendido para classificar também a `nexa` em seção separada (`externalSkills`/`externalOverall` `EXTERNAL_SKILLS_OK`/`EXTERNAL_SKILLS_GAPS`, independente de `overall`), só a `nexa` por nome — demais skills do repo externo (ex.: `gx-sap`) ficam dormentes. Contrato em `xpz-skills-setup/SKILL.md`; os motores não criam/removem vinculos nem gravam instrucionais — as ações de resolucao são manuais, sob confirmacao explicita.

- `Evidência direta`: a skill `xpz-kb-parallel-pre-push` (rotina pré-push de **pasta paralela de KB**, distinta da pré-push do repositório de skills do documento `13`) opera sobre motores compartilhados em `scripts/`: orquestrador `Invoke-XpzKbParallelPrePushPhase1.ps1` (gates G0–G5 + K1–K4/K8/K9/K11; JSON de máquina por padrão; consolida `pushReadiness` (`ready`/`warn`/`blocked`) com exit 0 ready / 2 warn / 1 blocked; `unknown`⇒`blocked` fail-closed; descoberta de wrapper K8/K9 por `kb-parallel-pre-push.config.json` → convenção → fail-closed, com 4 desfechos `config|convention|none|ambiguous`); e os motores `Test-XpzKbDangerousPaths.ps1` (K1/K2, paths perigosos), `Test-XpzKbLayerDiff.ps1` (K3/K4, camadas derivada/oficial), `Test-XpzNotNotIsAntipattern.ps1` (K11, antipattern `not not X.IsXxx()`), `Test-XpzKbFrenteHygiene.ps1` (Fase 2a, higiene de frente/pacote), `Compare-XpzChecksums.ps1` (F1, classificador SAME/DIFF/NEW/DELETED) e `Test-XpzKbIndexGate.ps1` (K9, contrato estruturado `-AsJson`). O K8 consome `Test-XpzSetupAudit.ps1 -AsJson`. `Test-XpzKbIndexGate.ps1` faz parte do `xpz-kb-parallel-setup/setup-contract.manifest.json` por ser motor compartilhado consumido pela via K8/K9. Pasta da skill: `SKILL.md` enxuto + satélites `fase1-mecanica`/`fase2a-estrutural`/`fase2b-classificador-de-regime` + `agents/openai.yaml` + `examples/` (wrapper fino, config com `layerTokens`, catálogo de padrões aceitos por-KB, moldes de relatório).
- `Evidência direta`: a rotina pré-push de pasta paralela ganhou 8 self-tests deterministas em `scripts/` mais o helper `XpzKbPrePushSelfTestSupport.ps1` (monta repos git de fixture e isola o `exit` do motor em pwsh-filho): `Test-XpzKbDangerousPathsSelfTest.ps1` (sentinela `XPZ_KB_DANGEROUS_PATHS_SELFTEST_OK`), `Test-XpzKbLayerDiffSelfTest.ps1` (`XPZ_KB_LAYER_DIFF_SELFTEST_OK`), `Test-XpzNotNotIsAntipatternSelfTest.ps1` (`XPZ_NOT_NOT_ANTIPATTERN_SELFTEST_OK`), `Test-XpzKbFrenteHygieneSelfTest.ps1` (`XPZ_KB_FRENTE_HYGIENE_SELFTEST_OK`), `Test-XpzChecksumCompareSelfTest.ps1` (`XPZ_CHECKSUM_COMPARE_SELFTEST_OK`), `Test-XpzKbIndexGateContractSelfTest.ps1` (`XPZ_KB_INDEX_GATE_CONTRACT_SELFTEST_OK`; prova que sob `-AsJson` o gate nunca lança e o bloqueio vira `{status:BLOCK}` estruturado), `Test-XpzSetupAuditContractSelfTest.ps1` (`XPZ_SETUP_AUDIT_CONTRACT_SELFTEST_OK`; contrato `-AsJson` do K8 — campo `estado_operacional_sugerido`, estados bloqueantes `runtime_powershell_bloqueado`/`auditoria_incompleta`) e `Test-XpzKbParallelPrePushPhase1SelfTest.ps1` (`XPZ_KB_PREPUSH_PHASE1_SELFTEST_OK`; 10 cenários do orquestrador: ready, K8 red, K9 block, wrapper none/ambiguous, BaseRef inválido, commitsBehind, fetch fail, G5 broken, K11 fires). Sentinela em CAIXA-ALTA (padrão dominante deste inventário).

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
- `Evidência direta`: `scripts/Start-GeneXusKbBuildDetached.ps1` (skill `xpz-msbuild-build`) é o orquestrador **opt-in** do modo desacoplado de build longo: registra uma Tarefa Agendada one-shot (console **oculto**, `-WindowStyle Hidden`) que executa `Invoke-GeneXusKbBuildAll.ps1` fora da sessão do agente (sob `svchost` do Scheduler — sobrevive a fechar janela/app, validado empiricamente na FabricaBrasil18) e sinaliza a conclusão por arquivo-sentinela (`{ done, exitCode, logPath, logExists, error, stdoutPath, stderrPath, finishedAt }`, escrita atômica `.tmp`+rename; `logExists`/`error` distinguem conclusão do wrapper de falha antes de escrever o log). Repassa os parâmetros ao wrapper por **hashtable splatting** (array splatting desalinha o binding). Não altera o wrapper de build (apenas o invoca) e é transporte, não autoridade de política — os gates de reorg/rebuild/opções caras permanecem no wrapper; modo desacoplado v1 não usa watcher (`timing.phases` vazio). Sobrevive a fechar janela/app mas **não** a logoff (tarefa `LogonType Interactive`); modo `S4U`/Password não oferecido por decisão consciente (credenciais + dependência do contexto interativo). Self-test: `scripts/Test-StartGeneXusKbBuildDetachedContract.ps1`. Contrato e fluxo em `xpz-msbuild-build/SKILL.md`; exit codes próprios (0, 46, 90) em `scripts/msbuild-exit-codes.catalog.json`.
- `Evidência direta`: `scripts/Wait-GeneXusKbBuildDetached.ps1` (skill `xpz-msbuild-build`) é o helper de **espera** do modo desacoplado: combina os dois sinais — sentinela (`done=true`) e heartbeat da Tarefa Agendada via `Get-ScheduledTask` (`State`) — com margem de corrida e timeout, para o consumidor não ficar preso quando o processo da tarefa morre de forma dura (kill/OOM/estouro de `-ExecutionTimeLimit`) antes de escrever a sentinela. Somente leitura; retorna `outcome` (`concluido`/`falha-anomala`/`timeout`) com exit 0/70/71 (registrados em `scripts/msbuild-exit-codes.catalog.json`, categoria `espera-desacoplada`, com nota de que o helper não invoca MSBuild). Self-test: `scripts/Test-WaitGeneXusKbBuildDetachedContract.ps1`.
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
