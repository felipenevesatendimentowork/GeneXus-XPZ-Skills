#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para criar pacote import_file.xml de uma frente da KB.

.DESCRIPTION
Executa o wrapper compartilhado `New-XpzImportPackage.ps1`, que chama o motor Python,
le
`kb-source-metadata.md`, coleta os XMLs de
`ObjetosGeradosParaImportacaoNaKbNoGenexus\<FrontName>` e grava o pacote em
`PacotesGeradosParaImportacaoNaKbNoGenexus`.

Este wrapper é recomendado quando a pasta paralela adota empacotamento local
recorrente e precisa de comando curto, auditável e aderente a allowlist.

.PARAMETER FrontName
Nome da subpasta da frente no formato `NomeCurto_GUID_YYYYMMDD`.

.PARAMETER NN
Rodada curta pretendida para o pacote. Default: 01.

.PARAMETER AsJson
Retorna saída JSON estruturada.

.PARAMETER TemplatePackagePath
Pacote import_file.xml ou XPZ real comparavel para clonar KMW, Source,
Dependencies e ObjectsIdentityMapping. Quando o template trouxer Attributes de
topo e a frente nao trouxer atributos explicitos, o motor preserva esses
Attributes. Quando omitido, o motor usa envelope minimo derivado de
kb-source-metadata.md.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\New-KbImportPackage.ps1 -FrontName MinhaFrente_12345678-1234-1234-1234-1234567890ab_20260429 -NN 01
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FrontName,

    [string]$NN = '01',

    [string]$TemplatePackagePath,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\New-XpzImportPackage.ps1"

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared import package script not found: $enginePath"
}

$argsForEngine = @{
    RepoRoot = $repoRoot
    FrontName = $FrontName
    NN = $NN
}

if ($AsJson) {
    $argsForEngine.AsJson = $true
}

if (-not [string]::IsNullOrWhiteSpace($TemplatePackagePath)) {
    $argsForEngine.TemplatePackagePath = $TemplatePackagePath
}

& $enginePath @argsForEngine
