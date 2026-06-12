#requires -Version 7.4
<#
.SYNOPSIS
Gate de compatibilidade do índice KbIntelligence (estrutura, frescor, inventario e assinatura do extrator).

.DESCRIPTION
Verifica sequencialmente: estrutura da pasta paralela via Test-*KbStructure.ps1,
pasta KbIntelligence, kb-intelligence.sqlite, wrapper local de consulta,
index-metadata (last_index_build_run_at, inventory_validation_status literal OK),
kb-source-metadata.md com last_xpz_materialization_run_at, comparacao de timestamps
(last_index_build_run_at >= last_xpz_materialization_run_at) e assinatura do extrator
(extractor_signature_version/extractor_signature_hash na metadata do SQLite contra
scripts/Build-KbIntelligenceIndex.py do repositório ativo via
scripts/GeneXusKbIntelligenceExtractorContract.ps1 em SharedSkillsRoot).
Retorna GATE_OK em stdout quando o índice está apto, ou lanca exceção com BLOCK: <motivo>.

Deve ser o único ponto de execução do gate da pasta paralela da KB.
Dependencias: Query-KbIntelligence.ps1 e Test-KbStructure.ps1 na mesma pasta.

.PARAMETER QueryWrapperPath
Caminho opcional para o wrapper local de consulta do índice.
Quando omitido, usa Query-KbIntelligence.ps1 na mesma pasta deste script.

.PARAMETER StructureWrapperPath
Caminho opcional para o wrapper local de verificacao de estrutura.
Quando omitido, usa Test-KbStructure.ps1 na mesma pasta deste script.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills` (motor do extrator em `scripts/`).

.EXAMPLE
.\Test-KbIndexGate.ps1

.EXAMPLE
& (Join-Path $kbRoot 'scripts\Test-FabricaBrasilKbIndexGate.ps1')
#>

param(
    [string]$QueryWrapperPath,
    [string]$StructureWrapperPath,

    [string]$SharedSkillsRoot = 'C:\CAMINHO\PARA\GeneXus-XPZ-Skills'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$indexDir = Join-Path $repoRoot 'KbIntelligence'
$indexPath = Join-Path $indexDir 'kb-intelligence.sqlite'
$sourceMetadata = Join-Path $repoRoot 'kb-source-metadata.md'

if (-not $QueryWrapperPath) {
    $QueryWrapperPath = Join-Path $PSScriptRoot 'Query-KbIntelligence.ps1'
}

if (-not $StructureWrapperPath) {
    $StructureWrapperPath = Join-Path $PSScriptRoot 'Test-KbStructure.ps1'
}

if (-not (Test-Path -LiteralPath $StructureWrapperPath -PathType Leaf)) {
    throw 'BLOCK: wrapper local de estrutura ausente'
}
$structureOutput = & $StructureWrapperPath *>&1
$structureText = ($structureOutput | Where-Object { $_ -is [string] } | Out-String)
$structureWarnings = @($structureOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
foreach ($w in $structureWarnings) { Write-Warning $w.Message }
if ((-not $?) -or $structureText -notmatch 'STRUCTURE_OK') {
    throw "BLOCK: estrutura da pasta paralela falhou: $($structureText.Trim())"
}

if (-not (Test-Path -LiteralPath $indexDir -PathType Container)) {
    throw 'BLOCK: pasta KbIntelligence ausente'
}
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw 'BLOCK: KbIntelligence\kb-intelligence.sqlite ausente'
}
if (-not (Test-Path -LiteralPath $QueryWrapperPath -PathType Leaf)) {
    throw 'BLOCK: wrapper local de consulta ausente'
}

$indexMetadata = & $QueryWrapperPath -Query index-metadata -Format text
$indexMetadataText = ($indexMetadata | Out-String)
if ([string]::IsNullOrWhiteSpace($indexMetadataText) -or ($indexMetadataText -notmatch 'last_index_build_run_at')) {
    throw 'BLOCK: index-metadata ausente ou sem last_index_build_run_at'
}
if ($indexMetadataText -notmatch 'inventory_validation_status') {
    throw 'BLOCK: index-metadata ausente ou sem inventory_validation_status'
}

if (-not (Test-Path -LiteralPath $sourceMetadata -PathType Leaf)) {
    throw 'BLOCK: kb-source-metadata.md ausente'
}
$sourceMaterialization = Select-String -LiteralPath $sourceMetadata -Pattern 'last_xpz_materialization_run_at' -SimpleMatch
if (-not $sourceMaterialization) {
    throw 'BLOCK: kb-source-metadata.md sem last_xpz_materialization_run_at'
}

$indexMatch = [regex]::Match($indexMetadataText, 'last_index_build_run_at\s*[:=]\s*(?<value>\S+)')
$sourceMatch = [regex]::Match($sourceMaterialization.Line, 'last_xpz_materialization_run_at\s*[:=]\s*(?<value>\S+)')
if (-not $indexMatch.Success) {
    throw 'BLOCK: index-metadata sem valor parseavel de last_index_build_run_at'
}
if (-not $sourceMatch.Success) {
    throw 'BLOCK: kb-source-metadata.md sem valor parseavel de last_xpz_materialization_run_at'
}

$lastIndexBuild = [datetimeoffset]::Parse($indexMatch.Groups['value'].Value)
$lastXpzMaterialization = [datetimeoffset]::Parse($sourceMatch.Groups['value'].Value)
if ($lastIndexBuild -lt $lastXpzMaterialization) {
    throw 'BLOCK: indice defasado em relacao a last_xpz_materialization_run_at'
}

$inventoryStatusMatch = [regex]::Match($indexMetadataText, 'inventory_validation_status\s*[:=]\s*(?<value>\S+)')
if (-not $inventoryStatusMatch.Success) {
    throw 'BLOCK: index-metadata sem valor parseavel de inventory_validation_status'
}
if ($inventoryStatusMatch.Groups['value'].Value -ne 'OK') {
    throw 'BLOCK: indice com inventario semantico invalido ou pendente'
}

$extractorContractPath = Join-Path $SharedSkillsRoot 'scripts\GeneXusKbIntelligenceExtractorContract.ps1'
if (-not (Test-Path -LiteralPath $extractorContractPath -PathType Leaf)) {
    throw "BLOCK: contrato de assinatura do extrator ausente: $extractorContractPath"
}
. $extractorContractPath

$indexMetadataMap = Get-GeneXusKbIntelligenceExtractorSignatureFromIndexMetadataText -IndexMetadataText $indexMetadataText
$extractorCheck = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata $indexMetadataMap
if (-not $extractorCheck.ok) {
    throw ('BLOCK: {0}' -f $extractorCheck.summary)
}

('extractor_signature_version: {0}' -f $extractorCheck.stored.extractor_signature_version)
('extractor_signature_hash: {0}' -f $extractorCheck.stored.extractor_signature_hash)
'inventory_validation_status: OK'
'GATE_OK'
