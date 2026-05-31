#requires -Version 7.4
<#
.SYNOPSIS
    Gate de gravabilidade por Transaction (fachada do nucleo canonico Python).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TransactionPath,

    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusTransactionWritabilitySupport.ps1')

if (-not (Test-Path -LiteralPath $TransactionPath -PathType Leaf)) {
    throw "TransactionPath nao encontrado ou nao e arquivo: $TransactionPath"
}
if (-not (Test-Path -LiteralPath $CorpusFolder -PathType Container)) {
    throw "CorpusFolder nao encontrado ou nao e diretorio: $CorpusFolder"
}

$TransactionPath = (Resolve-Path -LiteralPath $TransactionPath).Path
$CorpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path
$catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Catalogo de tipos nao encontrado: $catalogPath"
}

$result = Invoke-GeneXusTransactionWritabilityClassify `
    -TransactionPath $TransactionPath `
    -CorpusFolder $CorpusFolder `
    -CatalogPath $catalogPath

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $($result.status)"
    Write-Output "transactionName: $($result.transactionName)"
    Write-Output "coverage: $($result.coverage)"
    $levelAttributes = @($result.levelAttributes)
    Write-Output "levelAttributes: $($levelAttributes.Count)"
    foreach ($a in $levelAttributes) {
        $w = if ($null -eq $a.writable) { 'null' } else { $a.writable }
        Write-Output "  [$($a.levelName)] $($a.attributeName) key=$($a.key) -> $($a.classification) (writable=$w)"
    }
}
