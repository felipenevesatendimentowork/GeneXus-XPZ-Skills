#requires -Version 7.4
<#
.SYNOPSIS
    Diagnostica se o runtime GeneXus reflete a versao mais recente de um objeto importado.

.DESCRIPTION
    Verifica dois indicadores em modo somente leitura, sem abrir a IDE e sem invocar MSBuild:

    1. nav_objs.xml na raiz da KB: status de geracao do objeto
       - genreq  = GeneXus marcou o objeto como pendente de geracao (runtime defasado)
       - nogenreq = GeneXus considera o objeto ja gerado (checar artefatos para confirmar)

    2. Artefatos gerados (CSharpModel\web): timestamp dos arquivos gerados vs ImportedAt

    O diagnostico e somente leitura: nao grava, nao abre KB, nao invoca MSBuild.

.PARAMETER KbPath
    Caminho da KB GeneXus nativa (ex: C:\GxModels\MinhaKB).

.PARAMETER ObjectName
    Nome do objeto GeneXus a verificar.

.PARAMETER ImportedAt
    Timestamp do import usado como linha de corte (DateTime ou string ISO parseable).

.PARAMETER ObjectType
    Tipo GeneXus do objeto (ex: Procedure, WebPanel). Reservado para uso futuro.

.PARAMETER GeneratorOutputPath
    Pasta de output do gerador. Se omitido, deriva como <KbPath>\CSharpModel\web.

.PARAMETER AsJson
    Emite saida como JSON estruturado em vez de texto humano.

.EXAMPLE
    .\Test-GeneXusRuntimeFreshness.ps1 `
        -KbPath "C:\GxModels\MinhaKB" `
        -ObjectName "MinhaProc" `
        -ImportedAt "2026-05-07T22:00:00-03:00" `
        -AsJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$ObjectName,

    [Parameter(Mandatory = $true)]
    [string]$ImportedAt,

    [string]$ObjectType,

    [string]$GeneratorOutputPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Parse ImportedAt ───────────────────────────────────────────────────────────

$importedAtDt = $null
try {
    $importedAtDt = [DateTimeOffset]::Parse($ImportedAt)
} catch {
    throw "ImportedAt nao e timestamp valido: '$ImportedAt'"
}

# ── Inicializar resultado ──────────────────────────────────────────────────────

$result = [ordered]@{
    status     = 'runtime-unknown'
    objectName = $ObjectName
    importedAt = $importedAtDt.ToString('o')
    checks     = [ordered]@{
        navObjsXml         = [ordered]@{
            found              = $false
            objStatus          = $null
            requiresGeneration = $null
        }
        generatedArtifacts = [ordered]@{
            found                = $false
            artifacts            = @()
            allFresherThanImport = $null
        }
    }
    summary    = ''
}

# ── 1. nav_objs.xml ────────────────────────────────────────────────────────────
# Localizado na raiz da KB nativa; lista objetos com ObjStatus genreq/nogenreq.
# O arquivo nao tem elemento raiz — encapsulado antes do parse.

$navObjsPath = Join-Path $KbPath 'nav_objs.xml'

if (Test-Path -LiteralPath $navObjsPath -PathType Leaf) {
    try {
        $rawContent = Get-Content -LiteralPath $navObjsPath -Raw -Encoding UTF8
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.PreserveWhitespace = $false
        $xmlDoc.LoadXml("<NavObjs>$rawContent</NavObjs>")

        $matchedNode = $null
        foreach ($node in $xmlDoc.SelectNodes('/NavObjs/Object')) {
            $nameNode = $node.SelectSingleNode('ObjName')
            if ($null -ne $nameNode -and $nameNode.InnerText -ieq $ObjectName) {
                $matchedNode = $node
                break
            }
        }

        if ($null -ne $matchedNode) {
            $statusNode = $matchedNode.SelectSingleNode('ObjStatus')
            $objStatus  = if ($null -ne $statusNode) { $statusNode.InnerText } else { $null }
            $requiresGen = ($objStatus -eq 'genreq')

            $result.checks.navObjsXml.found              = $true
            $result.checks.navObjsXml.objStatus          = $objStatus
            $result.checks.navObjsXml.requiresGeneration = $requiresGen
        }
    } catch {
        # Parse falhou — manter found=false; nao abortar o diagnostico
    }
}

# ── 2. Artefatos gerados ───────────────────────────────────────────────────────
# Artefatos ficam em <KbPath>\CSharpModel\web\ com nome em minusculas.
# Extensoes observadas empiricamente: .cs .js .aspx .rsp

$outputPath = $GeneratorOutputPath
if ([string]::IsNullOrWhiteSpace($outputPath)) {
    $derived = Join-Path $KbPath 'CSharpModel\web'
    if (Test-Path -LiteralPath $derived -PathType Container) {
        $outputPath = $derived
    }
}

if (-not [string]::IsNullOrWhiteSpace($outputPath) -and
    (Test-Path -LiteralPath $outputPath -PathType Container)) {

    $namePrefix  = $ObjectName.ToLower()
    $extensions  = @('.cs', '.js', '.aspx', '.rsp')
    $foundArtifacts = [System.Collections.Generic.List[object]]::new()

    foreach ($ext in $extensions) {
        $candidate = Join-Path $outputPath ($namePrefix + $ext)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $fi        = Get-Item -LiteralPath $candidate
            $lastWrite = [DateTimeOffset]::new($fi.LastWriteTime)
            $fresh     = $lastWrite -gt $importedAtDt
            $foundArtifacts.Add([ordered]@{
                path              = $fi.FullName
                lastWrite         = $lastWrite.ToString('o')
                fresherThanImport = $fresh
            })
        }
    }

    if ($foundArtifacts.Count -gt 0) {
        $staleCount = ($foundArtifacts | Where-Object { -not $_.fresherThanImport }).Count
        $allFresh   = ($staleCount -eq 0)

        $result.checks.generatedArtifacts.found                = $true
        $result.checks.generatedArtifacts.artifacts            = $foundArtifacts.ToArray()
        $result.checks.generatedArtifacts.allFresherThanImport = $allFresh
    }
}

# ── 3. Classificar status ──────────────────────────────────────────────────────

$navFound    = $result.checks.navObjsXml.found
$requiresGen = $result.checks.navObjsXml.requiresGeneration
$artFound    = $result.checks.generatedArtifacts.found
$allFresh    = $result.checks.generatedArtifacts.allFresherThanImport

if ($navFound -and $requiresGen) {
    $result.status  = 'runtime-stale'
    $result.summary = "nav_objs.xml marca '$ObjectName' como genreq — geracao pendente apos o import"
} elseif ($navFound -and (-not $requiresGen) -and $artFound -and $allFresh) {
    $result.status  = 'runtime-fresh'
    $result.summary = "nav_objs.xml: nogenreq; artefatos gerados posteriores ao import — runtime atualizado"
} elseif ($navFound -and (-not $requiresGen) -and $artFound -and (-not $allFresh)) {
    $result.status  = 'runtime-stale'
    $result.summary = "nav_objs.xml: nogenreq, mas artefatos anteriores ao import — runtime ainda reflete versao anterior"
} elseif ($navFound -and (-not $requiresGen) -and (-not $artFound)) {
    $result.status  = 'runtime-unknown'
    $result.summary = "nav_objs.xml: nogenreq, mas artefatos nao localizados — diagnostico inconclusivo"
} elseif ((-not $navFound) -and $artFound -and $allFresh) {
    $result.status  = 'runtime-unknown'
    $result.summary = "Objeto ausente em nav_objs.xml; artefatos frescos encontrados — diagnostico inconclusivo"
} elseif (-not $navFound) {
    $result.status  = 'runtime-unknown'
    $result.summary = "Objeto '$ObjectName' nao encontrado em nav_objs.xml — diagnostico inconclusivo"
} else {
    $result.status  = 'runtime-unknown'
    $result.summary = "Indicadores insuficientes para determinar estado do runtime"
}

# ── 4. Saida ───────────────────────────────────────────────────────────────────

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Host "Status    : $($result.status)"
    Write-Host "Objeto    : $($result.objectName)"
    Write-Host "Import em : $($result.importedAt)"
    Write-Host ''
    Write-Host 'nav_objs.xml:'
    Write-Host "  Encontrado         : $($result.checks.navObjsXml.found)"
    Write-Host "  ObjStatus          : $($result.checks.navObjsXml.objStatus)"
    Write-Host "  Requer geracao     : $($result.checks.navObjsXml.requiresGeneration)"
    Write-Host ''
    Write-Host 'Artefatos gerados:'
    Write-Host "  Encontrados        : $($result.checks.generatedArtifacts.found)"
    Write-Host "  Todos frescos      : $($result.checks.generatedArtifacts.allFresherThanImport)"
    foreach ($a in $result.checks.generatedArtifacts.artifacts) {
        Write-Host "  - $($a.path) | $($a.lastWrite) | fresher=$($a.fresherThanImport)"
    }
    Write-Host ''
    Write-Host "Resumo    : $($result.summary)"
}

exit 0
