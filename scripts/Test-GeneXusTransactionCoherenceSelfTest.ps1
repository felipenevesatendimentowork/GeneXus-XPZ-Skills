#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do gate Test-GeneXusTransactionCoherence.ps1, foco na regra
    wwp-screen-code-on-non-generated-transaction (Frente D).

.DESCRIPTION
    Cobre:
    (1) positivo  — Transaction GenerateObject=False com código de tela WorkWithPlus
        DVelop orfao em Events (Call("LoadWWPContext") / Call("<Trn>WW")) dispara fail;
    (2) negativo  — mesma Transaction com Events limpos NÃO dispara;
    (3) negativo  — GenerateObject default (propriedade ausente) com chamada *WW em
        Events NÃO dispara (early-return: tela e gerada, o código não e orfao).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8SupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8SupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8SupportPath"
}
. $utf8SupportPath

$scriptPath = Join-Path $PSScriptRoot 'Test-GeneXusTransactionCoherence.ps1'
$utf8       = Get-Utf8NoBomEncoding
$tempRoot   = Join-Path ([System.IO.Path]::GetTempPath()) ('trncoherence-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$wwpCode        = '07135890-56fc-489b-b408-063722fa9f7d'
$wwpFindingCode = 'wwp-screen-code-on-non-generated-transaction'

function New-TrnXml {
    param(
        [Parameter(Mandatory = $true)][string]$EventsSource,
        [bool]$GenerateObjectFalse,
        [bool]$ApplyWwp
    )
    $props = ''
    if ($GenerateObjectFalse) {
        $props += "    <Property><Name>GenerateObject</Name><Value>False</Value></Property>`n"
    }
    if ($ApplyWwp) {
        $props += "    <Property><Name>Apply:$wwpCode</Name><Value>True</Value></Property>`n"
    }
    return @"
<Object type="1db606f2-af09-4cf9-a3b5-b481519d28f6" name="Trn1" guid="62f63801-fdf0-47a2-a52f-da4f1b035cb8">
  <Part type="264be5fb-1b28-4b25-a598-6ca900dd059f">
    <Level Name="Trn1">
      <Attribute key="True" guid="cad4e441-3180-4271-bb24-059d6090df30">AttrA</Attribute>
    </Level>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[$EventsSource]]></Source>
  </Part>
  <Properties>
$props  </Properties>
</Object>
"@
}

function Invoke-Gate {
    param([string]$Xml)
    $f = Join-Path $tempRoot ('trn-{0}.xml' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($f, $Xml, $utf8)
    return (& $scriptPath -InputPath $f -AsJson | ConvertFrom-Json)
}

function Test-HasWwpFinding {
    param($Result)
    return @($Result.findings | Where-Object { $_.code -eq $wwpFindingCode }).Count -gt 0
}

$eventsDirty = @'

Event Start
  Call("LoadWWPContext", &WWPContext)
EndEvent
Event After Trn
  Call("Trn1WW")
EndEvent
'@

$eventsClean = @'

Event Start
EndEvent
'@

# Caso 1: positivo — GenerateObject=False + código WWP orfao em Events
$r1 = Invoke-Gate (New-TrnXml -EventsSource $eventsDirty -GenerateObjectFalse $true -ApplyWwp $true)
if (-not (Test-HasWwpFinding $r1)) { throw "Caso 1: deveria disparar '$wwpFindingCode'." }
if ($r1.sourceSanityStatus -ne 'fail') { throw "Caso 1: sourceSanityStatus deveria ser 'fail'; obtido '$($r1.sourceSanityStatus)'." }
if ($r1.probablyImportable) { throw 'Caso 1: probablyImportable deveria ser false.' }

# Caso 2: negativo — GenerateObject=False + Events limpos
$r2 = Invoke-Gate (New-TrnXml -EventsSource $eventsClean -GenerateObjectFalse $true -ApplyWwp $true)
if (Test-HasWwpFinding $r2) { throw 'Caso 2: Events limpos nao deveriam disparar a regra WWP.' }

# Caso 3: negativo — GenerateObject default (ausente) + chamada *WW em Events
$r3 = Invoke-Gate (New-TrnXml -EventsSource $eventsDirty -GenerateObjectFalse $false -ApplyWwp $false)
if (Test-HasWwpFinding $r3) { throw 'Caso 3: GenerateObject default (True) nao deveria disparar a regra WWP.' }

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-GeneXusTransactionCoherenceSelfTest.ps1'
exit 0
