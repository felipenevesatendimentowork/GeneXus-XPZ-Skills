#requires -Version 7.4
<#
.SYNOPSIS
    Bateria minima para Get-GeneXusImportPackageObjectInventory.ps1 (XML e .xpz sintetico).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$inventoryScript = Join-Path $scriptDir 'Get-GeneXusImportPackageObjectInventory.ps1'
# Export real GeneXus 18: modulos SDK/plataforma entram como PackagedModule, nao Module.
$packagedModuleGuid = 'c88fffcd-b6f8-0000-8fec-00b5497e2117'
$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-import-inventory-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$exportXml = @"
<ExportFile>
  <Objects>
    <Object type="$packagedModuleGuid" name="GeneXus" guid="11111111-1111-1111-1111-111111111101" />
    <Object type="$procedureGuid" name="ProcPedida" guid="11111111-1111-1111-1111-111111111102" />
    <Object type="$procedureGuid" name="ProcExtra" guid="11111111-1111-1111-1111-111111111103" />
  </Objects>
  <Attributes>
    <Attribute name="AttrA" guid="22222222-2222-2222-2222-222222222201" />
    <Attribute name="AttrB" guid="22222222-2222-2222-2222-222222222202" />
  </Attributes>
</ExportFile>
"@

$xmlPath = Join-Path $tempRoot 'package.import_file.xml'
[System.IO.File]::WriteAllText($xmlPath, $exportXml, [System.Text.UTF8Encoding]::new($false))

$result = (& $inventoryScript -InputPath $xmlPath -DeclaredDeltaItems 'Procedure:ProcPedida' -AsJson | ConvertFrom-Json)
if ($result.objectCount -ne 3) { throw "objectCount esperado 3; obtido $($result.objectCount)" }
if ($result.attributeCount -ne 2) { throw 'attributeCount esperado 2' }
if (-not $result.selectiveExport) { throw 'selectiveExport esperado true' }
if ($result.status -ne 'DELTA_MISMATCH') { throw "status esperado DELTA_MISMATCH; obtido $($result.status)" }
if ($result.deltaComparison.extraCount -ne 2) {
    throw "extraCount esperado 2 (PackagedModule:GeneXus + ProcExtra); obtido $($result.deltaComparison.extraCount)"
}
if (@($result.systemModulesPresent).Count -ne 1) {
    throw "systemModulesPresent esperado 1 (PackagedModule:GeneXus); obtido $(@($result.systemModulesPresent).Count)"
}
if ($result.systemModulesPresent[0] -ne 'GeneXus') { throw 'modulo sistema esperado GeneXus' }
$genexusItem = @($result.inventory | Where-Object { $_.name -eq 'GeneXus' } | Select-Object -First 1)
if ($genexusItem.typeName -ne 'PackagedModule') {
    throw "tipo esperado PackagedModule para GeneXus; obtido $($genexusItem.typeName)"
}
if ($result.inputKind -ne 'xml') { throw 'inputKind xml esperado' }

$xpzPath = Join-Path $tempRoot 'package.xpz'
Compress-Archive -LiteralPath $xmlPath -DestinationPath $xpzPath -Force
$resultXpz = (& $inventoryScript -InputPath $xpzPath -DeclaredDeltaItems 'Procedure:ProcPedida' -AsJson | ConvertFrom-Json)
if ($resultXpz.inputKind -ne 'xpz') { throw 'inputKind xpz esperado' }
if ($resultXpz.objectCount -ne 3) { throw 'objectCount xpz esperado 3' }
if (@($resultXpz.systemModulesPresent).Count -ne 1) { throw 'systemModulesPresent xpz esperado 1' }

$full = (& $inventoryScript -InputPath $xmlPath -AsJson | ConvertFrom-Json)
if ($full.selectiveExport) { throw 'selectiveExport deve ser false sem delta' }
if ($null -ne $full.deltaComparison) { throw 'deltaComparison deve ser nulo sem delta' }

Remove-Item -LiteralPath $tempRoot -Recurse -Force
Write-Output 'GENEXUS_PKG_INVENTORY_SELFTEST_OK'
