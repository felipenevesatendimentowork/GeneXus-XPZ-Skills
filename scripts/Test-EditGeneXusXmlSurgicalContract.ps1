#requires -Version 7.4
<#
.SYNOPSIS
    Regressao minima do contrato Edit-GeneXusXmlSurgical.ps1.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$scriptPath = Join-Path $scriptDir 'Edit-GeneXusXmlSurgical.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Edit-GeneXusXmlSurgical.ps1 nao encontrado: $scriptPath"
}

$transactionGuid = '1db606f2-af09-4cf9-a3b5-b481519d28f6'
$baselineLastUpdate = '2026-05-25T12:00:00.0000000Z'

function Get-LastUpdateDateTimeOffset {
    param([object]$Value)

    if ($null -eq $Value) {
        throw 'lastUpdate nulo'
    }

    if ($Value -is [datetime]) {
        return [DateTimeOffset]::new($Value.ToUniversalTime())
    }

    $text = [string]$Value
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $text,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        throw "lastUpdate invalido: $text"
    }
    return $parsed
}

function New-ContractFixtureXml {
    param(
        [string]$RulesBody,

        [string]$ExtraRulesLine = ''
    )

    if (-not $PSBoundParameters.ContainsKey('RulesBody')) {
        $RulesBody = "Default(Field,proc());`r`n"
    }

    $body = $RulesBody
    if (-not [string]::IsNullOrEmpty($ExtraRulesLine)) {
        $body += $ExtraRulesLine
    }

    return @"
<Object type="$transactionGuid" name="ContractTest" guid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" lastUpdate="$baselineLastUpdate">
  <Rules><![CDATA[
$body]]></Rules>
</Object>
"@
}

function Invoke-SurgicalScript {
    param(
        [hashtable]$Arguments
    )

    $invokeArgs = @{
        InputPath  = $Arguments.InputPath
        Anchor     = $Arguments.Anchor
        Replacement = $Arguments.Replacement
        EditMode   = $Arguments.EditMode
    }

    if ($Arguments.ContainsKey('OutputPath')) { $invokeArgs.OutputPath = $Arguments.OutputPath }
    if ($Arguments.ContainsKey('ExpectedAnchorCount')) { $invokeArgs.ExpectedAnchorCount = $Arguments.ExpectedAnchorCount }
    if ($Arguments.ContainsKey('PreserveLastUpdate')) { $invokeArgs.PreserveLastUpdate = $Arguments.PreserveLastUpdate }
    if ($Arguments.ContainsKey('LastUpdateBaselinePath')) { $invokeArgs.LastUpdateBaselinePath = $Arguments.LastUpdateBaselinePath }
    if ($Arguments.ContainsKey('DryRun')) { $invokeArgs.DryRun = $Arguments.DryRun }
    if ($Arguments.ContainsKey('AssertWellFormedAfter')) { $invokeArgs.AssertWellFormedAfter = $Arguments.AssertWellFormedAfter }
    if ($Arguments.ContainsKey('AsJson')) { $invokeArgs.AsJson = $Arguments.AsJson }

    $jsonText = & $scriptPath @invokeArgs -AsJson 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $parsed = $jsonText | ConvertFrom-Json
    return [pscustomobject]@{
        ExitCode = $exitCode
        Json     = $parsed
        RawJson  = $jsonText
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('edit-genexus-xml-surgical-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

try {
    $anchorDefault = 'Default(Field,proc());'
    $fixturePath = Join-Path $tempRoot 'ContractTest.xml'
    [System.IO.File]::WriteAllText($fixturePath, (New-ContractFixtureXml), (New-Object System.Text.UTF8Encoding $false))

    # 1) Replace com bump (default)
    $r1 = Invoke-SurgicalScript -Arguments @{
        InputPath   = $fixturePath
        Anchor      = $anchorDefault
        Replacement = 'Default(Field,proc());' + "`r`n" + 'Field = 1 if cond;'
        EditMode    = 'Replace'
    }
    if ($r1.ExitCode -ne 0) { throw "Caso 1: exit esperado 0; obtido $($r1.ExitCode) $($r1.RawJson)" }
    if ($r1.Json.status -ne 'OK') { throw 'Caso 1: status OK esperado' }
    $written1 = [System.IO.File]::ReadAllText($fixturePath)
    if ($written1 -notmatch 'Field = 1 if cond') { throw 'Caso 1: replacement ausente' }
    $baseDto = Get-LastUpdateDateTimeOffset -Value $baselineLastUpdate
    $afterDto = Get-LastUpdateDateTimeOffset -Value $r1.Json.lastUpdateAfter
    if ($afterDto -le $baseDto) {
        throw "Caso 1: lastUpdateAfter deveria ser maior que baseline; after=$afterDto base=$baseDto"
    }

    # 2) InsertAfter
    $fixtureInsert = Join-Path $tempRoot 'ContractInsert.xml'
    [System.IO.File]::WriteAllText($fixtureInsert, (New-ContractFixtureXml), (New-Object System.Text.UTF8Encoding $false))
    $r2 = Invoke-SurgicalScript -Arguments @{
        InputPath   = $fixtureInsert
        Anchor      = $anchorDefault
        Replacement = "`r`n// inserted"
        EditMode    = 'InsertAfter'
    }
    if ($r2.ExitCode -ne 0) { throw "Caso 2 InsertAfter: exit $($r2.ExitCode)" }
    $written2 = [System.IO.File]::ReadAllText($fixtureInsert)
    if ($written2 -notmatch [regex]::Escape($anchorDefault + "`r`n// inserted")) {
        throw 'Caso 2: ancora + insercao nao encontradas em sequencia'
    }

    # 3) DryRun nao grava
    $fixtureDry = Join-Path $tempRoot 'ContractDry.xml'
    $dryContent = New-ContractFixtureXml
    [System.IO.File]::WriteAllText($fixtureDry, $dryContent, (New-Object System.Text.UTF8Encoding $false))
    $r3 = Invoke-SurgicalScript -Arguments @{
        InputPath   = $fixtureDry
        Anchor      = $anchorDefault
        Replacement = 'SHOULD_NOT_PERSIST'
        EditMode    = 'Replace'
        DryRun      = $true
    }
    if ($r3.ExitCode -ne 0) { throw "Caso 3 DryRun: exit $($r3.ExitCode)" }
    if (-not $r3.Json.dryRun) { throw 'Caso 3: dryRun esperado true' }
    $afterDry = [System.IO.File]::ReadAllText($fixtureDry)
    if ($afterDry -ne $dryContent) { throw 'Caso 3: arquivo foi alterado no dry-run' }

    # 4) OutputPath copia
    $sourceCopy = Join-Path $tempRoot 'ContractSource.xml'
    $destCopy = Join-Path $tempRoot 'ContractDest.xml'
    $sourceContent = New-ContractFixtureXml
    [System.IO.File]::WriteAllText($sourceCopy, $sourceContent, (New-Object System.Text.UTF8Encoding $false))
    $r4 = Invoke-SurgicalScript -Arguments @{
        InputPath   = $sourceCopy
        OutputPath  = $destCopy
        Anchor      = $anchorDefault
        Replacement = 'Default(Field,proc());' + "`r`n" + 'copied = true;'
        EditMode    = 'Replace'
    }
    if ($r4.ExitCode -ne 0) { throw "Caso 4 OutputPath: exit $($r4.ExitCode)" }
    if ([System.IO.File]::ReadAllText($sourceCopy) -ne $sourceContent) { throw 'Caso 4: origem alterada' }
    if ([System.IO.File]::ReadAllText($destCopy) -notmatch 'copied = true') { throw 'Caso 4: destino sem patch' }

    # 5) Ancora ausente
    $fixtureMissing = Join-Path $tempRoot 'ContractMissingAnchor.xml'
    [System.IO.File]::WriteAllText($fixtureMissing, (New-ContractFixtureXml), (New-Object System.Text.UTF8Encoding $false))
    $r5 = Invoke-SurgicalScript -Arguments @{
        InputPath   = $fixtureMissing
        Anchor      = 'ANCORA_INEXISTENTE'
        Replacement = 'x'
        EditMode    = 'Replace'
    }
    if ($r5.ExitCode -ne 11) { throw "Caso 5: exit 11 esperado; obtido $($r5.ExitCode)" }
    if ($r5.Json.code -ne 'ANCHOR_FAIL') { throw 'Caso 5: ANCHOR_FAIL esperado' }

    # 6) Ancora duplicada
    $dupBody = "Default(Field,proc());`r`n" + 'Default(Field,proc());' + "`r`n"
    $fixtureDup = Join-Path $tempRoot 'ContractDup.xml'
    [System.IO.File]::WriteAllText($fixtureDup, (New-ContractFixtureXml -RulesBody $dupBody), (New-Object System.Text.UTF8Encoding $false))
    $r6 = Invoke-SurgicalScript -Arguments @{
        InputPath   = $fixtureDup
        Anchor      = $anchorDefault
        Replacement = 'once'
        EditMode    = 'Replace'
    }
    if ($r6.ExitCode -ne 11) { throw "Caso 6: exit 11 esperado; obtido $($r6.ExitCode)" }

    # 7) XML malformado apos replace + restore
    $fixtureBad = Join-Path $tempRoot 'ContractBad.xml'
    $badOriginal = New-ContractFixtureXml
    [System.IO.File]::WriteAllText($fixtureBad, $badOriginal, (New-Object System.Text.UTF8Encoding $false))
    $r7 = Invoke-SurgicalScript -Arguments @{
        InputPath   = $fixtureBad
        Anchor      = ']]></Rules>'
        Replacement = 'BROKEN'
        EditMode    = 'Replace'
    }
    if ($r7.ExitCode -ne 13) { throw "Caso 7: exit 13 esperado; obtido $($r7.ExitCode)" }
    if ($r7.Json.code -ne 'XML_NOT_WELLFORMED_AFTER') { throw 'Caso 7: XML_NOT_WELLFORMED_AFTER esperado' }
    $afterBad = [System.IO.File]::ReadAllText($fixtureBad)
    if ($afterBad -ne $badOriginal) { throw 'Caso 7: arquivo nao restaurado apos falha' }

    # 8) PreserveLastUpdate
    $fixturePreserve = Join-Path $tempRoot 'ContractPreserve.xml'
    [System.IO.File]::WriteAllText($fixturePreserve, (New-ContractFixtureXml), (New-Object System.Text.UTF8Encoding $false))
    $r8 = Invoke-SurgicalScript -Arguments @{
        InputPath            = $fixturePreserve
        Anchor               = $anchorDefault
        Replacement          = 'Default(Field,proc());' + "`r`n" + 'preserved = 1;'
        EditMode             = 'Replace'
        PreserveLastUpdate   = $true
    }
    if ($r8.ExitCode -ne 0) { throw "Caso 8 PreserveLastUpdate: exit $($r8.ExitCode)" }
    $preservedAfter = Get-LastUpdateDateTimeOffset -Value $r8.Json.lastUpdateAfter
    $preservedBase = Get-LastUpdateDateTimeOffset -Value $baselineLastUpdate
    if ($preservedAfter -ne $preservedBase) {
        throw "Caso 8: lastUpdate deveria permanecer $baselineLastUpdate; obtido $preservedAfter"
    }
    if ([System.IO.File]::ReadAllText($fixturePreserve) -notmatch 'preserved = 1') {
        throw 'Caso 8: patch ausente'
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'EDIT_GENEXUS_XML_SURGICAL_CONTRACT_OK'
