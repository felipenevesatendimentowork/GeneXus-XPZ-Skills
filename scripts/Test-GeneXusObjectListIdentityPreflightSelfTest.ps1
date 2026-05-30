#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$preflightPath = Join-Path $PSScriptRoot 'GeneXusObjectListIdentityPreflight.ps1'
. $preflightPath

if (-not (Test-IsSelectiveGeneXusXpzExport -ObjectList 'Procedure:A' -ExportAll 'false' -FullExportRequested $false)) {
    throw 'Esperava export seletivo com ObjectList'
}

if (Test-IsSelectiveGeneXusXpzExport -ObjectList '' -ExportAll 'true' -FullExportRequested:$false) {
    throw 'ExportAll nao deveria ser seletivo'
}

$catalogResolved = Resolve-GeneXusObjectTypeCatalogPaths -ParallelKbRoot $null
$wwType = Resolve-GeneXusCatalogTypeForExportLabel -MergedCatalog $catalogResolved.MergedCatalog -ExportLabel 'WorkWith'
if ($wwType -ne 'WorkWithForWeb') {
    throw "Esperava WorkWith -> WorkWithForWeb no catalogo; obtido: $wwType"
}

$blocked = Invoke-GeneXusObjectListIdentityPreflight `
    -ObjectList 'Procedure:Demo' `
    -ExportAll 'false' `
    -FullExportRequested $false

if (-not $blocked.block -or $blocked.exitCode -ne 35) {
    throw 'Export seletivo sem ParallelKbRoot/IndexPath deveria bloquear com exit 35'
}

$items = @(Read-GeneXusObjectListItemsFromText -Text 'Procedure:A;WebPanel:B')
if ($items.Count -ne 2) {
    throw "Esperava 2 itens parseados; obtido: $($items.Count)"
}

Write-Output 'OBJECT_LIST_IDENTITY_PREFLIGHT_SELFTEST_OK'
