#requires -Version 7.4
<#
.SYNOPSIS
    Self-test minimo para extracao de chamadas em Property Formula de Attribute no KbIntelligence.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-attr-formula-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$procedureDir = Join-Path $objetosPath 'Procedure'
$attributeDir = Join-Path $objetosPath 'Attribute'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $procedureDir, $attributeDir, $kbIntelDir -Force)

$procCalleeXml = @"
<Object type="$procedureGuid" name="procFormulaCallee" guid="11111111-1111-1111-1111-111111111101">
  <Source><![CDATA[]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'procFormulaCallee.xml'), $procCalleeXml, (New-Object System.Text.UTF8Encoding($false)))

$attrDirectXml = @"
<Attribute name="AttrCalcFormula" guid="22222222-2222-2222-2222-222222222201">
  <Properties>
    <Property><Name>Formula</Name><Value>procFormulaCallee(0)</Value></Property>
  </Properties>
</Attribute>
"@
$attrDotCallXml = @"
<Attribute name="AttrCalcFormulaDotCall" guid="22222222-2222-2222-2222-222222222202">
  <Properties>
    <Property><Name>Formula</Name><Value>procFormulaCallee.Call(0)</Value></Property>
  </Properties>
</Attribute>
"@
$attrPlainXml = @"
<Attribute name="AttrPlain" guid="22222222-2222-2222-2222-222222222203">
  <Properties>
    <Property><Name>idBasedOn</Name><Value>Domain:Character</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrCalcFormula.xml'), $attrDirectXml, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrCalcFormulaDotCall.xml'), $attrDotCallXml, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrPlain.xml'), $attrPlainXml, (New-Object System.Text.UTF8Encoding($false)))

$sqlitePath = Join-Path $kbIntelDir 'kb-intelligence.sqlite'
$validationPath = Join-Path $kbIntelDir 'kb-intelligence-validation.json'
$validationCases = Join-Path $scriptDir 'kb-intelligence-attribute-formula.validation-extraction.json'
$indexScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'

& $indexScript `
    -SourceRoot $objetosPath `
    -OutputPath $sqlitePath `
    -ValidationReportPath $validationPath `
    -ValidationCasesPath $validationCases `
    -FailOnValidationFailure `
    -ParallelKbRoot $parallelRoot
if ($LASTEXITCODE -ne 0) {
    throw "Build-KbIntelligenceIndex falhou no self-test de Formula; exit $LASTEXITCODE"
}

$report = Get-Content -LiteralPath $validationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$failed = @($report.cases | Where-Object { $_.status -ne 'passed' })
if ($failed.Count -gt 0) {
    throw "Casos de validacao falharam: $($failed.id -join ', ')"
}

$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'
$whoUsesJson = & python $queryScript --index-path $sqlitePath --query who-uses --object-type Procedure --object-name procFormulaCallee --format json
if ($LASTEXITCODE -ne 0) {
    throw "who-uses falhou; exit $LASTEXITCODE"
}
$whoUses = $whoUsesJson | ConvertFrom-Json
$attributeSources = @(
    $whoUses.results |
        Where-Object { $_.source_type -eq 'Attribute' } |
        ForEach-Object { "$($_.source_type):$($_.source_name)" }
)
if ($attributeSources.Count -lt 2) {
    throw "who-uses de procFormulaCallee deveria listar pelo menos 2 Attributes; obtido: $($attributeSources -join ', ')"
}

Write-Output 'OK: Test-KbIntelligenceAttributeFormulaExtractionSelfTest.ps1'
exit 0
