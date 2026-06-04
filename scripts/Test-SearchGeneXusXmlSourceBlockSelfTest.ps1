#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptUnderTest = Join-Path $PSScriptRoot 'Search-GeneXusXmlSourceBlock.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-source-search-selftest-' + [guid]::NewGuid().ToString('N'))
$samplePath = Join-Path $tempRoot 'wpSample.xml'
$packagePath = Join-Path $tempRoot 'package.xml'

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message Expected=[$Expected] Actual=[$Actual]"
    }
}

function Read-JsonArray {
    param([string[]]$Text)

    $joined = ($Text -join [Environment]::NewLine)
    if ([string]::IsNullOrWhiteSpace($joined)) {
        return @()
    }
    return @($joined | ConvertFrom-Json)
}

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    $sampleXml = @(
        '<Object type="d82625fd-5892-40b0-99c9-5c8559c197fc" name="wpSample">',
        '  <Part type="layout">',
        '    <Source><![CDATA[<GxMultiForm><Form><detail><layout><data attribute="&praConsultaSerie" labelCaption="Serie" /></layout></detail></Form></GxMultiForm>]]></Source>',
        '  </Part>',
        '  <Part type="events">',
        '    <Source><![CDATA[Event Start',
        '  &praConsultaSerie = ''001''',
        'EndEvent',
        ']]></Source>',
        '  </Part>',
        '</Object>'
    ) -join "`n"
    [System.IO.File]::WriteAllText($samplePath, $sampleXml, (Get-Utf8NoBomEncoding))

    $packageXml = @(
        '<ExportFile>',
        '  <Objects>',
        '    <Object type="x" name="wpFirst">',
        '      <Source><![CDATA[Event Start',
        '  &outra = 1',
        'EndEvent',
        ']]></Source>',
        '    </Object>',
        '    <Object type="x" name="wpSecond">',
        '      <Source><![CDATA[Event Start',
        '  &praConsultaSerie = ''002''',
        'EndEvent',
        ']]></Source>',
        '    </Object>',
        '  </Objects>',
        '</ExportFile>'
    ) -join "`n"
    [System.IO.File]::WriteAllText($packagePath, $packageXml, (Get-Utf8NoBomEncoding))

    $events = Read-JsonArray -Text (& $scriptUnderTest -Path $samplePath -Pattern 'praConsultaSerie' -Block events -AsJson)
    Assert-Equal -Actual $events.Count -Expected 1 -Message 'events deve encontrar apenas o match no code-behind.'
    Assert-Equal -Actual $events[0].block -Expected 'events' -Message 'events deve classificar o bloco corretamente.'
    Assert-Equal -Actual $events[0].xmlLine -Expected 7 -Message 'events deve reportar a linha interna correta.'

    $layout = Read-JsonArray -Text (& $scriptUnderTest -Path $samplePath -Pattern 'praConsultaSerie' -Block layout -AsJson)
    Assert-Equal -Actual $layout.Count -Expected 1 -Message 'layout deve encontrar apenas o match no GxMultiForm.'
    Assert-Equal -Actual $layout[0].block -Expected 'layout' -Message 'layout deve classificar GxMultiForm corretamente.'
    if ($layout[0].preview.Length -gt 183) {
        throw 'preview de layout deve permanecer compacto.'
    }

    $code = Read-JsonArray -Text (& $scriptUnderTest -Path $samplePath -Pattern 'praConsultaSerie' -Block code -AsJson)
    Assert-Equal -Actual $code.Count -Expected 1 -Message 'code deve incluir events e excluir layout.'
    Assert-Equal -Actual $code[0].block -Expected 'events' -Message 'code deve preservar a classificacao real do bloco.'

    $package = Read-JsonArray -Text (& $scriptUnderTest -Path $packagePath -Pattern 'praConsultaSerie' -Block events -AsJson)
    Assert-Equal -Actual $package.Count -Expected 1 -Message 'package deve encontrar o match no objeto correto.'
    Assert-Equal -Actual $package[0].objectName -Expected 'wpSecond' -Message 'package deve reportar o Object/@name mais proximo do Source.'

    Write-Output 'SEARCH_GENEXUS_XML_SOURCE_BLOCK_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        $resolvedSystemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
        if (-not $resolvedTempRoot.StartsWith($resolvedSystemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Temp root fora do diretorio temporario esperado: $resolvedTempRoot"
        }
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
