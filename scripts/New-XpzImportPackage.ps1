#requires -Version 7.4
<#
.SYNOPSIS
    Cria um import_file.xml a partir de uma frente local da pasta paralela da KB.

.DESCRIPTION
    Wrapper fino para scripts\New-XpzImportPackage.py. Mantem um ponto de entrada
    PowerShell curto para allowlist local, deixando a montagem XML no motor Python.

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
    real exportado pela IDE da mesma KB.

.PARAMETER AsJson
    Retorna saída JSON estruturada.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

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

$output = & $pythonCommand.Source @engineArgs
if ($LASTEXITCODE -ne 0) {
    throw (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
}

if ($AsJson) {
    $output
} else {
    ($output | Out-String | ConvertFrom-Json)
}
