#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do gate Test-GeneXusSourceSanity.ps1, foco na regra type-aware
    procedural-in-conditions (Procedure + parte Conditions nao-vazia).

.DESCRIPTION
    Cobre:
    (1) positivo  — Procedure (84a12160) com parte Conditions (763f0d8b) nao-vazia -> fail;
    (2) negativo  — Procedure com Conditions vazia (CDATA vazio) -> nao dispara;
    (3) negativo  — Procedure com Conditions whitespace-only -> nao dispara (skip antes da regra);
    (4) negativo  — Procedure SEM a parte Conditions -> nao dispara;
    (5) negativo  — WebPanel (c9584656) com Conditions nao-vazia (filtro legitimo) -> nao dispara;
    (6) ExportFile com 2 objetos (Procedure sujo + WebPanel limpo) -> fail so para o Procedure.

    O gate emite JSON SEMPRE (sem -AsJson); o self-test invoca sem essa flag.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8SupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8SupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8SupportPath"
}
. $utf8SupportPath

$scriptPath  = Join-Path $PSScriptRoot 'Test-GeneXusSourceSanity.ps1'
$utf8        = Get-Utf8NoBomEncoding
$tempRoot    = Join-Path ([System.IO.Path]::GetTempPath()) ('sourcesanity-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$procType    = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$webType     = 'c9584656-94b6-4ccd-890f-332d11fc2c25'
$findingCode = 'procedural-in-conditions'

function New-ObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$ObjectType,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$MainSource = "msg('ok')",
        [ValidateSet('none', 'empty', 'whitespace', 'content')][string]$Conditions = 'none',
        [string]$ConditionsSource = ''
    )
    $condPart = ''
    if ($Conditions -ne 'none') {
        if ($Conditions -eq 'content') {
            $inner = $ConditionsSource
        } elseif ($Conditions -eq 'whitespace') {
            $inner = "`r`n   `r`n"
        } else {
            $inner = ''
        }
        $condPart = @"
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Source><![CDATA[$inner]]></Source>
  </Part>
"@
    }
    return @"
<Object type="$ObjectType" name="$Name" guid="11111111-1111-1111-1111-111111111111">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[$MainSource]]></Source>
  </Part>
$condPart</Object>
"@
}

function Invoke-Gate {
    param([string]$Xml)
    $f = Join-Path $tempRoot ('o-{0}.xml' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($f, $Xml, $utf8)
    return (& $scriptPath -InputPath $f | ConvertFrom-Json)
}

function Test-HasCondFinding {
    param($Result)
    return @($Result.findings | Where-Object { $_.code -eq $findingCode }).Count -gt 0
}

$dirtyConditions = @'
// Comentario indevido
&varMsg = ''
If &foundA
Return
Endif
'@

# Caso 1: Procedure + Conditions nao-vazia -> fail
$r1 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procDirty' -Conditions 'content' -ConditionsSource $dirtyConditions)
if (-not (Test-HasCondFinding $r1)) { throw "Caso 1: deveria disparar '$findingCode'." }
if ($r1.sourceSanityStatus -ne 'fail') { throw "Caso 1: sourceSanityStatus deveria ser 'fail'; obtido '$($r1.sourceSanityStatus)'." }
if ($r1.probablyImportable) { throw 'Caso 1: probablyImportable deveria ser false.' }

# Caso 2: Procedure + Conditions vazia -> nao dispara
$r2 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procEmpty' -Conditions 'empty')
if (Test-HasCondFinding $r2) { throw 'Caso 2: Conditions vazia nao deveria disparar.' }

# Caso 3: Procedure + Conditions whitespace-only -> nao dispara (skip antes da regra)
$r3 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procWs' -Conditions 'whitespace')
if (Test-HasCondFinding $r3) { throw 'Caso 3: Conditions whitespace-only nao deveria disparar.' }

# Caso 4: Procedure SEM a parte Conditions -> nao dispara
$r4 = Invoke-Gate (New-ObjectXml -ObjectType $procType -Name 'procNoCond' -Conditions 'none')
if (Test-HasCondFinding $r4) { throw 'Caso 4: Procedure sem parte Conditions nao deveria disparar.' }

# Caso 5: WebPanel + Conditions nao-vazia (filtro legitimo) -> nao dispara
$r5 = Invoke-Gate (New-ObjectXml -ObjectType $webType -Name 'wpClean' -Conditions 'content' -ConditionsSource 'AttrA = &x;')
if (Test-HasCondFinding $r5) { throw 'Caso 5: WebPanel com Conditions legitima nao deveria disparar.' }

# Caso 6: ExportFile com 2 objetos -> fail so para o Procedure
$exportXml = @"
<ExportFile>
  <Objects>
    <Object type="$procType" name="procDirty2" guid="22222222-2222-2222-2222-222222222222">
      <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
        <Source><![CDATA[msg('ok')]]></Source>
      </Part>
      <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
        <Source><![CDATA[$dirtyConditions]]></Source>
      </Part>
    </Object>
    <Object type="$webType" name="wpClean2" guid="33333333-3333-3333-3333-333333333333">
      <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
        <Source><![CDATA[AttrA = &x;]]></Source>
      </Part>
    </Object>
  </Objects>
</ExportFile>
"@
$r6 = Invoke-Gate $exportXml
$condFindings = @($r6.findings | Where-Object { $_.code -eq $findingCode })
if ($condFindings.Count -ne 1) { throw "Caso 6: deveria haver exatamente 1 finding '$findingCode'; obtido $($condFindings.Count)." }
if ($condFindings[0].message -notmatch 'procDirty2') { throw 'Caso 6: o finding deveria referenciar o Procedure procDirty2.' }
if ($r6.sourceSanityStatus -ne 'fail') { throw "Caso 6: sourceSanityStatus deveria ser 'fail'." }

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-GeneXusSourceSanitySelfTest.ps1'
exit 0
