#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$contractPath = Join-Path $PSScriptRoot 'GeneXusKbIntelligenceExtractorContract.ps1'
if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "GeneXusKbIntelligenceExtractorContract.ps1 nao encontrado: $contractPath"
}
. $contractPath

$expected = Get-GeneXusKbIntelligenceExpectedExtractorSignature
if ([string]::IsNullOrWhiteSpace($expected.extractor_signature_version)) {
    throw 'Versao esperada do extrator vazia'
}
if ($expected.extractor_signature_hash.Length -ne 64) {
    throw "Hash esperado deve ter 64 hex chars; obtido: $($expected.extractor_signature_hash.Length)"
}

$okResult = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata @{
    extractor_signature_version = $expected.extractor_signature_version
    extractor_signature_hash    = $expected.extractor_signature_hash
}
if (-not $okResult.ok) {
    throw "Assinatura esperada deveria passar: $($okResult.summary)"
}

$missingResult = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata @{}
if ($missingResult.ok) {
    throw 'Metadata vazia deveria falhar'
}
if ($missingResult.reason -ne 'indice_sem_assinatura_extrator') {
    throw "reason incorreto: $($missingResult.reason)"
}

$versionResult = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata @{
    extractor_signature_version = '0'
    extractor_signature_hash    = $expected.extractor_signature_hash
}
if ($versionResult.ok -or $versionResult.reason -ne 'extrator_version_defasada') {
    throw 'Versao defasada deveria falhar com extrator_version_defasada'
}

Write-Output 'KB_INTELLIGENCE_EXTRACTOR_SIGNATURE_SELFTEST_OK'
