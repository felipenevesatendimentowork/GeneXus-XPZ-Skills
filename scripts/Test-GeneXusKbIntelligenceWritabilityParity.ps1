#requires -Version 7.4
<#
.SYNOPSIS
    Exige paridade entre Test-GeneXusTransactionWritability.ps1 e consultas do índice materializado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [Parameter(Mandatory = $true)]
    [string]$IndexPath,

    [int]$MaxTransactions = 0,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$corpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path
$indexPath = (Resolve-Path -LiteralPath $IndexPath).Path

if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw "IndexPath nao encontrado: $indexPath"
}

$writabilityScript = Join-Path $scriptDir 'Test-GeneXusTransactionWritability.ps1'
$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'

$txFolder = Join-Path $corpusFolder 'Transaction'
if (-not (Test-Path -LiteralPath $txFolder -PathType Container)) {
    throw "Pasta Transaction ausente em CorpusFolder: $txFolder"
}

$txFiles = @(Get-ChildItem -LiteralPath $txFolder -Filter '*.xml' -File | Sort-Object Name)
if ($MaxTransactions -gt 0) {
    $txFiles = @($txFiles | Select-Object -First $MaxTransactions)
}

$failures = [System.Collections.Generic.List[string]]::new()
$checked = 0

foreach ($txFile in $txFiles) {
    $gateJson = & $writabilityScript -TransactionPath $txFile.FullName -CorpusFolder $corpusFolder -AsJson | ConvertFrom-Json
    if ($gateJson.status -ne 'pass') {
        $failures.Add("Gate status nao pass para $($txFile.Name): $($gateJson.status)")
        continue
    }
    $txName = [string]$gateJson.transactionName
    if ([string]::IsNullOrWhiteSpace($txName)) {
        $failures.Add("transactionName vazio para $($txFile.Name)")
        continue
    }

    $indexJsonText = & python $queryScript `
        --index-path $indexPath `
        --query transaction-attributes `
        --object-name $txName `
        --format json
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Query transaction-attributes falhou para $txName (exit $LASTEXITCODE)")
        continue
    }
    $indexJson = $indexJsonText | ConvertFrom-Json
    if (-not $indexJson.found) {
        $failures.Add("Indice nao encontrou Transaction $txName")
        continue
    }

    $indexMap = @{}
    foreach ($row in @($indexJson.results)) {
        $key = ("{0}`0{1}" -f $row.levelName, $row.attribute)
        $indexMap[$key] = $row
    }

    foreach ($gateRow in @($gateJson.levelAttributes)) {
        $checked++
        $key = ("{0}`0{1}" -f $gateRow.levelName, $gateRow.attributeName)
        if (-not $indexMap.ContainsKey($key)) {
            $failures.Add("Indice sem linha para $txName :: $key")
            continue
        }
        $indexRow = $indexMap[$key]
        if ([string]$indexRow.classification -ne [string]$gateRow.classification) {
            $failures.Add(
                "classification divergente em $txName [$($gateRow.attributeName)]: gate=$($gateRow.classification) index=$($indexRow.classification)"
            )
        }
        $gateWritable = $gateRow.writable
        $indexWritable = $indexRow.writable
        $gateIsNull = $null -eq $gateWritable
        $indexIsNull = $null -eq $indexWritable
        if ($gateIsNull -ne $indexIsNull) {
            $failures.Add(
                "writable nullability divergente em $txName [$($gateRow.attributeName)]: gate=$gateWritable index=$indexWritable"
            )
        } elseif (-not $gateIsNull -and [bool]$gateWritable -ne [bool]$indexWritable) {
            $failures.Add(
                "writable divergente em $txName [$($gateRow.attributeName)]: gate=$gateWritable index=$indexWritable"
            )
        }
    }
}

$report = [pscustomobject]@{
    status            = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
    corpusFolder      = $corpusFolder
    indexPath         = $indexPath
    transactions      = $txFiles.Count
    attributePairs    = $checked
    failureCount      = $failures.Count
    failures          = @($failures)
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $($report.status)"
    Write-Output "transactions: $($report.transactions)"
    Write-Output "attributePairs: $($report.attributePairs)"
    Write-Output "failureCount: $($report.failureCount)"
    foreach ($failure in $report.failures) {
        Write-Output "  $failure"
    }
}

if ($report.status -ne 'pass') {
    exit 2
}
exit 0
