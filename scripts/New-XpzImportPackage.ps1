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

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

    [string]$AcervoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-XpzPackageJson {
    param([Parameter(Mandatory = $true)][object]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 10)
}

function Write-XpzPackageJsonAndExit {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )
    ConvertTo-XpzPackageJson -InputObject $InputObject
    exit $ExitCode
}

trap {
    $failure = [ordered]@{
        status = 'erro'
        exitCode = 90
        stage = 'powershell-wrapper'
        blockingReasons = @($_.Exception.Message)
        warnings = @()
    }
    Write-XpzPackageJsonAndExit -InputObject $failure -ExitCode 90
}

$enginePath = Join-Path $PSScriptRoot 'New-XpzImportPackage.py'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'preflight'
        blockingReasons = @("motor Python nao encontrado: $enginePath")
        warnings = @()
    }) -ExitCode 20
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'preflight'
        blockingReasons = @('python nao encontrado no PATH para executar New-XpzImportPackage.py')
        warnings = @()
    }) -ExitCode 20
}

# Gate de drift frente-vs-acervo (antes do empacotamento)
$driftResult = $null
if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
    $acervoResolved = (Resolve-Path -LiteralPath $AcervoPath -ErrorAction Stop).Path
    $frontDir = Join-Path $RepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus' $FrontName
    if (-not (Test-Path -LiteralPath $frontDir -PathType Container)) {
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
            status = 'bloqueado'
            exitCode = 20
            stage = 'front-acervo-drift'
            repoRoot = $RepoRoot
            frontName = $FrontName
            blockingReasons = @("Pasta da frente nao encontrada: $frontDir")
            warnings = @()
        }) -ExitCode 20
    }
    $driftGatePath = Join-Path $PSScriptRoot 'Test-GeneXusFrontAcervoDrift.ps1'
    if (-not (Test-Path -LiteralPath $driftGatePath -PathType Leaf)) {
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
            status = 'bloqueado'
            exitCode = 20
            stage = 'front-acervo-drift'
            repoRoot = $RepoRoot
            frontName = $FrontName
            blockingReasons = @("gate de drift nao encontrado: $driftGatePath")
            warnings = @()
        }) -ExitCode 20
    }
    $driftOutput = & $driftGatePath -FrontFolder $frontDir -AcervoFolder $acervoResolved -AsJson 2>&1
    $driftResult = $driftOutput | ConvertFrom-Json
    if ($driftResult.status -eq 'fail') {
        $failFindings = @($driftResult.findings | Where-Object { $_.severity -eq 'fail' })
        $blockMsgs = @($failFindings | ForEach-Object { $_.message })
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
            status = 'bloqueado'
            exitCode = 20
            stage = 'front-acervo-drift'
            repoRoot = $RepoRoot
            frontName = $FrontName
            driftStatus = $driftResult.status
            driftFindings = $driftResult.findings
            driftObjectsScanned = $driftResult.objectsScanned
            blockingReasons = @("gate de drift frente-vs-acervo falhou ($($blockMsgs.Count) finding(s) fatal(is)): $($blockMsgs -join '; ')")
            warnings = @()
        }) -ExitCode 20
    }
    if ($driftResult.status -eq 'alert') {
        $warnFindings = @($driftResult.findings | Where-Object { $_.severity -eq 'warn' })
        $warnMsgs = @($warnFindings | ForEach-Object { $_.message })
        Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
            status = 'bloqueado'
            exitCode = 20
            stage = 'front-acervo-drift'
            repoRoot = $RepoRoot
            frontName = $FrontName
            driftStatus = $driftResult.status
            driftFindings = $driftResult.findings
            driftObjectsScanned = $driftResult.objectsScanned
            blockingReasons = @("gate de drift frente-vs-acervo retornou alerta ($($warnMsgs.Count) finding(s) warn): confirmacao explicita ou resolucao manual requerida antes de empacotar. $($warnMsgs -join '; ')")
            warnings = @($warnMsgs)
        }) -ExitCode 20
    }
}

$engineArgs = @(
    $enginePath,
    '--repo-root', $RepoRoot,
    '--front-name', $FrontName,
    '--nn', $NN
)

if (-not [string]::IsNullOrWhiteSpace($TemplatePackagePath)) {
    $engineArgs += @('--template-package-path', $TemplatePackagePath)
}

$outputText = (& $pythonCommand.Source @engineArgs 2>&1 | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
$engineExitCode = $LASTEXITCODE

try {
    $result = $outputText | ConvertFrom-Json
} catch {
    Write-XpzPackageJsonAndExit -InputObject ([ordered]@{
        status = 'erro'
        exitCode = 90
        stage = 'python-engine'
        blockingReasons = @('motor Python retornou saida nao JSON')
        rawOutput = $outputText
        warnings = @()
    }) -ExitCode 90
}

if ($engineExitCode -ne 0) {
    if ($null -eq $result.PSObject.Properties['exitCode']) {
        $result | Add-Member -NotePropertyName exitCode -NotePropertyValue $engineExitCode -Force
    }
    if ($null -eq $result.PSObject.Properties['stage']) {
        $result | Add-Member -NotePropertyName stage -NotePropertyValue 'python-engine' -Force
    }
    Write-XpzPackageJsonAndExit -InputObject $result -ExitCode $engineExitCode
}

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

ConvertTo-XpzPackageJson -InputObject $result
