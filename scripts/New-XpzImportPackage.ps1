#requires -Version 7.4
<#
.SYNOPSIS
    Cria um import_file.xml a partir de uma frente local da pasta paralela da KB.

.DESCRIPTION
    Wrapper fino para scripts\New-XpzImportPackage.py. Mantem um ponto de entrada
    PowerShell curto para allowlist local, deixando a montagem XML no motor Python.
    Para Panel, o resultado JSON inclui information quando o par level/layout e
    confirmado pelo template comparavel e warnings quando o par nao e confirmado
    ou nao ha template comparavel.

    Quando -AcervoPath e fornecido, executa o gate de drift frente-vs-acervo
    (Test-GeneXusFrontAcervoDrift.ps1) ANTES de chamar o motor Python. Se o gate
    retornar status fail ou alert, o empacotamento e abortado com erro. Findings
    warn exigem confirmacao explicita ou resolucao antes de nova tentativa.

.PARAMETER RepoRoot
    Raiz da pasta paralela da KB.

.PARAMETER FrontName
    Nome da subpasta da frente no formato NomeCurto_GUID_YYYYMMDD.

.PARAMETER NN
    Rodada curta do pacote. Default: 01.

.PARAMETER TemplatePackagePath
    Pacote import_file.xml ou XPZ real comparavel para clonar KMW, Source,
    Dependencies e ObjectsIdentityMapping. Quando o template trouxer Attributes
    de topo e a frente nao trouxer atributos explicitos, o motor preserva esses
    Attributes. Quando omitido, o motor usa envelope minimo derivado de
    kb-source-metadata.md. Para Panel, especialmente Panel SD, preferir template
    real exportado pela IDE da mesma KB; par confirmado e reportado em information.

.PARAMETER AcervoPath
    Caminho para a pasta do acervo oficial (ObjetosDaKbEmXml). Quando fornecido,
    executa o gate de drift frente-vs-acervo antes do empacotamento. Se o gate
    detectar que um XML da frente esta mais antigo que o homonimo no acervo
    (front-older-than-acervo), o empacotamento e abortado. Findings warn
    (front-equals-acervo ou lastupdate-unparseable) tambem bloqueiam esta
    chamada automatica ate confirmacao/resolucao fora do wrapper.

.PARAMETER AsJson
    Retorna saída JSON estruturada, incluindo warnings e information de Panel.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

    [string]$AcervoPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$enginePath = Join-Path $PSScriptRoot 'New-XpzImportPackage.py'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "BLOCK: motor Python nao encontrado: $enginePath"
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
    throw 'BLOCK: python nao encontrado no PATH para executar New-XpzImportPackage.py'
}

# Gate de drift frente-vs-acervo (antes do empacotamento)
$driftResult = $null
if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
    $acervoResolved = (Resolve-Path -LiteralPath $AcervoPath -ErrorAction Stop).Path
    $frontDir = Join-Path $RepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus' $FrontName
    if (-not (Test-Path -LiteralPath $frontDir -PathType Container)) {
        throw "Pasta da frente nao encontrada: $frontDir"
    }
    $driftGatePath = Join-Path $PSScriptRoot 'Test-GeneXusFrontAcervoDrift.ps1'
    if (-not (Test-Path -LiteralPath $driftGatePath -PathType Leaf)) {
        throw "BLOCK: gate de drift nao encontrado: $driftGatePath"
    }
    $driftOutput = & $driftGatePath -FrontFolder $frontDir -AcervoFolder $acervoResolved -AsJson 2>&1
    $driftResult = $driftOutput | ConvertFrom-Json
    if ($driftResult.status -eq 'fail') {
        $failFindings = @($driftResult.findings | Where-Object { $_.severity -eq 'fail' })
        $blockMsgs = @($failFindings | ForEach-Object { $_.message })
        throw "BLOCK: gate de drift frente-vs-acervo falhou ($($blockMsgs.Count) finding(s) fatal(is)): $($blockMsgs -join '; ')"
    }
    if ($driftResult.status -eq 'alert') {
        $warnFindings = @($driftResult.findings | Where-Object { $_.severity -eq 'warn' })
        $warnMsgs = @($warnFindings | ForEach-Object { $_.message })
        throw "BLOCK: gate de drift frente-vs-acervo retornou alerta ($($warnMsgs.Count) finding(s) warn): confirmacao explicita ou resolucao manual requerida antes de empacotar. $($warnMsgs -join '; ')"
    }
}

$engineArgs = @(
    $enginePath,
    '--repo-root', $RepoRoot,
    '--front-name', $FrontName,
    '--nn', $NN,
    '--as-json'
)

if (-not [string]::IsNullOrWhiteSpace($TemplatePackagePath)) {
    $engineArgs += @('--template-package-path', $TemplatePackagePath)
}

$outputText = (& $pythonCommand.Source @engineArgs | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    throw $outputText
}

$result = $outputText | ConvertFrom-Json
if (-not [string]::IsNullOrWhiteSpace([string]$result.outputPath)) {
    . (Join-Path $PSScriptRoot 'GeneXusPackageInventorySupport.ps1')
    $declaredDelta = Get-DeclaredDeltaItemsFromFrontObjectXmls -FrontDir $result.sourceFolder
    $sidecarInventoryPath = ([string]$result.outputPath) + '.package-inventory.json'
    $inventoryBlock = New-PackageInventoryResult `
        -InputPath $result.outputPath `
        -DeclaredDeltaItems $declaredDelta `
        -SidecarInventoryPath $sidecarInventoryPath
    $result | Add-Member -NotePropertyName packageInventory -NotePropertyValue $inventoryBlock.packageInventory -Force
    $result | Add-Member -NotePropertyName inventoryDegraded -NotePropertyValue $inventoryBlock.inventoryDegraded -Force
    $result | Add-Member -NotePropertyName inventoryError -NotePropertyValue $inventoryBlock.inventoryError -Force
}

if ($null -ne $driftResult) {
    $result | Add-Member -NotePropertyName driftStatus -NotePropertyValue $driftResult.status -Force
    $result | Add-Member -NotePropertyName driftFindings -NotePropertyValue $driftResult.findings -Force
    $result | Add-Member -NotePropertyName driftObjectsScanned -NotePropertyValue $driftResult.objectsScanned -Force
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result
}
